#include "PNGLoader.as";
#include "RoomsCommon.as";
#include "RoomsHandlers.as";

void onInit(CRules@ this)
{
    onRestart(this);
    
    if (isClient())
    {
        this.set_u8("captured_room_id", 255); // none

        CBitStream params;
        params.write_bool(true); // request sync
        this.SendCommand(this.getCommandID("create_rooms_grid"), params);
    }
}

void onRestart(CRules@ this)
{
    // clear current room info
    this.set_u8("current_level_type", 0);
    this.set_s32("current_level_id", -1);

    this.set_Vec2f("current_room_pos", Vec2f(0,0));
    this.set_Vec2f("current_room_size", Vec2f(0,0));
    this.set_Vec2f("current_room_center", Vec2f(0,0));
    
    // clear pathline test data
    this.set_u8("test_pathline_state", 0); // hidden
    this.set_u32("test_pathline_start_time", 0);
    this.set_bool("recording_pathline", false);
    cached_positions.clear();

    // set captured room data to none
    this.set_u8("captured_room_id", 255);
    u8[] room_ids;
    u16[] room_owners;
    this.set("room_ids", @room_ids);
    this.set("room_owners", @room_owners);

    CreateRoomsGrid(this);
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
        if (!params.saferead_u16(rooms_count)) {print("Failed to read rooms count [0]"); return;}

        Vec2f[] room_coords;
        for (uint i = 0; i < rooms_count; i++)
        {
            Vec2f room_pos;
            if (!params.saferead_Vec2f(room_pos)) {print("Failed to read room pos"); return;}
            room_coords.push_back(room_pos);
        }

        CreateRoomsGrid(this, room_coords);
        print("Received rooms grid with " + room_coords.length + " rooms");

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

        u8 level_type;
        if (!params.saferead_u8(level_type)) {print("Failed to read room type"); return;}

        int level_id;
        if (!params.saferead_s32(level_id)) {print("Failed to read level id"); return;}

        Vec2f room_size;
        if (!params.saferead_Vec2f(room_size)) {print("Failed to read room size"); return;}

        Vec2f start_pos;
        if (!params.saferead_Vec2f(start_pos)) {print("Failed to read start pos"); return;}

        print("Loaded level " + level_id + " of type " + level_type + " with size " + room_size + " at pos " + start_pos);

        // set client vars
        if (p.isMyPlayer())
        {
            this.set_u8("current_level_type", level_type);
            this.set_s32("current_level_id", level_id);

            this.set_Vec2f("current_room_pos", start_pos);
            this.set_Vec2f("current_room_size", room_size);
            this.set_Vec2f("current_room_center", start_pos + room_size * 0.5f);

            error("Client: set current room to " + level_id + " of type " + level_type + " at pos " + start_pos);
        }

        string file = level_type == RoomType::chess ? "ChessLevel.png" : GetRoomFile(level_type, level_id);
        CFileImage fm(file);
        if (!fm.isLoaded())
        {
            print("Room file " + file + " not found, loading empty room");
            file = "Maps/Hub.png";
        }

        EraseRoom(this, start_pos, room_size); // tag for room creation
        CreateRoomFromFile(this, file, start_pos, pid);
        onRoomCreated(this, level_type, level_id, pid);
    }
    else if (cmd == this.getCommandID("create_room"))
    {
        if (!isServer()) return;

        u16 pid;
        if (!params.saferead_u16(pid)) {print("Failed to read player id"); return;}

        CPlayer@ p = getPlayerByNetworkId(pid);
        if (p is null) return;
        
        u8[]@ room_ids;
        if (!this.get("room_ids", @room_ids)) {print("Failed to get room ids"); return;}

        u16[]@ room_owners;
        if (!this.get("room_owners", @room_owners)) {print("Failed to get room owners"); return;}

        if (room_ids is null || room_owners is null)
        {
            print("Room ids or owners not found");
            return;
        }

        if (room_ids.length != room_owners.length)
        {
            print("Room ids and owners length mismatch");
            return;
        }

        u8 free_room_id = 255;
        // check if we own one already and set that one instead
        for (uint i = 0; i < room_ids.size(); i++)
        {
            if (room_owners[i] == pid) // already owned
            {
                print("Player " + p.getUsername() + " already owns room id " + room_ids[i]);
                free_room_id = room_ids[i];
                break;
            }
        }

        if (free_room_id == 255)
        {
            // find a free room to claim
            for (uint i = 0; i < room_ids.size(); i++)
            {
                if (room_owners[i] == 0) // unowned
                {
                    //free_room_id = room_ids[i];
                    //room_owners[i] = pid; // claim ownership
                    break;
                }
            }
            free_room_id = XORRandom(6);
            room_owners[free_room_id] = pid; // claim ownership
        }
        
        CBitStream params1;
        params1.write_u16(pid);
        params1.write_u8(free_room_id);
        params1.write_u8(room_ids.size());
        for (uint i = 0; i < room_ids.size(); i++)
        {
            params1.write_u8(room_ids[i]);
            params1.write_u16(room_owners[i]);
        }
        this.SendCommand(this.getCommandID("sync_room_owners"), params1);
    }
    else if (cmd == this.getCommandID("sync_room_owners"))
    {
        if (!isClient()) return;

        u16 pid;
        if (!params.saferead_u16(pid)) {print("Failed to read player id"); return;}

        u8 free_room_id;
        if (!params.saferead_u8(free_room_id)) {print("Failed to read free room id"); return;}

        u8 rooms_count;
        if (!params.saferead_u8(rooms_count)) {print("Failed to read rooms count [1]"); return;}

        u8[] room_ids;
        u16[] room_owners;

        for (uint i = 0; i < rooms_count; i++)
        {
            u8 room_id;
            if (!params.saferead_u8(room_id)) {print("Failed to read room id"); return;}
            room_ids.push_back(room_id);

            u16 owner_id;
            if (!params.saferead_u16(owner_id)) {print("Failed to read room owner id"); return;}
            room_owners.push_back(owner_id);
        }

        print("Synced room owners with " + rooms_count + " rooms count, " + room_ids.length + " room ids and " + room_owners.length + " owners");
        
        this.set("room_ids", @room_ids);
        this.set("room_owners", @room_owners);

        CPlayer@ p = getPlayerByNetworkId(pid);
        if (p !is null)
        {
            print("Player " + p.getUsername() + " assigned room id " + free_room_id);
            this.set_u8("captured_room_id", free_room_id);
            error("now id "+this.get_u8("captured_room_id"));
        }
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

void onRoomCreated(CRules@ this, u8 level_type, uint level_id, u16 pid)
{
    CPlayer@ p = getPlayerByNetworkId(pid);
    if (p is null) return;

    CBlob@ player_blob = p.getBlob();
    string new_blob_name = level_type == RoomType::builder ? "builder" : level_type == RoomType::archer ? "archer" : "knight";
    
    CBlob@[] bs;
    getBlobsByTag("owner_tag_" + pid, @bs);

    CBlob@ target = bs.length > 0 ? bs[0] : null;
    Vec2f pos = target !is null ? target.getPosition() : player_blob !is null ? player_blob.getPosition() : Vec2f(0, 0);

    if (player_blob !is null && player_blob.getName() == new_blob_name) return; // already correct class
    CBlob@ new_blob = server_CreateBlob(new_blob_name, p.getTeamNum(), pos);
    if (new_blob !is null) new_blob.server_SetPlayer(p);
    if (player_blob !is null) player_blob.server_Die();
}

void onReload(CRules@ this)
{
    Vec2f[]@ room_coords;
    if (this.get("room_coords", @room_coords))
    {
        @local_room_coords = @room_coords;
    }
}

void CreateRoomsGrid(CRules@ this, Vec2f[] override_room_coords = Vec2f[]())
{
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

        print("Creating rooms grid for map size " + map_width + "x" + map_height +" and room size " + ROOM_SIZE.x + "x" + ROOM_SIZE.y + " (" + cols + "x" + rows + ")");

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
                    print("Loading chess level at room index " + room_index + " pos (" + x + ", " + y + ")");
                    LoadChessLevel(this, Vec2f(x, y));
                    continue;
                }

                room_coords.push_back(Vec2f(x, y));
                room_ids.push_back(room_ids.length);
                room_owners.push_back(0); // no owner yet
            }
        }
    }

    print("Created rooms grid with " + room_coords.length + " rooms, " + room_ids.length + " ids, " + room_owners.length + " owners");

    @local_room_coords = @room_coords;
    this.set("room_coords", room_coords);

    this.set("room_ids", @room_ids);
    this.set("room_owners", @room_owners);
}

