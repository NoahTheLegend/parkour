#include "PNGLoader.as";

void SyncRoomsGrid(CRules@ this)
{
    // send a command to clients with actual rooms grid
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

    print("Syncing rooms grid with " + room_coords.length + " rooms to clients");
    this.SendCommand(this.getCommandID("create_rooms_grid"), params);
}

string GetRoomFile(u8 level_type, uint level_id)
{
    return "Rooms/" + getTypeName(level_type) + "_" + level_id + ".png";
}

const u16[] collapseable_tiles = {
    CMap::tile_castle,
    CMap::tile_castle_back,
    CMap::tile_wood,
    CMap::tile_wood_back,
    CMap::tile_castle_moss,
    CMap::tile_castle_back_moss
};

const u16[] support_tiles = {
    CMap::tile_ground,
    CMap::tile_ground_back,
    CMap::tile_bedrock,
    CMap::tile_stone,
    CMap::tile_thickstone,
    CMap::tile_gold
};

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
        if (b !is null && !b.hasTag("player") && b.getName() != "tdm_spawn") // don't delete players
        {
            b.Untag("exploding");
            b.Tag("dead");
            b.server_Die();
        }
    }

    print("Erased room at " + pos + " with size " + size + ", cleared " + blobs.length + " blobs");

    bool removed = true;
    while (removed)
    {
        removed = false;
        for (f32 x = pos.x; x < pos.x + size.x; x += map.tilesize)
        {
            for (f32 y = pos.y; y < pos.y + size.y; y += map.tilesize)
            {
                Vec2f tilePos(x, y);
                Tile tile = map.getTile(tilePos);
                for (uint i = 0; i < collapseable_tiles.length; i++)
                {
                    if (tile.type == collapseable_tiles[i] && hasSupport(tilePos))
                    {
                        map.server_SetTile(tilePos, CMap::tile_ground_back);
                        removed = true;
                        break;
                    }
                }
            }
        }
    }

    // erase remaining tiles
    for (f32 x = pos.x; x < pos.x + size.x; x += map.tilesize)
    {
        for (f32 y = pos.y; y < pos.y + size.y; y += map.tilesize)
        {
            Tile tile = map.getTile(Vec2f(x, y));
            if (tile.type != CMap::tile_empty)
            {
                map.server_SetTile(Vec2f(x, y), CMap::tile_empty);
            }

            map.server_setFloodWaterWorldspace(Vec2f(x, y), false);
        }
    }
}

bool hasSupport(Vec2f pos)
{
    CMap@ map = getMap();
    if (map is null) return false;

    Vec2f[] directions;
    directions.push_back(Vec2f(-map.tilesize, 0));
    directions.push_back(Vec2f(map.tilesize, 0));
    directions.push_back(Vec2f(0, -map.tilesize));
    directions.push_back(Vec2f(0, map.tilesize));

    for (uint d = 0; d < directions.length; ++d)
    {
        Vec2f adj = pos + directions[d];
        Tile adjTile = map.getTile(adj);

        for (uint s = 0; s < support_tiles.length; ++s)
        {
            if (adjTile.type == support_tiles[s])
                return true;
        }
    }

    return false;
}

void CreateRoomFromFile(CRules@ this, string room_file, Vec2f pos, u16 pid)
{
    RoomPNGLoader loader = RoomPNGLoader(pid);
    loader.startLoading(getMap(), room_file, pos, ROOM_SIZE, true, tiles_per_tick_base);
    this.set_u32("_room_creation_delay", getGameTime() + room_creation_delay_base);
    
    CPlayer@ p = getPlayerByNetworkId(pid);
    if (p !is null) this.set("room_loader_" + p.getUsername(), @loader);
}

void SetMesh()
{
    CMap@ map = getMap();
    if (map is null) return;

    // temp fix - make 2x2 areas
    Vec2f top_left = Vec2f_zero;
    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 0; iy < 2; iy++)
        {
            Vec2f p = top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            map.server_SetTile(p, filler_tile);
        }
    }

    Vec2f bottom_left = Vec2f(0, map.tilemapheight - 2) * map.tilesize;
    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 0; iy < 2; iy++)
        {
            Vec2f p = bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            map.server_SetTile(p, filler_tile);
        }
    }
}

void FixMesh()
{
    CMap@ map = getMap();
    if (map is null) return;

    // break placed corners
    Vec2f top_left = Vec2f_zero;
    Vec2f bottom_left = Vec2f(0, map.tilemapheight - 2) * map.tilesize;

    Vec2f copy_top_left = Vec2f(3, 0) * map.tilesize;
    Vec2f copy_bottom_left = Vec2f(3, map.tilemapheight - 2) * map.tilesize;

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 0; iy < 2; iy++)
        {
            Vec2f src = copy_top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Vec2f dst = top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Tile t = map.getTile(src);
            map.server_SetTile(dst, t.type);
        }
    }

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 0; iy < 2; iy++)
        {
            Vec2f src = copy_bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Vec2f dst = bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Tile t = map.getTile(src);
            map.server_SetTile(dst, t.type);
        }
    }

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 1; iy < 2; iy++)
        {
            Vec2f p = top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            map.server_SetTile(p, filler_tile);
        }
    }

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 1; iy < 2; iy++)
        {
            Vec2f p = bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            map.server_SetTile(p, filler_tile);
        }
    }

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 1; iy < 2; iy++)
        {
            Vec2f src = copy_top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Vec2f dst = top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Tile t = map.getTile(src);
            map.server_SetTile(dst, t.type);
        }
    }

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 1; iy < 2; iy++)
        {
            Vec2f src = copy_bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Vec2f dst = bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Tile t = map.getTile(src);
            map.server_SetTile(dst, t.type);
        }
    }
}

void LoadChessLevel(CRules@ rules, Vec2f override_pos = Vec2f(-1, -1))
{
    u8 room_id = rules.get_u8("captured_room_id");
    if (room_id == 255 && override_pos.x == -1)
    {
        print("No free room id available for chess level");
        return;
    }

    string name = "ChessLevel.png";
    u8 type = RoomType::chess;

    int level_id = 5012;
    Vec2f pos = override_pos.x == -1 ? getRoomPosFromID(room_id) : override_pos; // default chess pos

    CBitStream params;
    params.write_u16(getLocalPlayer().getNetworkID()); // player id
    params.write_u8(type);
    params.write_s32(level_id); // room id
    params.write_Vec2f(ROOM_SIZE); // room size
    params.write_Vec2f(pos); // start pos

    rules.SendCommand(rules.getCommandID("set_room"), params);
    print("sent "+rules.getCommandID("set_room"));
}

void sendRoomCommand(CRules@ rules, u8 type, int level_id, Vec2f pos)
{
    CBitStream params;
    params.write_u16(getLocalPlayer().getNetworkID()); // player id
    params.write_u8(type);
    params.write_s32(level_id); // level id
    params.write_Vec2f(ROOM_SIZE); // room size
    params.write_Vec2f(pos); // start pos // todo: get from level data

    rules.SendCommand(rules.getCommandID("set_room"), params);
    print("sent " + rules.getCommandID("set_room"));
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

    print("Calculating position for room ID " + room_id);

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
        print("Warning: rooms_per_row was zero, falling back to 1");
    }

    f32 x = (room_id % rooms_per_row) * ROOM_SIZE.x;
    f32 y = (room_id / rooms_per_row) * ROOM_SIZE.y;

    return Vec2f(x, y);
}
