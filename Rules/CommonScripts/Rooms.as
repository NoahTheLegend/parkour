#include "KGUI.as";
#include "PNGLoader.as";
#include "RoomsCommon.as";
#include "RoomsListeners.as";
#include "RoomsHandlers.as";
#include "RoomsHooks.as";
#include "Helpers.as";
#include "CommandHandlers.as";

void onInit(CRules@ this)
{
    onRestart(this);
    
    if (isClient())
    {
        this.set_u8("captured_room_id", 255); // none

        CBitStream params;
        params.write_bool(true); // request a sync
        this.SendCommand(this.getCommandID("create_rooms_grid"), params);
    }
}

void onRestart(CRules@ this)
{
    this.Untag("was_init");

    // clear current room info
    this.set_u8("current_level_type", 0);
    this.set_s32("current_level_id", -1);

    this.set_string("_client_message", "");
    this.set_u32("_client_message_time", 0);

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
}

void onReload(CRules@ this)
{
    Vec2f[]@ room_coords;
    if (this.get("room_coords", @room_coords))
    {
        @local_room_coords = @room_coords;
    }
}

void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{
    if (cmd == this.getCommandID("create_rooms_grid"))
    {
        CreateRoomsGridCommand(this, params);
    }
    else if (cmd == this.getCommandID("set_room"))
    {
        SetRoomCommand(this, params);
        UpdatePathlineData(this);
    }
    else if (cmd == this.getCommandID("create_room"))
    {
        CreateRoomCommand(this, params);
        UpdatePathlineData(this);
    }
    else if (cmd == this.getCommandID("sync_room_owners"))
    {
        SyncRoomOwnerCommand(this, params);
    }
    else if (cmd == this.getCommandID("editor"))
    {
        UpdatePathlineData(this);

        // todo, wip
        u16 pid;
        if (!params.saferead_u16(pid)) {print("[CMD] Failed to read player id"); return;}

        CPlayer@ p = getPlayerByNetworkId(pid);
        if (p is null) return;

        CRules@ rules = getRules();
        if (rules is null) return;

        bool is_editor = rules.get_bool("editor_mode_" + pid);
        rules.set_bool("editor_mode_" + pid, !is_editor);

        SetClientMessage(pid, "Editor hasn't been done yet. This was kept as a placeholder.");
    }
    else if (cmd == this.getCommandID("set_client_message"))
    {
        ClientMessageCommand(this, params);
    }
}

bool cfg_loaded = false;
ConfigFile@ pathline_cfg = @ConfigFile();
string[] positions_str;

