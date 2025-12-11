#include "PNGLoader.as";
#include "Helpers.as";

// builds the room for the specified player
void BuildRoom(CRules@ this, u16 pid, u8 level_type, int level_id, Vec2f room_size, Vec2f start_pos)
{
    u16[]@ room_owners;
    if (!this.get("room_owners", @room_owners))
    {
        error("[ERR] BuildRoom: failed to get room_owners");
        return;
    }

    // ensure the player has a room
    if (pid != 0)
    {
        if (room_owners.find(pid) == -1)
        {
            error("[ERR] Player " + pid + " does not own any room, cannot build room");
            SetClientMessage(pid, "You need to create a room before loading levels");
            return;
        }
    }

    print("[INF] Loaded level " + level_id + " of type " + level_type + " with size " + room_size + " at pos " + start_pos);
    // set client vars (notify client who requested)
    if (pid != 0)
    {
        CBitStream params1;
        params1.write_u16(pid);
        params1.write_u8(level_type);
        params1.write_s32(level_id);
        params1.write_Vec2f(room_size);
        params1.write_Vec2f(start_pos);
        params1.write_Vec2f(start_pos + room_size * 0.5f); // center
        params1.write_s32(0); // complexity, todo
        params1.write_string(getFullTypeName(level_type));

        this.SendCommand(this.getCommandID("sync_room"), params1);
    }

    string file = level_type == RoomType::chess ? "ChessLevel.png" : GetRoomFile(level_type, level_id);
    CFileImage fm(file);
    if (!fm.isLoaded())
    {
        error("[ERR] Room file " + file + " not found, loading empty room");
        file = "Maps/Hub.png";
    }

    u8[]@ level_types;
    if (!this.get("level_types", @level_types))
    {
        print("[CMD] Failed to get level types");
        return;
    }

    u8 room_id = room_owners.find(pid);
    if (room_id < level_types.size()) level_types[room_id] = level_type; // server tracking
    
    u16[]@ level_ids;
    if (!this.get("level_ids", @level_ids))
    {
        print("[CMD] Failed to get level ids");
        return;
    }

    if (room_id < level_ids.size()) level_ids[room_id] = level_id;
    this.set_s32("update_room_pathline_" + room_id, level_id);
    
    if (room_id < level_types.size() && room_id < level_ids.size())
    {
        string pathline_key = "_p_" + level_types[room_id] + "_" + level_ids[room_id] + "_" + room_id;
        this.set_string("pathline_key_" + room_id, pathline_key);
    }

    EraseRoom(this, start_pos, room_size); // tag for room creation
    CreateRoomFromFile(this, file, start_pos, pid);
    onRoomCreated(this, level_type, level_id, pid);
}

// returns the file path for a given room based on its type and ID
string GetRoomFile(u8 level_type, uint level_id)
{
    return "Rooms/" + getTypeName(level_type) + "_" + level_id + ".png";
}

string getTypeName(u8 level_type)
{
    switch (level_type)
    {
        case RoomType::knight: return "k";
        case RoomType::archer: return "a";
        case RoomType::builder: return "b";
        default: return "unknown";
    }

    return "unknown";
}

string getFullTypeName(u8 level_type)
{
    switch (level_type)
    {
        case RoomType::knight: return "Knight";
        case RoomType::archer: return "Archer";
        case RoomType::builder: return "Builder";
        case RoomType::chess: return "Chess";
        default: return "Unknown";
    }

    return "Unknown";
}

u8 getTypeFromName(string type_name)
{
    if (type_name == "k") return RoomType::knight;
    if (type_name == "a") return RoomType::archer;
    if (type_name == "b") return RoomType::builder;
    return 255;
}

Vec2f getRoomPosFromID(int room_id)
{
    CRules@ rules = getRules();
    if (rules is null) return Vec2f_zero;

    CMap@ map = getMap();
    if (map is null) return Vec2f_zero;

    int map_width = map.tilemapwidth * 8;
    int map_height = map.tilemapheight * 8;

    u8 rooms_count = (map_width / ROOM_SIZE.x) * (map_height / ROOM_SIZE.y);
    u8 middle_hub_id = Maths::Floor(rooms_count / 2.0f);

    if (room_id >= middle_hub_id)
    {
        room_id += 1; // skip middle hub
    }

    int rooms_per_row = 0;
    if (ROOM_SIZE.x > 0.0f && map_width > 0)
    {
        rooms_per_row = int(map_width / ROOM_SIZE.x);
    }

    if (rooms_per_row <= 0)
    {
        // fallback to avoid division/modulo by zero
        rooms_per_row = 1;
        warn("[WRN] Rooms_per_row was zero, falling back to 1");
    }

    f32 x = (room_id % rooms_per_row) * ROOM_SIZE.x;
    f32 y = (room_id / rooms_per_row) * ROOM_SIZE.y;

    return Vec2f(x, y);
}

