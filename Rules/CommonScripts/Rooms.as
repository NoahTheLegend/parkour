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
    this.set_s32("current_level_complexity", 0);

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
    u8[] level_types;
    u16[] level_ids;
    u16[] room_owners;
    this.set("room_ids", @room_ids);
    this.set("level_types", @level_types);
    this.set("level_ids", @level_ids);
    this.set("room_owners", @room_owners);
}

void onReload(CRules@ this)
{
    Vec2f[]@ room_coords;
    if (this.get("room_coords", @room_coords))
    {
        @local_room_coords = @room_coords;
    }

    // reload config
    @pathline_cfg = ConfigFile();
    cfg_loaded = pathline_cfg.loadFile("../Cache/parkour_pathlines.cfg");
    print("Reloaded config? " + pathline_cfg.exists("_p_1_31_0"));
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

        if (this.get_bool("close_on_room_select")) this.Tag("close_menu");
    }
    else if (cmd == this.getCommandID("create_room"))
    {
        CreateRoomCommand(this, params);
    }
    else if (cmd == this.getCommandID("sync_room"))
    {
        SyncRoomCommand(this, params);
    }
    else if (cmd == this.getCommandID("sync_room_owners"))
    {
        SyncRoomOwnerCommand(this, params);
    }
    else if (cmd == this.getCommandID("room_chatcommand"))
    {
        if (this.exists("_last_room_chatcommand_time"))
        {
            u32 last_time = this.get_u32("_last_room_chatcommand_time");
            if (getGameTime() - last_time < base_room_set_delay)
            {
                return;
            }
        }
        this.set_u32("_last_room_chatcommand_time", getGameTime());
        RoomChatCommand(this, params);
    }
    else if (cmd == this.getCommandID("editor"))
    {
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

void onRender(CRules@ this)
{
    if (!isClient()) return;
    GUI::SetFont("menu");

    u8 room_id = this.get_u8("captured_room_id");
    RenderMessages(this);

    // render miscellaneous info
    int level_id = this.get_s32("current_level_id");
    int current_complexity = this.get_s32("current_level_complexity");
    string type_name = this.get_string("current_level_type_name");

    f32 offset = 0;
    #ifdef STAGING
    offset = 20;
    #endif
    GUI::SetFont("Terminus_18");
    GUI::DrawText("LEVEL: " + type_name + " " + level_id, Vec2f(10, 10 + offset), SColor(255, 255, 255, 255));
    GUI::DrawText("COMPLEXITY: ", Vec2f(10, 30 + offset), SColor(255, 255, 255, 255));
    #ifdef STAGING
    GUI::SetFont("Terminus_12");
    GUI::DrawText("STAGING IS UNSTABLE", Vec2f(10, 60 + offset), SColor(255, 255, 255, 255));
    GUI::DrawText("PRESS G TO RESTART LEVEL", Vec2f(10, 80 + offset), SColor(255, 255, 255, 255));
    #endif
    GUI::SetFont("Terminus_18");

    string current_complexity_string = current_complexity == -1 ? "N/A" : "" + current_complexity;
    SColor col = getComplexityRedness(current_complexity);
    GUI::DrawText("" + current_complexity_string, Vec2f(128, 30 + offset), col);

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
        Vec2f start_pos = Vec2f(100, 200);

        // draw debug overlay with useful state from this script (cleaned & grouped)
        GUI::SetFont("menu");

        f32 line_h = 14.0f;
        int l = 0;
        Vec2f p = start_pos;
        int gap = int(Maths::Ceil(20.0f / line_h)); // approx 20px gap

        //
        // ROOM INFO
        //
        u8 captured = this.get_u8("captured_room_id");
        GUI::DrawText("CAPTURED ROOM ID: " + captured, p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));

        Vec2f cur_pos = this.get_Vec2f("current_room_pos");
        Vec2f cur_size = this.get_Vec2f("current_room_size");
        Vec2f cur_center = this.get_Vec2f("current_room_center");
        GUI::DrawText("CURRENT ROOM POS: (" + int(cur_pos.x) + "," + int(cur_pos.y) + ")", p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));
        GUI::DrawText("CURRENT ROOM SIZE: (" + int(cur_size.x) + "," + int(cur_size.y) + ")", p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));
        GUI::DrawText("CURRENT ROOM CENTER: (" + int(cur_center.x) + "," + int(cur_center.y) + ")", p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));

        l += gap;

        //
        // RECORDING / PATHLINE (minimal)
        //
        bool recording = this.get_bool("recording_pathline");
        Vec2f recording_startpos = this.get_Vec2f("recording_startpos");
        GUI::DrawText("RECORDING: " + recording, p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));
        GUI::DrawText("RECORD START POS: (" + int(recording_startpos.x) + "," + int(recording_startpos.y) + ")", p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));

        l += gap;

        //
        // CACHED POSITIONS & ARRAYS / COUNTS
        //
        int cached_sz = cached_positions.size();
        GUI::DrawText("CACHED POSITIONS: " + cached_sz, p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));

        u8[]@ room_ids; u8[]@ level_types; u16[]@ level_ids; u16[]@ room_owners;
        int room_count = 0;
        if (this.get("room_ids", @room_ids)) room_count = room_ids.size();
        int level_types_count = 0;
        if (this.get("level_types", @level_types)) level_types_count = level_types.size();
        int level_ids_count = 0;
        if (this.get("level_ids", @level_ids)) level_ids_count = level_ids.size();
        int room_owners_count = 0;
        if (this.get("room_owners", @room_owners)) room_owners_count = room_owners.size();

        GUI::DrawText("ROOMS: " + room_count + " | LEVEL_TYPES: " + level_types_count + " | LEVEL_IDS: " + level_ids_count, p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));

        // pathline key for current captured room (best-effort)
        string pk = "none";
        if (captured != 255)
        {
            string keyname = "pathline_key_" + captured;
            if (this.exists(keyname))
            {
                pk = this.get_string(keyname);
            }
            else
            {
                u8[]@ ltypes;
                u16[]@ lids;
                u8[]@ rids;
                if (this.get("level_types", @ltypes) && this.get("level_ids", @lids) && this.get("room_ids", @rids))
                {
                    uint ci = uint(captured);
                    if (ci < ltypes.size() && ci < lids.size() && ci < rids.size())
                    {
                        pk = "_p_" + ltypes[ci] + "_" + lids[ci] + "_" + rids[ci];
                    }
                }
            }
        }
        GUI::DrawText("PATHLINE KEY: " + pk, p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));

        l += gap;

        //
        // LOCAL ROOM COORDS & OWNERS (preview)
        //
        int local_coords_count = (local_room_coords is null) ? 0 : local_room_coords.length;
        GUI::DrawText("LOCAL ROOM COORDS: " + local_coords_count, p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));

        // show first few room ids/owners if present
        for (uint i = 0; i < 6 && i < room_count; i++)
        {
            string owner_str = "none";
            if (i < room_owners_count)
            {
                u16 oid = room_owners[i];
                if (oid != 0)
                {
                    CPlayer@ owner_p = getPlayerByNetworkId(oid);
                    owner_str = owner_p !is null ? owner_p.getUsername() : ("id:" + oid);
                }
            }
            Vec2f rc = (local_room_coords !is null && i < local_room_coords.length) ? local_room_coords[i] : Vec2f(0,0);
            GUI::DrawText("R[" + i + "] id:" + (room_ids is null ? 0 : room_ids[i]) + " owner:" + owner_str + " pos:(" + int(rc.x) + "," + int(rc.y) + ")", p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));
        }

        l += gap;

        //
        // CHECKPOINT VIEW (new)
        //
        GUI::DrawText("CHECKPOINT (packed): " + checkpoint_packed, p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));
        if (checkpoint_packed != "")
        {
            Vec2f cp = UnpackVec2f(parseInt(checkpoint_packed));
            int found = cached_positions.find(checkpoint_packed);

            string found_str = (found != -1) ? ("cached idx " + found) : "not in cache";
            GUI::DrawText("CHECKPOINT POS: (" + int(cp.x) + "," + int(cp.y) + ")  " + found_str, p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));
        }

        // current frame (for pathline)
        // timing / frames
        CBlob@[] personal_pathlines;
        if (!getBlobsByTag("personal_pathline_" + room_id, @personal_pathlines)) return;

        CBlob@ pathline_blob;
        if (personal_pathlines.size() > 0)
            @pathline_blob = personal_pathlines[0];

        if (pathline_blob !is null && pathline_blob.get_bool("active"))
        {
            string[]@ positions_str;
            string[][]@ room_pathlines;

            if (!this.get("room_pathlines", @room_pathlines)) return;
            if (room_id >= room_pathlines.length) return;

            @positions_str = room_pathlines[room_id];
            u32 start_time = pathline_blob.get_u32("start_time");
            int diff = int(getGameTime()) - int(start_time);

            int entries = int(positions_str.length);
            if (entries <= 0) return;

            CBlob@ local_blob = getLocalPlayerBlob();
            if (local_blob !is null)
            {
                bool pairs_mode = local_blob.getName() == "archer";
                int frames = pairs_mode ? entries / 2 : entries;
                if (frames <= 0) return;

                diff %= frames;
            }
            GUI::DrawText("FRAME: " + diff + " / " + entries, p + Vec2f(0, l++ * line_h), SColor(255, 255, 255, 0));
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

void onPlayerLeave(CRules@ this, CPlayer@ player)
{
    RoomPNGLoader empty;
    this.set("room_loader_" + player.getUsername(), @empty);
}

bool debug_test = false;
void onTick(CRules@ this)
{
    // client listener
    CControls@ controls = getControls();
    if (isClient() && controls !is null)
    {
        CPlayer@ local = getLocalPlayer();
        if (local is null) return;

        u16 local_id = local.getNetworkID();
        if (controls.isKeyJustPressed(KEY_RSHIFT))
        {
            debug_test = !debug_test;
            Sound::Play2D("ButtonClick.ogg", 1.0f, 1.5f);
        }

        if (controls.isKeyJustPressed(KEY_LCONTROL))
        {
            u8 room_id = this.get_u8("captured_room_id");

            u8 current_type = this.get_u8("current_level_type");
            int current_level = this.get_s32("current_level_id");
    
            if (room_id != 255 && current_level != -1)
            {
                CBlob@[] personal_pathlines;
                if (!getBlobsByTag("personal_pathline_" + room_id, @personal_pathlines)){}
                
                CBlob@ personal_pathline_blob;
                if (personal_pathlines.size() > 0)
                    @personal_pathline_blob = personal_pathlines[0];

                if (personal_pathline_blob !is null)
                {
                    CBitStream params;
                    params.write_u16(local_id);
                    params.write_u32(getGameTime());
                    params.write_u8(current_type);
                    personal_pathline_blob.SendCommand(personal_pathline_blob.getCommandID("switch"), params);
                    Sound::Play2D("ButtonClick.ogg", 1.0f, 1.0f);
                }
            }
        }
    }

    if (!this.hasTag("was_init")) CreateRoomsGrid(this);
    CMap@ map = getMap();

    if (map is null) return;
    if (!isServer()) return;

    EnsureRoomsOwned(this);
    RunRoomLoaders(this);

    u8[]@ room_ids;
    if (!this.get("room_ids", @room_ids)) return;

    // set cfg if not loaded on startup
    if (!cfg_loaded)
    {
        u8[]@ level_types;
        if (!this.get("level_types", @level_types)) return;

        u16[]@ level_ids;
        if (!this.get("level_ids", @level_ids)) return;

        string[][] room_pathlines;
        string[][]@ room_pathlines_ptr;
        if (!this.get("room_pathlines", @room_pathlines_ptr))
        {
            room_pathlines = loadRoomPathlines(this, room_ids, level_types, level_ids, room_pathlines);
            this.set("room_pathlines", @room_pathlines);
        }
    }

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

    PathlineTick(this);
}

string[][] loadRoomPathlines(CRules@ this, u8[]@ &in room_ids, u8[]@ &in level_types, u16[]@ &in level_ids, string[][]&out room_pathlines)
{
    if (room_ids.size() != level_types.size() || room_ids.size() != level_ids.size())
    {
        print("[ERR] loadRoomPathlines: room_ids or level_types or level_ids size mismatch");
        return room_pathlines;
    }

    for (u8 i = 0; i < room_ids.size(); i++)
    {
        u8 room_id = room_ids[i];
        string pathline_key = "_p_" + level_types[i] + "_" + level_ids[i] + "_" + room_id;

        string[] positions;
        pathline_cfg.readIntoArray_string(positions, pathline_key);
        room_pathlines.push_back(positions);
    }

    return room_pathlines;
}

string checkpoint_packed = 0;

// runs only on server and localhost
void PathlineTick(CRules@ this)
{
    u8[]@ room_ids;
    if (!this.get("room_ids", @room_ids)) return;

    u8[]@ level_types;
    if (!this.get("level_types", @level_types)) return;

    u16[]@ level_ids;
    if (!this.get("level_ids", @level_ids)) return;

    u16[]@ room_owners;
    if (!this.get("room_owners", @room_owners)) return;

    for (u8 i = 0; i < room_ids.size(); i++)
    {
        s32 update_level_id = this.get_s32("update_room_pathline_" + i);
        if (update_level_id != -1)
        {
            u8 room_id = room_ids[i];

            u8[]@ level_types;
            if (!this.get("level_types", @level_types)) return;

            u16[]@ level_ids;
            if (!this.get("level_ids", @level_ids)) return;

            UpdatePathlineData(this, this.get_string("pathline_key_" + i), i);
            this.set_s32("update_room_pathline_" + i, -1);
        }
    }

    string[][]@ room_pathlines;
    if (!this.get("room_pathlines", @room_pathlines))
    {
        print("[ERR] PathlineTick: could not load room_pathlines");
        return;
    }

    for (u8 i = 0; i < room_ids.size(); i++)
    {
        CBlob@[] personal_pathlines;
        if (!getBlobsByTag("personal_pathline_" + i, @personal_pathlines))
        {
            CBlob@ pathline_blob = server_CreateBlob("pathline", -1, Vec2f(0,0));
            if (pathline_blob !is null)
            {
                pathline_blob.Tag("personal_pathline_" + i);
                pathline_blob.set_string("pathline_tag", "personal_pathline_" + i);

                pathline_blob.set_u8("room_id", i);
                pathline_blob.set_bool("active", false);
                pathline_blob.set_u32("start_time", 0);
                pathline_blob.set_Vec2f("room_pos", getRoomPosFromID(i));
            }
        }
        else if (i < personal_pathlines.size())
        {
            CBlob@ pathline_blob = personal_pathlines[i];
            if (pathline_blob is null) continue;

            pathline_blob.set_u16("owner_id", room_owners[i]);
        }
    }

    // manage controls & debug, only for localhost
    if (isServer() && isClient())
    {
        CPlayer@ local = getLocalPlayer();
        if (local is null) return;
        u16 local_id = local.getNetworkID();

        CBlob@ local_blob = getLocalPlayerBlob();
        if (local_blob is null) return;

        Vec2f player_pos = local_blob.getPosition();
        Vec2f player_old_pos = local_blob.getOldPosition();

        CControls@ controls = getControls();
        if (controls is null) return;

        u8 room_id = this.get_u8("captured_room_id");
        if (room_id != 255)
        {
            // used for recording
            bool recording_pathline = this.get_bool("recording_pathline");
            Vec2f recording_startpos = this.get_Vec2f("recording_startpos");

            CBlob@ personal_pathline_blob;
            CBlob@[] personal_pathlines;
            if (getBlobsByTag("personal_pathline_" + room_id, @personal_pathlines))
            {
                @personal_pathline_blob = personal_pathlines[0];
            }

            // toggle record on/off
            if (controls.isKeyJustPressed(KEY_MBUTTON)) // for localhost only
            {
                Sound::Play2D("ButtonClick.ogg", 1.0f, 1.5f);

                recording_pathline = !recording_pathline;
                recording_startpos = player_pos;
                checkpoint_packed = "";
            }
            
            if (recording_pathline)
            {
                bool is_archer = (local_blob.getName() == "archer");

                // make a checkpoint to go back to
                if (controls.isKeyJustPressed(KEY_F2))
                {
                    string unpacked_current = cached_positions[cached_positions.size() - 1];
                    checkpoint_packed = unpacked_current;

                    local_blob.setPosition(player_old_pos);
                }
                // go back to checkpoint
                else if (controls.isKeyJustPressed(KEY_F3))
                {
                    int id = cached_positions.find(checkpoint_packed);

                    if (id != -1)
                    {
                        Vec2f cp = UnpackVec2f(parseInt(checkpoint_packed)) + recording_startpos;
                        local_blob.setPosition(cp);
                        local_blob.setPosition(cp);
                        local_blob.setVelocity(Vec2f(0,0));
                        local_blob.set_Vec2f("grapple_pos", cp);

                        cached_positions.resize(id + (is_archer ? 2 : 1));
                    }
                }
            }

            if (recording_pathline) // for localhost only
            {
                string[][]@ room_pathlines;
                if (!this.get("room_pathlines", @room_pathlines)) recording_pathline = false;

                if (room_id >= room_pathlines.length) recording_pathline = false;
                RecordPathline(this, local_blob, recording_startpos, player_pos, player_old_pos);

                if (!recording_pathline)
                {
                    SetClientMessage(local_id, "[ERR] Can not record pathline!");
                }

                if (personal_pathline_blob !is null) personal_pathline_blob.set_bool("active", !recording_pathline);
            }

            // save when recording stops
            bool stopped_recording = !recording_pathline && this.get_bool("recording_pathline");
            if (stopped_recording)
            {
                string pathline_key = "_p_" + level_types[room_id] + "_" + level_ids[room_id] + "_" + room_id; // test 0
                SavePathline(this, pathline_key, room_id, stopped_recording);
            }

            this.set_bool("recording_pathline", recording_pathline);
            this.set_Vec2f("recording_startpos", recording_startpos);
        }
    }

    CBlob@[] personal_pathlines;
    CBlob@[] pathlines_unsorted;
    if (getBlobsByName("pathline", @pathlines_unsorted))
    {
        for (uint i = 0; i < pathlines_unsorted.length; i++)
        {
            CBlob@ pathline_blob = pathlines_unsorted[i];
            if (pathline_blob is null) continue;

            if (!pathline_blob.exists("active") || !pathline_blob.get_bool("active")) continue;
            u8 room_id = pathline_blob.get_u8("room_id");

            #ifdef STAGING
            if (personal_pathlines.length <= room_id)
            {
                personal_pathlines.resize(room_id + 1);
            }
            #endif
            personal_pathlines.insertAt(room_id, pathline_blob);
        }
    }
    
    for (uint i = 0; i < personal_pathlines.length; i++)
    {
        CBlob@ pathline_blob = personal_pathlines[i];
        if (pathline_blob is null) continue;

        u8 room_id = pathline_blob.get_u8("room_id");
        if (room_id >= room_pathlines.length) continue;

        string[]@ positions_str = room_pathlines[room_id];
        if (positions_str is null || positions_str.length == 0) continue;

        // determine pairs mode from level_types (archer uses pairs)
        bool pairs_mode = false;
        if (room_id < level_types.length)
        {
            u8 lt = level_types[room_id];
            pairs_mode = (lt == RoomType::archer);
        }

        // timing / frames
        u32 start_time = pathline_blob.get_u32("start_time");
        int diff = int(getGameTime()) - int(start_time);

        int entries = int(positions_str.length);
        if (entries <= 0) continue;

        int frames = pairs_mode ? entries / 2 : entries;
        if (frames <= 0) continue;
        
        diff %= frames;
        bool ok = (diff >= 0 && diff < frames);

        if (!ok) continue;
        int step = pairs_mode ? 2 : 1;
        int mainIndex = diff * step;
        int prevIndex = (diff > 0) ? (mainIndex - step) : -1;
        bool reset = mainIndex == 0;

        string old_s = "";
        int old_parsed = -1;
        bool has_old = false;
        if (prevIndex >= 0 && prevIndex < entries)
        {
            old_s = positions_str[prevIndex];
            old_parsed = parseInt(old_s);
            has_old = (old_parsed != -1);
        }

        if (mainIndex < 0 || mainIndex >= entries) continue;
        string s = positions_str[mainIndex];
        int parsed = parseInt(s);
        if (parsed == -1) continue;

        int grapple_parsed = -1;
        if (pairs_mode)
        {
            int grappleIndex = mainIndex + 1;
            if (grappleIndex < entries)
            {
                string gs = positions_str[grappleIndex];
                grapple_parsed = parseInt(gs); // may be -1 if invalid
            }
        }

        // run pathline update for this blob
        RunPathline(this, pathline_blob, parsed, has_old, old_parsed, grapple_parsed, reset);
    }
}

void RunPathline(CRules@ this, CBlob@ pathline_blob, int parsed, bool has_old,
                int old_parsed, int grapple_parsed, bool reset)
{
    if (pathline_blob is null) return;

    u32 packed = u32(parsed);
    Vec2f pos = UnpackVec2f(packed);
    Vec2f anchor_pos = pathline_blob.get_Vec2f("anchor_pos"); // this is set from anchor on creation

    Vec2f oldpos = has_old ? UnpackVec2f(u32(old_parsed)) : Vec2f(0,0);
    Vec2f endpos = pos + anchor_pos;
    Vec2f gpos = grapple_parsed != -1 ? UnpackVec2f(u32(grapple_parsed)) + anchor_pos : endpos;
    
    Vec2f last_gpos = pathline_blob.get_Vec2f("grapple_pos");
    if (last_gpos != gpos)
    {
        pathline_blob.set_Vec2f("last_grapple_pos", last_gpos);

        if (gpos != endpos) pathline_blob.set_Vec2f("grapple_pos", gpos);
        else pathline_blob.set_Vec2f("grapple_pos", Vec2f(0,0));

        pathline_blob.Tag("sync");
    }

    if (reset)
    {
        CBitStream params;
        params.write_string(pathline_blob.get_string("pathline_tag"));
        params.write_Vec2f(pathline_blob.get_Vec2f("grapple_pos"));
        params.write_u32(getGameTime());
        pathline_blob.SendCommand(pathline_blob.getCommandID("sync"), params);
        pathline_blob.set_u32("time", getGameTime());
    }

    // update vars
    pathline_blob.setPosition(endpos);
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

void SavePathline(CRules@ this, string pathline_key, u8 room_id, bool stopped_recording)
{
    if (stopped_recording && cached_positions.size() > 0)
    {
        if (pathline_cfg.exists(pathline_key)) pathline_cfg.remove(pathline_key);
        pathline_cfg.addArray_string(pathline_key, cached_positions);
        pathline_cfg.saveFile("parkour_pathlines.cfg");

        print("[INF] Saved pathline data for key " + pathline_key + ", size: " + cached_positions.size() + ", for room id " + room_id);
        cached_positions.clear();

        // update cfg_loaded and pathline_key
        UpdatePathlineData(this, pathline_key, room_id);
    }
}

void UpdatePathlineData(CRules@ this, string pathline_key, u8 room_id)
{
    string[][]@ room_pathlines;
    if (!this.get("room_pathlines", @room_pathlines))
    {
        error("[ERR] UpdatePathlineData: could not load room_pathlines");
        return;
    }

    if (pathline_cfg is null)
    {
        warn("[WRN] Client: pathline_cfg was nullon update");
    }

    ConfigFile@ empty = @ConfigFile();
    @pathline_cfg = @empty;

    print("[INF] Client: reloading pathline config for key " + pathline_key + " and room id " + room_id + ", pathline size " + room_pathlines.size());
    // read from cache again to update to the latest data
    cfg_loaded = pathline_cfg.loadFile("../Cache/parkour_pathlines.cfg");
    if (room_id < room_pathlines.size())
    {
        string[] temp;
        pathline_cfg.readIntoArray_string(temp, pathline_key);

        room_pathlines[room_id] = temp;
        print("[INF] Client: updated pathline data for key " + pathline_key + ", new size: " + room_pathlines[room_id].size());
    }
}
