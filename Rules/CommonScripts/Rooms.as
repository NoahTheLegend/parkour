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
        u16 pid;
        if (!params.saferead_u16(pid)) {print("Failed to read player id"); return;}

        u8 room_type;
        if (!params.saferead_u8(room_type)) {print("Failed to read room type"); return;}

        int room_id;
        if (!params.saferead_s32(room_id)) {print("Failed to read room id"); return;}

        Vec2f room_size;
        if (!params.saferead_Vec2f(room_size)) {print("Failed to read room size"); return;}

        Vec2f start_pos;
        if (!params.saferead_Vec2f(start_pos)) {print("Failed to read start pos"); return;}

        print("Loaded room " + room_id + " of type " + room_type + " with size " + room_size + " at pos " + start_pos);

        // set client vars
        CPlayer@ p = getPlayerByNetworkId(pid);
        if (p !is null && p.isMyPlayer())
        {
            this.set_u8("current_room_type", room_type);
            this.set_s32("current_room_id", room_id);

            this.set_Vec2f("current_room_pos", start_pos);
            this.set_Vec2f("current_room_size", room_size);
            this.set_Vec2f("current_room_center", start_pos + room_size * 0.5f);

            error("Client: set current room to " + room_id + " of type " + room_type + " at pos " + start_pos);
        }
        
        string file = room_type == RoomType::chess ? "ChessLevel.png" : GetRoomFile(room_type, room_id);
        CFileImage fm(file);
        if (!fm.isLoaded())
        {
            print("Room file " + file + " not found, loading empty room");
            file = "Maps/Hub.png";
        }

        EraseRoom(this, start_pos, room_size, room_id); // tag for room creation
        CreateRoomFromFile(this, file, start_pos, pid);
        onRoomCreated(this, room_type, room_id, pid);
    }
}

void onRoomCreated(CRules@ this, u8 room_type, uint room_id, u16 pid)
{
    CPlayer@ p = getPlayerByNetworkId(pid);
    if (p is null) return;

    CBlob@ player_blob = p.getBlob();
    string new_blob_name = room_type == RoomType::builder ? "builder" : room_type == RoomType::archer ? "archer" : "knight";
    
    CBlob@[] bs;
    getBlobsByTag("owner_tag_" + pid, @bs);

    CBlob@ target = bs.length > 0 ? bs[0] : null;
    Vec2f pos = target !is null ? target.getPosition() : player_blob !is null ? player_blob.getPosition() : Vec2f(0, 0);

    if (player_blob !is null && player_blob.getName() == new_blob_name) return; // already correct class
    CBlob@ new_blob = server_CreateBlob(new_blob_name, p.getTeamNum(), pos);
    new_blob.server_SetPlayer(p);
    player_blob.server_Die();
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
    // if (isClient() && isServer() && getControls().isKeyPressed(KEY_LSHIFT))
    // {
    //     map.server_SetTile(getControls().getMouseWorldPos(), CMap::tile_castle);
    // }

    if (!isServer()) return;
	for (u8 i = 0; i < getPlayersCount(); i++)
	{
		CPlayer@ p = getPlayer(i);
		if (p is null) continue;

		string username = p.getUsername();
		RoomPNGLoader@ loader;
		if (this.get("room_loader_" + username, @loader))
		{
			if (loader !is null)
			{
				loader.loadRoom();
			}
		}
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