void onRender(CRules@ this)
{
    if (!isClient()) return;
    GUI::SetFont("menu");

    u8 room_id = this.get_u8("captured_room_id");
    RenderMessages(this);

    string pathline_key = this.exists("pathline_key") ? this.get_string("pathline_key") : "";

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

    if (debug_test)
    {
        f32 y = 200.0f;

        string recording = this.get_bool("recording_pathline") ? "ON" : "OFF";
        GUI::DrawText("Pathline recording: " + recording, Vec2f(100, y), SColor(255, 255, 255, 0));

        GUI::DrawText("Pathline key: " + pathline_key, Vec2f(100, y + 20), SColor(255, 255, 255, 0));

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

void RenderMessages(CRules@ this)
{
    u32 gt = getGameTime();

    // client message
    u32 msg_time = this.get_u32("_client_message_time");
    string msg = this.get_string("_client_message");
    Vec2f pane_size = this.get_Vec2f("_client_message_size");
    if (msg_time != 0)
    {
        f32 ft = 10.0f;
        f32 kt = 90.0f + msg.size() * 3;
        f32 et = 10.0f;

        int diff = gt - msg_time;
        f32 fade = diff < ft ? diff / ft : diff < ft + kt ? 1.0f : 1.0f - Maths::Clamp((diff - ft - kt) / et, 0.0f, 1.0f);
        if (diff >= ft + kt + et)
        {
            this.set_u32("_client_message_time", 0);
            this.set_string("_client_message", "");
            this.set_Vec2f("_client_message_size", Vec2f(0,0));
        }

        string font = "Terminus_14";
        GUI::SetFont(font);

        Vec2f screen_size = getDriver().getScreenDimensions();
        Vec2f extra = Vec2f(6, 6);

        f32 offset = fade * (pane_size.y + 8 + extra.y * 2);
        Vec2f pane_pos = Vec2f(screen_size.x - pane_size.x - 8 - extra.x, -pane_size.y - 8 + offset);

        GUI::DrawPane(pane_pos - extra, pane_pos + pane_size + extra, SColor(fade * 255, 75, 125, 235));
        GUI::DrawText(msg, pane_pos - Vec2f(1, 1), SColor(fade * 255, 255, 255, 255));
    }
}

bool debug_test = true;
void onTick(CRules@ this)
{
    if (!this.hasTag("was_init")) CreateRoomsGrid(this);
    if (!cfg_loaded) UpdatePathlineData(this);

    CMap@ map = getMap();
    if (map is null) return;
    if (!isServer()) return;

    EnsureRoomsOwned(this);
    RunRoomLoaders(this);

    string pathline_key = this.exists("pathline_key") ? this.get_string("pathline_key") : "";

    // developer localhost only, todo
    if (isClient() && isServer())
    {
        CControls@ controls = getControls();
        if (controls is null) return;

        u8 pathline_state = this.get_u8("test_pathline_state");
        u32 start_time = this.get_u32("test_pathline_start_time");
        bool recording_pathline = this.get_bool("recording_pathline");

        bool show_pathline = this.get_bool("enable_pathline");
        if (show_pathline)
        {
            // display
            if (controls.isKeyJustPressed(KEY_LCONTROL)) start_time = getGameTime();
            pathline_state = controls.isKeyPressed(KEY_LCONTROL) ? 1 : 0;
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

            if (player_pos != player_old_pos || pblob.isKeyPressed(key_left) || pblob.isKeyPressed(key_right))
            {
                u32 packed = PackVec2f(player_pos);
                cached_positions.push_back("" + packed); // store as string for config
            }
        }
        // replay recorded path
        else if (pathline_state == 1)
        {
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
                        int time = 60;

                        CParticle@ p = ParticleAnimated("PathlineCursor.png", interp, Vec2f(0,0), 0, 0, time, 0.0f, true);
                        if (p !is null)
                        {
                            p.gravity = Vec2f(0, 0);
                            p.scale = 0.75f;
                            p.timeout = time;
                            p.growth = -0.05f;
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
        if (stopped_recording && cached_positions.length > 0)
        {
            if (pathline_cfg.exists(pathline_key)) pathline_cfg.remove(pathline_key);
            pathline_cfg.addArray_string(pathline_key, cached_positions);
            pathline_cfg.saveFile("parkour_pathlines.cfg");

            print("[INF] Saved pathline with " + cached_positions.length + " positions to key " + pathline_key);
            cached_positions.clear();
            
            // update cfg_loaded and pathline_key, then set positions_str
            UpdatePathlineData(this);
        }

        this.set_u8("test_pathline_state", pathline_state);
        this.set_u32("test_pathline_start_time", start_time);
        this.set_bool("recording_pathline", recording_pathline);
    }
}

void UpdatePathlineData(CRules@ this)
{
    string pathline_key = "_p_" + this.get_u8("current_level_type") + "_" + this.get_s32("current_level_id");
    this.set_string("pathline_key", pathline_key);

    if (pathline_cfg is null)
    {
        @pathline_cfg = @ConfigFile();
        warn("[WRN] Client: pathline_cfg was null, recreated");
    }

    ConfigFile@ empty = @ConfigFile();
    @pathline_cfg = @empty;

    cfg_loaded = pathline_cfg.loadFile("../Cache/parkour_pathlines.cfg");
    positions_str.clear();

    pathline_cfg.readIntoArray_string(positions_str, pathline_key);
    print("[INF] Client: updated pathline data for key " + pathline_key + " with " + positions_str.length + " positions, new size: " + positions_str.length);
}