Vec2f[]@ local_room_coords;
void onRender(CRules@ this)
{
    if (!isClient()) return;
    u8 room_id = this.get_u8("captured_room_id");

    if (local_room_coords !is null)
    {
        // room_id of 255 means "none"
        if (room_id != 255)
        {
            uint idx = uint(room_id);
            if (idx < local_room_coords.length)
            {
                Vec2f room_pos = local_room_coords[idx];
                Vec2f room_size = ROOM_SIZE;

                Vec2f top_left = room_pos;
                Vec2f top_right = room_pos + Vec2f(room_size.x, 0);
                Vec2f bottom_left = room_pos + Vec2f(0, room_size.y);
                Vec2f bottom_right = room_pos + room_size;

                GUI::DrawLine(top_left, top_right, SColor(255, 255, 255, 255));
                GUI::DrawLine(top_right, bottom_right, SColor(255, 255, 255, 255));
                GUI::DrawLine(bottom_right, bottom_left, SColor(255, 255, 255, 255));
                GUI::DrawLine(bottom_left, top_left, SColor(255, 255, 255, 255));
            }
        }
    }

    if (pathline_test)
    {
        f32 y = 200.0f;

        string key = this.get_string("pathline_key");
        ConfigFile cfg;
        string[] positions_str;
        bool cfg_loaded = cfg.loadFile("../Cache/parkour_pathlines.cfg");
        cfg.readIntoArray_string(positions_str, key);

        string recording = this.get_bool("recording_pathline") ? "ON" : "OFF";
        GUI::DrawText("Pathline recording: " + recording, Vec2f(100, y), SColor(255, 255, 255, 0));

        GUI::DrawText("Pathline key: " + key, Vec2f(100, y + 20), SColor(255, 255, 255, 0));

        string pathline_state = this.get_u8("test_pathline_state") == 0 ? "HIDDEN" : "SHOWING";
        GUI::DrawText("Pathline test state: " + pathline_state, Vec2f(100, y + 40), SColor(255, 255, 255, 0));

        string showing_index = "Showing index: ";
        if (this.get_u8("test_pathline_state") == 1 && positions_str.length > 0)
        {
            u32 start_time = this.get_u32("test_pathline_start_time");
            int diff = getGameTime() - start_time;
            diff %= positions_str.length;
            showing_index += "" + diff;
        }
        else showing_index += "N/A";
        GUI::DrawText(showing_index, Vec2f(100, y + 60), SColor(255, 255, 255, 0));

        string quantity = "Positions cached: " + cached_positions.length;
        GUI::DrawText(quantity, Vec2f(100, y + 80), SColor(255, 255, 255, 0));

        string room_exists_in_config = "Room exists in config: ";
        if (!cfg_loaded) room_exists_in_config += "NO";
        else room_exists_in_config += positions_str.length > 0 ? "YES" : "NO";
        GUI::DrawText(room_exists_in_config, Vec2f(100, y + 100), SColor(255, 255, 255, 0));

        CMap@ map = getMap();
        if (map !is null)
        {
            string map_size = "Map size: " + (map.tilemapwidth) + " x " + (map.tilemapheight) + "   /   " + (map.tilemapwidth * map.tilesize) + " x " + (map.tilemapheight * map.tilesize);
            string player_coord = "Player pos: ";
            CBlob@ pblob = getLocalPlayerBlob();
            if (pblob !is null)
            {
                Vec2f ppos = pblob.getPosition();
                player_coord += "(" + int(ppos.x) + ", " + int(ppos.y) + ")";
            }
            else
            {
                player_coord += "N/A";
            }
            GUI::DrawText(map_size, Vec2f(100, y + 120), SColor(255, 255, 255, 0));
            GUI::DrawText(player_coord, Vec2f(100, y + 140), SColor(255, 255, 255, 0));
        }
    }

    // render each room id, its owner and coords
    if (local_room_coords !is null)
    {
        u8[]@ room_ids;
        if (!this.get("room_ids", @room_ids)) return;

        u16[]@ room_owners;
        if (!this.get("room_owners", @room_owners)) return;

        //print("Rendering " + room_ids.length + " room ids and owners");
        for (uint i = 0; i < room_ids.size(); i++)
        {
            Vec2f room_pos = local_room_coords[i];

            // determine owner name safely
            string owner_name = "none";
            u16 owner_id = 0;
            if (i < room_owners.length)
            {
                owner_id = room_owners[i];
                if (owner_id != 0)
                {
                    CPlayer@ owner_player = getPlayerByNetworkId(owner_id);
                    owner_name = owner_player !is null ? owner_player.getUsername() : "unknown";
                }
            }

            // build display text
            string text = "Room " + i + "; Position (" + int(room_pos.x) + ", " + int(room_pos.y) + "); Owner " + owner_name;
            
            Vec2f screen_pos = getDriver().getScreenPosFromWorldPos(Vec2f(room_pos.x + ROOM_SIZE.x * 0.5f, room_pos.y));
            GUI::DrawTextCentered(text, screen_pos, SColor(255, 255, 255, 255));

            // draw room ids and owners on screen in localhost
            screen_pos = Vec2f(800, 200 + i * 40);
            GUI::DrawText(text, screen_pos, SColor(255, 255, 255, 0));
        }
    }
}

