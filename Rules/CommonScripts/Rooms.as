#include "PNGLoader.as";

namespace RoomType {
    enum RoomType {
        knight = 0,
        archer,
        builder
    };
};

Vec2f ROOM_SIZE = Vec2f(100, 100) * 8;
void onInit(CRules@ this)
{
    CreateRoomsGrid(this);
    
    if (isClient())
    {
        CBitStream params;
        params.write_bool(true); // request sync
        this.SendCommand(this.getCommandID("create_rooms_grid"), params);
    }
}

void CreateRoomsGrid(CRules@ this, Vec2f[] override_rooms_coords = Vec2f[]())
{
    // create both on client and server
    CMap@ map = getMap();
    if (map is null) return;

    Vec2f[] rooms_coords;
    if (override_rooms_coords.length() > 0)
    {
        rooms_coords = override_rooms_coords;
    }
    else
    {
        int map_width = map.tilemapwidth;
        int map_height = map.tilemapheight;

        for (int x = 0; x < map_width; x += ROOM_SIZE.x)
        {
            for (int y = 0; y < map_height; y += ROOM_SIZE.y)
            {
                rooms_coords.push_back(Vec2f(x * map.tilesize, y * map.tilesize));
            }
        }
    }

    print("Created rooms grid with " + rooms_coords.length + " rooms");
    @local_rooms_coords = @rooms_coords;
    this.set("rooms_coords", rooms_coords);
}

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

void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{
    if (cmd == this.getCommandID("create_rooms_grid"))
    {
        // if request_sync, client is requesting the grid from server
        bool request_sync = false;
        if (!params.saferead_bool(request_sync)) {print("Failed to read request sync"); return;}

        if (request_sync && isServer())
        {
            SyncRoomsGrid(this);
            return;
        }

        uint rooms_count;
        if (!params.saferead_u16(rooms_count)) {print("Failed to read rooms count"); return;}

        Vec2f[] rooms_coords;
        for (uint i = 0; i < rooms_count; i++)
        {
            Vec2f room_pos;
            if (!params.saferead_Vec2f(room_pos)) {print("Failed to read room pos"); return;}
            rooms_coords.push_back(room_pos);
        }

        CreateRoomsGrid(this, rooms_coords);
        print("Received rooms grid with " + rooms_coords.length + " rooms");

        return;
    }
    else if (cmd == this.getCommandID("set_room"))
    {
        u8 room_type;
        if (!params.saferead_u8(room_type)) {print("Failed to read room type"); return;}

        uint room_id;
        if (!params.saferead_u16(room_id)) {print("Failed to read room id"); return;}

        Vec2f room_size;
        if (!params.saferead_Vec2f(room_size)) {print("Failed to read room size"); return;}

        Vec2f start_pos;
        if (!params.saferead_Vec2f(start_pos)) {print("Failed to read start pos"); return;}

        bool lazy_load;
        if (!params.saferead_bool(lazy_load)) {print("Failed to read lazy load"); return;}

        print("Loaded room " + room_id + " of type " + room_type + " with size " + room_size + " at pos " + start_pos + (lazy_load ? " (lazy)" : ""));

        // erase area first
        EraseRoom(this, start_pos, room_size);

        // create room from tiles
        CreateRoomFromFile(this, GetRoomFile(room_type, room_id), start_pos);
    }
}

Vec2f[]@ local_rooms_coords;
void onRender(CRules@ this)
{
    if (!isClient()) return;
    
    if (local_rooms_coords !is null)
    {
        for (uint i = 0; i < local_rooms_coords.length; i++)
        {
            Vec2f room_pos = local_rooms_coords[i];
            Vec2f room_size = ROOM_SIZE;

            Vec2f top_left = room_pos;
            Vec2f top_right = room_pos + Vec2f(room_size.x, 0);
            Vec2f bottom_left = room_pos + Vec2f(0, room_size.y);
            Vec2f bottom_right = room_pos + room_size;

            // Top edge (draw along the top side of top tiles)
            GUI::DrawLine(top_left, top_right, SColor(255, 255, 255, 255));
            // Right edge (draw along the right side of right tiles)
            GUI::DrawLine(top_right, bottom_right, SColor(255, 255, 255, 255));
            // Bottom edge (draw along the bottom side of bottom tiles)
            GUI::DrawLine(bottom_right, bottom_left, SColor(255, 255, 255, 255));
            // Left edge (draw along the left side of left tiles)
            GUI::DrawLine(bottom_left, top_left, SColor(255, 255, 255, 255));
        }
    }
}

void onReload(CRules@ this)
{
    Vec2f[]@ rooms_coords;
    if (this.get("rooms_coords", @rooms_coords))
    {
        @local_rooms_coords = @rooms_coords;
    }
}

void onTick(CRules@ this)
{
    CMap@ map = getMap();
    if (map is null) return;

    // debug
    if (isClient() && isServer() && getControls().isKeyPressed(KEY_LSHIFT))
    {
        map.server_SetTile(getControls().getMouseWorldPos(), CMap::tile_castle);
    }   

    //CBlob@ b = getBlobByName("archer");
    //if (b !is null && b.isKeyJustPressed(key_action1))
    //{
    //    CBitStream params;
    //    params.write_u8(RoomType::knight);
    //    params.write_u16(0); // room id
    //    params.write_Vec2f(ROOM_SIZE); // room size
    //    params.write_Vec2f(Vec2f(0, 0)); // start pos
    //    params.write_bool(false); // lazy load
    //   if (isClient()) this.SendCommand(this.getCommandID("set_room"), params);
    //   if (isClient()) print("sent "+this.getCommandID("set_room"));
    //}
}

string GetRoomFile(u8 room_type, uint room_id)
{
    return "room"+room_id+"_"+getTypeName(room_type)+".png";
}

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
}

void CreateRoomFromFile(CRules@ this, string room_file, Vec2f pos)
{
    RoomPNGLoader@ loader = @RoomPNGLoader();
    uint[] cache = loader.loadRoom(getMap(), room_file, pos, ROOM_SIZE); // todo: set these to remove the tiles on erase

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