#include "PNGLoader.as";

Vec2f ROOM_SIZE = Vec2f(100, 100) * 8;

const u8 tiles_per_tick_base = 20;
const u32 room_creation_delay_base = 0;

TileType filler_tile = CMap::tile_ground_back;

namespace RoomType {
    enum RoomType {
        knight = 0,
        archer,
        builder,
        chess
    };
};

void SyncRoomsGrid(CRules@ this)
{
    // send a command to clients with actual rooms grid
    if (!isServer()) return;

    CMap@ map = getMap();
    if (map is null) return;

    Vec2f[]@ rooms_coords;
    if (!this.get("rooms_coords", @rooms_coords)) return;

    CBitStream params;
    params.write_bool(false);
    params.write_u16(rooms_coords.length);
    for (uint i = 0; i < rooms_coords.length; i++)
    {
        params.write_Vec2f(rooms_coords[i]);
    }

    print("Syncing rooms grid with " + rooms_coords.length + " rooms to clients");
    this.SendCommand(this.getCommandID("create_rooms_grid"), params);
}

string GetRoomFile(u8 room_type, uint room_id)
{
    return "Rooms/" + getTypeName(room_type) + "_" + room_id + ".png";
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

void EraseRoom(CRules@ this, Vec2f pos, Vec2f size, u8 room_id)
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

    Vec2f bottom_right = Vec2f(map.tilemapwidth - 2, map.tilemapheight - 2) * map.tilesize;
    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 0; iy < 2; iy++)
        {
            Vec2f p = bottom_right + Vec2f(ix * map.tilesize, iy * map.tilesize);
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
    Vec2f bottom_base = Vec2f(map.tilemapwidth - 2, map.tilemapheight - 2) * map.tilesize;

    Vec2f copy_top_left = Vec2f(3, 0) * map.tilesize;
    Vec2f copy_bottom_right = Vec2f(map.tilemapwidth - 3, map.tilemapheight) * map.tilesize;

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
            Vec2f src = copy_bottom_right + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Vec2f dst = bottom_base + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Tile t = map.getTile(src);
            map.server_SetTile(dst, t.type);
        }
    }
}

void sendRoomCommand(CRules@ rules, u8 type, int room_id, Vec2f pos)
{
    CBitStream params;
    params.write_u16(getLocalPlayer().getNetworkID()); // player id
    params.write_u8(type);
    params.write_s32(room_id); // room id
    params.write_Vec2f(ROOM_SIZE); // room size
    params.write_Vec2f(pos); // start pos // todo: get from level data

    rules.SendCommand(rules.getCommandID("set_room"), params);
    print("sent " + rules.getCommandID("set_room"));
}

string getTypeName(u8 room_type)
{
    switch (room_type)
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