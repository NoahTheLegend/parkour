#include "PNGLoader.as";
#include "RoomsCommon.as";

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