// creates the rooms grid either from override coordinates or by calculating based on map size
// the map size is determined in RoomsCommon.as using MAP_GRID in amount of rooms and ROOM_SIZE in pixels
void CreateRoomsGrid(CRules@ this, Vec2f[] override_room_coords = Vec2f[]())
{
    this.Tag("was_init");

    // create both on client and server
    CMap@ map = getMap();
    if (map is null)
    {
        print("[ERR] CreateRoomsGrid: map is null");
        return;
    }

    Vec2f[] room_coords;
    u8[] room_ids;
    u8[] level_types;
    u16[] level_ids;
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
                    BuildRoom(this, 0, RoomType::chess, 5012, ROOM_SIZE, Vec2f(x, y));
                    this.set_Vec2f("update_hub_pos", Vec2f(x, y));

                    continue;
                }

                room_coords.push_back(Vec2f(x, y));
                room_ids.push_back(room_ids.length);
                level_types.push_back(RoomType::knight); // default type
                level_ids.push_back(0); // default id
                room_owners.push_back(0); // no owner yet
            }
        }
    }

    print("[INF] Created rooms grid with " + room_coords.length + " rooms, " + room_ids.length + " ids, " + room_owners.length + " owners");

    @local_room_coords = @room_coords;
    this.set("room_coords", room_coords);

    this.set("room_ids", @room_ids);
    this.set("level_types", @level_types);
    this.set("level_ids", @level_ids);
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

    u8[]@ level_types;
    if (!this.get("level_types", @level_types))
    {
        if (gt % 30 == 0) error("[ERR] EnsureRoomsOwned: failed to get level_types");
        return;
    }

    u16[]@ level_ids;
    if (!this.get("level_ids", @level_ids))
    {
        if (gt % 30 == 0) error("[ERR] EnsureRoomsOwned: failed to get level_ids");
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
void EraseRoom(CRules@ this, Vec2f pos, Vec2f size, bool force_all_tiles = false)
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
            // remove bg
            map.server_SetTile(b.getPosition(), CMap::tile_empty);
            map.SetTile(map.getTileOffset(b.getPosition()), CMap::tile_empty);

            b.Untag("exploding");
            b.Tag("dead");
            b.server_Die();
        }
    }

    string pos_str = int(pos.x) + "_" + int(pos.y);
    if (force_all_tiles)
    {
        // fill every tile with wooden bg
        TileType filler_tile = CMap::tile_wood_back;
        for (f32 x = pos.x; x < pos.x + size.x; x += map.tilesize)
        {
            for (f32 y = pos.y; y < pos.y + size.y; y += map.tilesize)
            {
                if (map.getTile(Vec2f(x, y)).type == CMap::tile_empty) continue;

                map.server_SetTile(Vec2f(x, y), filler_tile);
            }
        }
        
        // erase all tiles in the area at once
        for (f32 x = pos.x; x < pos.x + size.x; x += map.tilesize)
        {
            for (f32 y = pos.y; y < pos.y + size.y; y += map.tilesize)
            {
                map.server_SetTile(Vec2f(x, y), CMap::tile_empty);
                map.SetTile(map.getTileOffset(Vec2f(x, y)), CMap::tile_empty);
            }
        }
    }
    else
    {
        // erase water
        for (f32 x = pos.x; x < pos.x + size.x; x += map.tilesize)
        {
            for (f32 y = pos.y; y < pos.y + size.y; y += map.tilesize)
            {
                map.server_setFloodWaterWorldspace(Vec2f(x, y), false);
            }
        }

        // erase cached tiles
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
                    map.server_SetTile(tpos, filler_tile);
                }
            }

            // second pass: replace all remaining cached tiles with empty
            for (uint i = 0; i < tile_positions.length; i++)
            {
                map.server_SetTile(tile_positions[i], CMap::tile_empty);
                map.SetTile(map.getTileOffset(tile_positions[i]), CMap::tile_empty);
            }
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
    if (!isClient()) return;

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
            if (loader !is null && loader.map !is null) // map null check is supposed for left players resetting their loaders
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

int getComplexity(u8 level_type, int level_id)
{
    switch (level_type)
    {
        case RoomType::knight:
        {
            if (level_id < 0) return -1;
            uint idx = uint(level_id);
            if (idx >= difficulty_knight.size()) return -1;
            return difficulty_knight[idx];

            break;
        }
        case RoomType::archer:
        {
            if (level_id < 0) return -1;
            uint idx = uint(level_id);
            if (idx >= difficulty_archer.size()) return -1;
            return difficulty_archer[idx];

            break;
        }
        case RoomType::builder:
        {
            if (level_id < 0) return -1;
            uint idx = uint(level_id);
            if (idx >= difficulty_builder.size()) return -1;
            return difficulty_builder[idx];

            break;
        }
        default:
            return -1;
    }

    return -1;
}

SColor getComplexityRedness(int complexity)
{
    // map complexity to redness color
    // complexity 0-10
    f32 t = Maths::Clamp(complexity / 10.0f, 0.0f, 1.0f);
    u8 r = 255;
    u8 g = u8(255 * (1.0f - t));
    u8 b = u8(255 * (1.0f - t));
    return SColor(255, r, g, b);
}