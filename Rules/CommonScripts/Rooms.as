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

        CPlayer@ p = getPlayerByNetworkId(pid);
        if (p is null) return;

        string user_call = "last_room_set_time_" + p.getUsername();
        if (this.exists(user_call) && getGameTime() - this.get_u32(user_call) < base_room_set_delay)
        {
            print("Ignoring rapid room set request from " + p.getUsername());
            return;
        }
        this.set_u32(user_call, getGameTime());

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
        if (p.isMyPlayer())
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
    else if (cmd == this.getCommandID("editor"))
    {
        u16 pid;
        if (!params.saferead_u16(pid)) {print("Failed to read player id"); return;}

        CPlayer@ p = getPlayerByNetworkId(pid);
        if (p is null) return;

        CRules@ rules = getRules();
        if (rules is null) return;

        bool is_editor = rules.get_bool("editor_mode_" + pid);
        rules.set_bool("editor_mode_" + pid, !is_editor);
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

void onReload(CRules@ this)
{
    Vec2f[]@ rooms_coords;
    if (this.get("rooms_coords", @rooms_coords))
    {
        @local_rooms_coords = @rooms_coords;
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

    if (pathline_test)
    {
        f32 y = 200.0f;

        string recording = this.get_bool("recording_pathline") ? "ON" : "OFF";
        GUI::DrawText("Pathline recording: " + recording, Vec2f(100, y), SColor(255, 255, 255, 0));
    
        string key = this.get_string("pathline_key");
        GUI::DrawText("Pathline key: " + key, Vec2f(100, y + 20), SColor(255, 255, 255, 0));

        string pathline_state = this.get_u8("test_pathline_state") == 0 ? "HIDDEN" : "SHOWING";
        GUI::DrawText("Pathline test state: " + pathline_state, Vec2f(100, y + 40), SColor(255, 255, 255, 0));

        string quantity = "Positions cached: " + cached_positions.length;
        GUI::DrawText(quantity, Vec2f(100, y + 60), SColor(255, 255, 255, 0));
    }
}

const f32 MAX_POS = 20000.0f; // maximum absolute coordinate value
u32[] cached_positions; // packed player path data
bool pathline_test = true;

void onTick(CRules@ this)
{
	CMap@ map = getMap();
	if (map is null) return;
	if (!isServer()) return;

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

	// developer localhost only
	if (isClient() && isServer())
	{
		CControls@ controls = getControls();
		if (controls is null) return;

		string pathline_key = "_p_" + this.get_u8("current_room_type") + "_" + this.get_s32("current_room_id");
		this.set_string("pathline_key", pathline_key);

		ConfigFile cfg;
		if (!cfg.loadFile("parkour_pathlines.cfg"))
			cfg.saveFile("parkour_pathlines.cfg");

        cfg.loadFile("parkour_pathlines.cfg");

		u8 pathline_state = this.get_u8("test_pathline_state");
		u32 start_time = this.get_u32("test_pathline_start_time");
		bool recording_pathline = this.get_bool("recording_pathline");

		// toggle display/record mode
		if (controls.isKeyJustPressed(KEY_LCONTROL))
		{
			Sound::Play("ButtonClick.ogg");
			pathline_state = (pathline_state + 1) % 2;
			start_time = getGameTime();
		}

		// toggle record on/off
		if (controls.isKeyJustPressed(KEY_MBUTTON))
        {
            Sound::Play2D("ButtonClick.ogg", 1.0f, 1.5f);
			recording_pathline = !recording_pathline;
        }

		// record player path
		if (recording_pathline)
		{
			CBlob@ pblob = getLocalPlayerBlob();
			if (pblob is null) return;

			Vec2f player_pos = pblob.getPosition();
			Vec2f player_old_pos = pblob.getOldPosition();

			if (player_pos != player_old_pos)
			{
				u32 packed = PackVec2(player_pos);
				cached_positions.push_back(packed);
			}
		}
		// replay recorded path
        else if (pathline_state == 1)
        {
            int diff = getGameTime() - start_time;
            u32[] positions_u32;
            cfg.readIntoArray_u32(positions_u32, pathline_key);

            bool ok = (diff >= 0 && diff < positions_u32.length);
            if (ok)
            {
                u32 packed_u32 = positions_u32[diff];
                ok = (packed_u32 != -1);
                if (ok)
                {
                    u32 packed = u32(packed_u32);
                    Vec2f pos = UnpackVec2(packed);

                    CParticle@ p = ParticlePixelUnlimited(pos, Vec2f(0,0), SColor(255, 0, 255, 0), true);
                    if (p !is null)
                    {
                        p.gravity = Vec2f(0, 0);
                        p.scale = 1.0f;
                        p.timeout = 1;
                        p.collides = false;
                    }
                }
            }
        }

		// save when recording stops
		bool stopped_recording = !recording_pathline && this.get_bool("recording_pathline");
		if (stopped_recording && cached_positions.length > 0)
		{
			u32[] to_save = cached_positions;
			cfg.addArray_u32(pathline_key, to_save); // crashes the game? todo
			cfg.saveFile("parkour_pathlines.cfg");
			cached_positions.clear();
    
            print("Saved pathline with " + to_save.length + " positions to key " + pathline_key);
        }

		this.set_u8("test_pathline_state", pathline_state);
		this.set_u32("test_pathline_start_time", start_time);
		this.set_bool("recording_pathline", recording_pathline);
	}
}

// encode single coordinate (-MAX_POS..+MAX_POS) to u16 (0..65535)
u16 EncodeCoord(f32 value)
{
	if (value < -MAX_POS) value = -MAX_POS;
	if (value >  MAX_POS) value =  MAX_POS;
	f32 norm = (value + MAX_POS) / (2.0f * MAX_POS);
	return u16(Maths::Round(norm * 65535.0f));
}

// decode u16 (0..65535) back to coordinate (-MAX_POS..+MAX_POS)
f32 DecodeCoord(u16 encoded)
{
	f32 norm = f32(encoded) / 65535.0f;
	return norm * (2.0f * MAX_POS) - MAX_POS;
}

// pack Vec2f into u32 (16 bits x, 16 bits y)
u32 PackVec2(const Vec2f &in pos)
{
	u16 ex = EncodeCoord(pos.x);
	u16 ey = EncodeCoord(pos.y);
	return (u32(ex) << 16) | u32(ey);
}

// unpack u32 back to Vec2f
Vec2f UnpackVec2(u32 packed)
{
	u16 ex = u16((packed >> 16) & 0xFFFF);
	u16 ey = u16(packed & 0xFFFF);
	return Vec2f(DecodeCoord(ex), DecodeCoord(ey));
}