void EnsureRoomsOwned(CRules@ this)
{
    if (!isServer()) return;
    u32 gt = getGameTime();

    u8[]@ room_ids;
    if (!this.get("room_ids", @room_ids))
    {
        if (gt % 30 == 0) error("EnsureRoomsOwned: failed to get room_ids");
        return;
    }

    u16[]@ room_owners;
    if (!this.get("room_owners", @room_owners))
    {
        if (gt % 30 == 0) error("EnsureRoomsOwned: failed to get room_owners");
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
                if (gt % 30 == 0) print("Room " + i + " owner disconnected, freeing room");
            }
        }
    }
}

const f32 MAX_POS = 20000.0f; // maximum absolute coordinate value
string[] cached_positions; // packed player path data as strings
bool pathline_test = true;

void onTick(CRules@ this)
{
    CMap@ map = getMap();
    if (map is null) return;
    if (!isServer()) return;

    EnsureRoomsOwned(this);

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

        string pathline_key = "_p_" + this.get_u8("current_level_type") + "_" + this.get_s32("current_level_id");
        this.set_string("pathline_key", pathline_key);

        ConfigFile cfg;
        if (!cfg.loadFile("../Cache/parkour_pathlines.cfg"))
        {
            cfg.saveFile("../Cache/parkour_pathlines.cfg");
        }
        cfg.loadFile("../Cache/parkour_pathlines.cfg");

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

            // snap to 0.1 precision
            Vec2f rpos = Vec2f(Maths::Round(player_pos.x * 10.0f) / 10.0f, Maths::Round(player_pos.y * 10.0f) / 10.0f);
            Vec2f rold = Vec2f(Maths::Round(player_old_pos.x * 10.0f) / 10.0f, Maths::Round(player_old_pos.y * 10.0f) / 10.0f);

            // compute room top-left offset for the room that contains the player and convert to room-local coords
            f32 room_x = Maths::Floor(rpos.x / ROOM_SIZE.x) * ROOM_SIZE.x;
            f32 room_y = Maths::Floor(rpos.y / ROOM_SIZE.y) * ROOM_SIZE.y;
            Vec2f room_offset = Vec2f(room_x, room_y);

            rpos -= room_offset;
            rold -= room_offset;

            player_pos = rpos;
            player_old_pos = rold;

            if (player_pos != player_old_pos)
            {
                u32 packed = PackVec2f(player_pos);
                cached_positions.push_back("" + packed); // store as string for ConfigFile
            }
        }
        // replay recorded path
        else if (pathline_state == 1)
        {
            string[] positions_str;
            cfg.readIntoArray_string(positions_str, pathline_key);

            int diff = getGameTime() - start_time;
            if (positions_str.length <= 0) return;
            
            diff %= positions_str.length;
            bool ok = (diff >= 0 && diff < positions_str.length);
            if (ok)
            {
                string old_s = "";
                int old_parsed = -1;
                bool has_old = false;
                if (diff > 0)
                {
                    old_s = positions_str[diff - 1];
                    old_parsed = parseInt(old_s);
                    has_old = (old_parsed != -1);
                }

                string s = positions_str[diff];
                int parsed = parseInt(s);
                ok = (parsed != -1);
                
                if (ok)
                {
                    u32 old_packed = u32(old_parsed);
                    u32 packed = u32(parsed);

                    Vec2f oldpos = has_old ? UnpackVec2f(u32(old_parsed)) : Vec2f(0,0);
                    Vec2f pos = UnpackVec2f(packed);
                    Vec2f offset = this.get_Vec2f("current_room_pos");

                    u32 quantity = 1;
                    if (has_old) quantity = u32(Maths::Ceil((pos - oldpos).Length()));
                    for (u32 i = 0; i < quantity; i++)
                    {
                        f32 t = quantity > 1 ? f32(i) / f32(quantity - 1) : 0.0f;
                        Vec2f interp = has_old ? oldpos + (pos - oldpos) * t : pos;
                        interp += offset;
                        int time = 15;

                        CParticle@ p = ParticleAnimated("PathlineCursor.png", interp, Vec2f(0,0), 0, 0, time, 0.0f, true);
                        if (p !is null)
                        {
                            p.gravity = Vec2f(0, 0);
                            p.scale = 0.5f;
                            p.timeout = time;
                            p.growth = -0.1f;
                            p.deadeffect = -1;
                            p.collides = false;

                            f32 sin = Maths::Sin(getGameTime() * 0.1f) * 0.5f + 0.5f;
                            SColor col = SColor(255, 255 - sin * 85, 255 - sin * 25, 255 - sin * 85);
                            p.colour = col;
                            p.forcecolor = col;

                            //p.setRenderStyle(RenderStyle::additive);
                        }
                    }
                }
            }
        }

        // save when recording stops
        bool stopped_recording = !recording_pathline && this.get_bool("recording_pathline");
        if (stopped_recording)
        {
            string[] to_save = cached_positions;
            if (cfg.exists(pathline_key)) cfg.remove(pathline_key); // clear old data
            cfg.addArray_string(pathline_key, to_save);

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
u32 PackVec2f(const Vec2f &in pos)
{
    u16 ex = EncodeCoord(pos.x);
    u16 ey = EncodeCoord(pos.y);
    return (u32(ex) << 16) | u32(ey);
}

// unpack u32 back to Vec2f
Vec2f UnpackVec2f(u32 packed)
{
    u16 ex = u16((packed >> 16) & 0xFFFF);
    u16 ey = u16(packed & 0xFFFF);
    return Vec2f(DecodeCoord(ex), DecodeCoord(ey));
}
