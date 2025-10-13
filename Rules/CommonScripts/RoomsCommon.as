#include "PNGLoader.as";

Vec2f ROOM_SIZE = Vec2f(100, 100) * 8;

namespace RoomType {
    enum RoomType {
        knight = 0,
        archer,
        builder
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

void EraseRoom(CRules@ this, Vec2f pos, Vec2f size, u8 room_id)
{
    FixMesh();
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

    // erase tiles
    for (f32 x = pos.x; x < pos.x + size.x; x += map.tilesize)
    {
        for (f32 y = pos.y; y < pos.y + size.y; y += map.tilesize)
        {
            map.server_SetTile(Vec2f(x, y), CMap::tile_empty);
        }
    }

    FixMesh();
}

void CreateRoomFromFile(CRules@ this, string room_file, Vec2f pos, u16 pid)
{
    RoomPNGLoader@ loader = @RoomPNGLoader(pid);
    uint[] cache = loader.loadRoom(getMap(), room_file, pos, ROOM_SIZE); // todo: set these to remove the tiles on erase

    CMap@ map = getMap();
    if (map is null) return;
    
    FixMesh();
}

void FixMesh()
{
    CMap@ map = getMap();
    if (map is null) return;

    // temp fix
    map.server_SetTile(Vec2f_zero, CMap::tile_ground_back);
    map.server_SetTile(Vec2f_zero, map.getTile(Vec2f(map.tilesize, 0)).type);
    Vec2f bottom_left = Vec2f(map.tilemapwidth - 1, map.tilemapheight - 1) * map.tilesize;
    map.server_SetTile(bottom_left, CMap::tile_ground_back);
    map.server_SetTile(bottom_left, map.getTile(bottom_left - Vec2f(map.tilesize, 0)).type);
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