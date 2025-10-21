#include "PNGLoader.as";
#include "RoomsCommon.as";
#include "Helpers.as";

// creates the rooms grid either from override coordinates or by calculating based on map size
// the map size is determined in RoomsCommon.as using MAP_GRID in amount of rooms and ROOM_SIZE in pixels
void CreateRoomsGrid(CRules@ this, Vec2f[] override_room_coords = Vec2f[]())
{
    this.Tag("was_init");

    // create both on client and server
    CMap@ map = getMap();
    if (map is null) return;

    Vec2f[] room_coords;
    u8[] room_ids;
    u16[] room_owners;

    if (override_room_coords.length() > 0)
    {
        room_coords = override_room_coords;
    }
    else
    {
        int map_width = map.tilemapwidth * 8;
        int map_height = map.tilemapheight * 8;

        int cols = map_width / ROOM_SIZE.x;
        int rows = map_height / ROOM_SIZE.y;

        print("[INF] Creating rooms grid for map size " + map_width + "x" + map_height +" and room size " + ROOM_SIZE.x + "x" + ROOM_SIZE.y + " (" + cols + "x" + rows + ")");

        u8 rooms_count = u8(cols * rows);
        u8 middle_hub_id = u8(Maths::Floor(rooms_count / 2.0f));

        // iterate row-major: y (rows) outer, x (cols) inner
        for (int ry = 0; ry < rows; ry++)
        {
            for (int cx = 0; cx < cols; cx++)
            {
                int x = cx * ROOM_SIZE.x;
                int y = ry * ROOM_SIZE.y;

                u8 room_index = u8(ry * cols + cx);

                if (room_index == middle_hub_id)
                {
                    // load chess level here
                    print("[INF] Loading chess level at room index " + room_index + " pos (" + x + ", " + y + ")");
                    LoadChessLevel(this, 0, Vec2f(x, y));
                    continue;
                }

                room_coords.push_back(Vec2f(x, y));
                room_ids.push_back(room_ids.length);
                room_owners.push_back(0); // no owner yet
            }
        }
    }

    print("[INF] Created rooms grid with " + room_coords.length + " rooms, " + room_ids.length + " ids, " + room_owners.length + " owners");

    @local_room_coords = @room_coords;
    this.set("room_coords", room_coords);

    this.set("room_ids", @room_ids);
    this.set("room_owners", @room_owners);
}

// syncs the rooms grid to all clients
void SyncRoomsGrid(CRules@ this)
{
    if (!isServer()) return;

    CMap@ map = getMap();
    if (map is null) return;

    Vec2f[]@ room_coords;
    if (!this.get("room_coords", @room_coords)) return;

    CBitStream params;
    params.write_bool(false);
    params.write_u16(room_coords.length);
    for (uint i = 0; i < room_coords.length; i++)
    {
        params.write_Vec2f(room_coords[i]);
    }

    print("[INF] Syncing rooms grid with " + room_coords.length + " rooms to clients");
    this.SendCommand(this.getCommandID("create_rooms_grid"), params);
}

// ensures that all rooms are owned by valid players, frees rooms if owner disconnected
void EnsureRoomsOwned(CRules@ this)
{
    if (!isServer()) return;
    u32 gt = getGameTime();

    u8[]@ room_ids;
    if (!this.get("room_ids", @room_ids))
    {
        if (gt % 30 == 0) error("[ERR] EnsureRoomsOwned: failed to get room_ids");
        return;
    }

    u16[]@ room_owners;
    if (!this.get("room_owners", @room_owners))
    {
        if (gt % 30 == 0) error("[ERR] EnsureRoomsOwned: failed to get room_owners");
        return;
    }

    for (uint i = 0; i < room_ids.length; i++)
    {
        u16 owner_id = room_owners[i];
        if (owner_id != 0) // unowned
        {
            CPlayer@ owner_player = getPlayerByNetworkId(owner_id);
            if (owner_player is null)
            {
                // owner disconnected, free the room
                room_owners[i] = 0;
                if (gt % 30 == 0) print("[INF] Room " + i + " owner disconnected, freeing room");
            }
        }
    }
}

