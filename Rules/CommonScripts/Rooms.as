#include "KGUI.as";
#include "PNGLoader.as";
#include "RoomsCommon.as";
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
    this.set_u8("pathline_state", 0); // hidden
    this.set_u32("pathline_start_time", 0);
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

        if (this.get_bool("close_on_room_select")) this.Tag("close_menu");
    }
    else if (cmd == this.getCommandID("create_room"))
    {
        CreateRoomCommand(this, params);
        UpdatePathlineData(this);
    }
    else if (cmd == this.getCommandID("sync_room"))
    {
        SyncRoomCommand(this, params);
        UpdatePathlineData(this);
    }
    else if (cmd == this.getCommandID("sync_room_owners"))
    {
        SyncRoomOwnerCommand(this, params);
    }
    else if (cmd == this.getCommandID("room_chatcommand"))
    {
        RoomChatCommand(this, params);
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

    CControls@ controls = getControls();
    if (controls !is null)
    {
        if (controls.isKeyJustPressed(KEY_RSHIFT))
        {
            debug_test = !debug_test;
            Sound::Play2D("ButtonClick.ogg", 1.0f, 1.5f);
        }
    }

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

        string pathline_state = this.get_u8("pathline_state") == 0 ? "HIDDEN" : "SHOWING";
        GUI::DrawText("Pathline test state: " + pathline_state, Vec2f(100, y + 40), SColor(255, 255, 255, 0));

        string showing_index = "Showing index: ";
        if (this.get_u8("pathline_state") == 1 && positions_str.length > 0)
        {
            u32 start_time = this.get_u32("pathline_start_time");
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

    // render miscellaneous info
    int level_id = this.get_s32("current_level_id");
    int current_complexity = this.get_s32("current_level_complexity");
    string type_name = this.get_string("current_level_type_name");

    GUI::SetFont("Terminus_18");
    GUI::DrawText("LEVEL: " + type_name + " " + level_id, Vec2f(10, 10), SColor(255, 255, 255, 255));
    GUI::DrawText("COMPLEXITY: ", Vec2f(10, 30), SColor(255, 255, 255, 255));
    // colored text
    // todo
    SColor col = SColor(255, 255, 255, 255);
    GUI::DrawText("" + current_complexity, Vec2f(128, 30), col);
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
    if (isServer() && getGameTime() == 30 && this.exists("update_hub_pos"))
    {
        Vec2f hub_pos = this.get_Vec2f("update_hub_pos");
		CBlob@[] blobs;
		map.getBlobsInBox(hub_pos, hub_pos + ROOM_SIZE, @blobs);

		for (uint i = 0; i < blobs.length; i++)
		{
			CBlob@ b = blobs[i];
			b.Tag("room_loader_done");
		}
    }

    PathlineTick(this, pathline_key);
}

void PathlineTick(CRules@ this, const string &in pathline_key)
{
    if (isServer())
    {
        for (u8 i = 0; i < getPlayersCount(); i++)
        {
            CPlayer@ p = getPlayer(i);
            if (p is null) continue;

            CBlob@[] personal_pathline;
            if (!getBlobsByTag("personal_pathline_" + p.getNetworkID(), @personal_pathline))
            {
                CBlob@ pathline_blob = server_CreateBlob("pathline", -1, Vec2f(0,0));
                if (pathline_blob !is null)
                {
                    pathline_blob.Tag("personal_pathline_" + p.getNetworkID());
                    pathline_blob.set_u16("pathline_test_owner_id", p.getNetworkID());

                    this.set_u16("pathline_test_blob_id", pathline_blob.getNetworkID());
                    this.Sync("pathline_test_blob_id", true);
                }
            }
        }
    }

    u8 pathline_state = this.get_u8("pathline_state");
    u32 start_time = this.get_u32("pathline_start_time");
    bool recording_pathline = this.get_bool("recording_pathline");
    Vec2f recording_startpos = this.get_Vec2f("recording_startpos");

    bool show_pathline = this.get_bool("enable_pathline");
    u16 pathline_blob_id = this.get_u16("pathline_test_blob_id");

    CBlob@ pblob = getBlobByNetworkID(pathline_blob_id);
    if (pblob is null) return;

    Vec2f player_pos = pblob.getPosition();
    Vec2f player_old_pos = pblob.getOldPosition();

    // manage controls & debug
    if (isClient())
    {
        CControls@ controls = getControls();
        if (controls is null) return;

        // toggle record on/off
        if (isServer() && controls.isKeyJustPressed(KEY_MBUTTON)) // for localhost only
        {
            Sound::Play2D("ButtonClick.ogg", 1.0f, 1.5f);

            recording_pathline = !recording_pathline;
            CBlob@ local_player_blob = getLocalPlayerBlob();
            if (local_player_blob !is null)
            {
                recording_startpos = local_player_blob.getPosition();
            }

            //CBitStream params;
            //params.write_bool(recording_pathline);
            //params.write_Vec2f(recording_startpos);
            //this.SendCommand(this.getCommandID("sync_pathline_to_server"), params);
        }

        if (show_pathline)
        {
            // display
            if (controls.isKeyJustPressed(KEY_LCONTROL)) start_time = getGameTime();
            pathline_state = controls.isKeyPressed(KEY_LCONTROL) ? 1 : 0;
        }
    }

    bool is_archer = false;
    if (isServer())
    {
        if (recording_pathline)
        {
            CBlob@ local_player_blob = getLocalPlayerBlob();
            if (local_player_blob !is null)
            {
                player_pos = local_player_blob.getPosition();
                player_old_pos = local_player_blob.getOldPosition();

                is_archer = local_player_blob.getName() == "archer";
            }

            RecordPathline(this, local_player_blob, recording_startpos, player_pos, player_old_pos);
        }
        // replay recorded path (now stored as pairs when archer)
        else if (pathline_state == 1)
        {
            int diff = getGameTime() - start_time;
            if (positions_str.length <= 0) return;

            // if positions were stored as pairs (archer), treat entries as pairs count.
            int entries = positions_str.length;
            bool pairs_mode = !is_archer && (entries % 2 == 0 && entries >= 2);
            int frames = pairs_mode ? entries / 2 : entries;

            if (frames <= 0) return;

            diff %= frames;
            bool ok = (diff >= 0 && diff < frames);
            if (ok)
            {
                // main indices
                int mainIndex = diff * (pairs_mode ? 2 : 1);
                int prevIndex = (diff > 0) ? (mainIndex - (pairs_mode ? 2 : 1)) : -1;

                string old_s = "";
                int old_parsed = -1;
                bool has_old = false;
                if (prevIndex >= 0)
                {
                    old_s = positions_str[prevIndex];
                    old_parsed = parseInt(old_s);
                    has_old = (old_parsed != -1);
                }

                string s = positions_str[mainIndex];
                int parsed = parseInt(s);
                ok = (parsed != -1);

                // grapple index (if pairs_mode)
                int grappleIndex = pairs_mode ? mainIndex + 1 : -1;
                int grapple_parsed = -1;
                if (pairs_mode && grappleIndex < positions_str.length)
                {
                    string gs = positions_str[grappleIndex];
                    grapple_parsed = parseInt(gs); // may be -1 if invalid
                }

                if (ok)
                {
                    RunPathline(this, pblob, parsed, has_old, old_parsed, grapple_parsed);
                }
            }
        }
    }

    // save when recording stops
    bool stopped_recording = !recording_pathline && this.get_bool("recording_pathline");
    if (stopped_recording) print(cached_positions.length + " positions recorded for pathline key " + pathline_key);
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

    this.set_u8("pathline_state", pathline_state);
    this.set_u32("pathline_start_time", start_time);
    this.set_bool("recording_pathline", recording_pathline);
    this.set_Vec2f("recording_startpos", recording_startpos);
}

void RunPathline(CRules@ this, CBlob@ pblob, int parsed, bool has_old, int old_parsed, int grapple_parsed)
{
    u32 packed = u32(parsed);
    Vec2f room_pos = this.get_Vec2f("current_room_pos");

    Vec2f pos = UnpackVec2f(packed);
    Vec2f oldpos = has_old ? UnpackVec2f(u32(old_parsed)) : Vec2f(0,0);

    bool exists_anchor_pos = this.exists("current_anchor_pos");
    Vec2f anchor_pos = exists_anchor_pos ? this.get_Vec2f("current_anchor_pos") : Vec2f(0, 0);
    Vec2f anchor_offset_to_room = exists_anchor_pos ? anchor_pos : Vec2f(0, 0);
    Vec2f endpos = pos + room_pos + anchor_offset_to_room;

    Vec2f gpos_rel = grapple_parsed != -1 ? UnpackVec2f(u32(grapple_parsed)) + anchor_offset_to_room : endpos;
    Vec2f gpos = gpos_rel;

    // particles
    // ensure at least one particle even if pos == oldpos
    u32 quantity = 1;
    if (has_old)
    {
        int raw = Maths::Ceil((pos - oldpos).Length());
        quantity = raw > 0 ? u32(raw) : 1;
    }

    if (isClient())
    {
        for (u32 i = 0; i < quantity; i++)
        {
            f32 t = quantity > 1 ? f32(i) / f32(quantity - 1) : 0.0f;
            Vec2f interp = has_old ? oldpos + (pos - oldpos) * t : pos;

            // world position for this particle (trail)
            interp += anchor_offset_to_room;
            int time = 30;

            // determine world end position (current player pos)
            Vec2f world_endpos = endpos; // already includes room_pos and anchor offset

            // draw grapple line (only once per frame, from endpos to grapple pos)
            if (grapple_parsed != -1 && grapple_parsed != parsed && i == quantity - 1)
            {
                Vec2f dir = gpos - world_endpos;
                f32 dist = dir.Length();
                if (dist > 16.0f)
                {
                    // particle spacing: roughly one particle per 8 pixels (tweak as needed)
                    f32 spacing = 1.0f;
                    u32 line_qty = u32(Maths::Ceil(dist / spacing));
                    if (line_qty == 0) line_qty = 1;

                    for (u32 j = 0; j < line_qty; j++)
                    {
                        f32 tt = line_qty > 1 ? f32(j) / f32(line_qty - 1) : 0.0f;
                        Vec2f at = world_endpos + dir * tt;
                        u8 ctime = Maths::Max(2, tt * 1);

                        CParticle@ lp = ParticleAnimated("PathlineCursorGrapple.png", at, Vec2f(0,0), 0, 0, ctime, 0.0f, true);
                        if (lp !is null)
                        {
                            lp.fastcollision = true;
                            lp.gravity = Vec2f(0, 0);
                            lp.scale = 0.25f;
                            lp.growth = -0.01f;
                            lp.deadeffect = -1;
                            lp.collides = false;
                            lp.Z = 50.0f;
                        }
                    }
                }
            }

            // main particle: use endpos for the current position (put trail particles at interp, final one at endpos)
            Vec2f particle_pos = (i == quantity - 1) ? world_endpos : interp;

            CParticle@ p = ParticleAnimated("PathlineCursor.png", particle_pos, Vec2f(0,0), 0, 0, time, 0.0f, true);
            if (p !is null)
            {
                p.fastcollision = true;
                p.gravity = Vec2f(0, 0);
                p.scale = 0.75f;
                p.growth = -0.05f;
                p.deadeffect = -1;
                p.collides = false;

                f32 sin = Maths::Sin(getGameTime() * 0.1f) * 0.5f + 0.5f;
                SColor col = SColor(255, 255 - sin * 85, 255 - sin * 25, 255 - sin * 85);
                p.colour = col;
                p.forcecolor = col;
            }
        }
    }

    // update vars
    if (isServer())
    {
        pblob.setPosition(endpos);
        pblob.setAimPos(gpos);
    }
}

void RecordPathline(CRules@ this, CBlob@ local_player_blob, Vec2f recording_startpos,
                    Vec2f player_pos, Vec2f player_old_pos)
{
    // snap to 0.1 precision
    Vec2f rpos = Vec2f(Maths::Round((player_pos.x - recording_startpos.x) * 10.0f) / 10.0f,
                       Maths::Round((player_pos.y - recording_startpos.y) * 10.0f) / 10.0f);

    Vec2f rold = Vec2f(Maths::Round((player_old_pos.x - recording_startpos.x) * 10.0f) / 10.0f,
                        Maths::Round((player_old_pos.y - recording_startpos.y) * 10.0f) / 10.0f);

    player_pos = rpos;
    player_old_pos = rold;

    // prepare grapple value (relative) if archer
    bool is_archer = (local_player_blob.getName() == "archer");
    Vec2f grapple_rel = Vec2f(0,0);

    if (is_archer)
    {
        Vec2f gpos = this.get_Vec2f("grapple_pos");
        grapple_rel = Vec2f(Maths::Round((gpos.x - recording_startpos.x) * 10.0f) / 10.0f,
                            Maths::Round((gpos.y - recording_startpos.y) * 10.0f) / 10.0f);
    }

    if (player_pos != player_old_pos || local_player_blob.isKeyPressed(key_action1) || local_player_blob.isKeyPressed(key_action2))
    {
        u32 packed = PackVec2f(player_pos);
        cached_positions.push_back("" + packed); // main pos

        // if archer, also store grapple pos right after main pos
        if (is_archer)
        {
            u32 packed_grapple = PackVec2f(grapple_rel);
            cached_positions.push_back("" + packed_grapple);
        }
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