// wipes the room, used before loading a new one
void EraseRoom(CRules@ this, Vec2f pos, Vec2f size)
{
    CMap@ map = getMap();
    if (map is null) return;

    // clear blobs first
    CBlob@[] blobs;
    map.getBlobsInBox(pos, pos + size, @blobs);
    for (uint i = 0; i < blobs.length; i++)
    {
        CBlob@ b = blobs[i];
        if (b !is null && !b.hasTag("player")) // don't delete players
        {
            b.Untag("exploding");
            b.Tag("dead");
            b.server_Die();
        }
    }

    // erase water
    for (f32 x = pos.x; x < pos.x + size.x; x += map.tilesize)
    {
        for (f32 y = pos.y; y < pos.y + size.y; y += map.tilesize)
        {
            map.server_setFloodWaterWorldspace(Vec2f(x, y), false);
        }
    }

    // erase cached tiles
    string pos_str = int(pos.x) + "_" + int(pos.y);
    u32[]@ offsets;

    if (this.get("_room_tile_offsets_" + pos_str, @offsets))
    {
        // cache tile world positions and mark which were replaced with filler
        Vec2f[] tile_positions;
        tile_positions.reserve(offsets.length);

        for (uint i = 0; i < offsets.length; i++)
        {
            Vec2f tpos = map.getTileWorldPosition(offsets[i]);
            tile_positions.push_back(tpos);

            TileType tile = map.getTile(tpos).type;
            if (collapseable_tiles.find(tile) != -1)
            {
                // first pass: only replace collapsable tiles with filler
                map.server_SetTile(tpos, CMap::filler_tile);
            }
        }

        // second pass: replace all remaining cached tiles with empty
        for (uint i = 0; i < tile_positions.length; i++)
        {
            map.server_SetTile(tile_positions[i], CMap::tile_empty);
        }
    }

    u32[] empty;
    this.set("_room_tile_offsets_" + pos_str, @empty);

    print("[INF] Erased room at " + pos + " with size " + size + ", cleared " + blobs.length + " blobs");
}

// creates a room from a PNG file at the specified position for the specified player
// server reserves pid = 0
void CreateRoomFromFile(CRules@ this, string room_file, Vec2f pos, u16 pid)
{
    bool lazy_load = pid != 0; // lazy load for clients
    RoomPNGLoader loader = RoomPNGLoader(pid);
    loader.startLoading(getMap(), room_file, pos, ROOM_SIZE, lazy_load, tiles_per_tick_base);
    this.set_u32("_room_creation_delay", getGameTime() + room_creation_delay_base);
    
    if (pid == 0)
    {
        this.set("room_loader_server", @loader);
    }
    else
    {
        CPlayer@ p = getPlayerByNetworkId(pid);
        if (p !is null) this.set("room_loader_" + p.getUsername(), @loader);
    }
}

// creates a specific room for chess
void LoadChessLevel(CRules@ rules, u16 pid, Vec2f override_pos = Vec2f(-1, -1))
{
    u8 room_id = rules.get_u8("captured_room_id");
    if (room_id == 255 && override_pos.x == -1)
    {
        error("[ERR] No free room id available for chess level");
        SetClientMessage(pid, "No free room id available for your level, wait for someone to free one. You still can play in other rooms.");
        return;
    }

    string name = "ChessLevel.png";
    u8 type = RoomType::chess;

    int level_id = 5012;
    Vec2f pos = override_pos.x == -1 ? getRoomPosFromID(room_id) : override_pos; // default chess pos

    CBitStream params;
    params.write_u16(pid); // player id
    params.write_u8(type);
    params.write_s32(level_id); // room id
    params.write_Vec2f(ROOM_SIZE); // room size
    params.write_Vec2f(pos); // start pos

    rules.SendCommand(rules.getCommandID("set_room"), params);
    print("[CMD] Sent " + rules.getCommandID("set_room"));
}

// runs lazy loading for all rooms every tick
void RunRoomLoaders(CRules@ this)
{
    // update room loaders
    for (u8 i = 0; i < getPlayersCount(); i++)
    {
        CPlayer@ p = getPlayer(i);
        if (p is null) continue;

        string username = p.getUsername();
        RoomPNGLoader@ loader;
        if (this.get("room_loader_" + username, @loader))
        {
            if (loader !is null)
                loader.loadRoom();
        }
    }
    // server loader
    RoomPNGLoader@ server_loader;
    if (this.get("room_loader_server", @server_loader))
    {
        if (server_loader !is null)
            server_loader.loadRoom();
    }
}