#include "Helpers.as";
#include "RoomsCommon.as";
#include "RoomsHooks.as";

void CreateRoomsGridCommand(CRules@ this, CBitStream@ params)
{
    bool request_sync = false;
    if (!params.saferead_bool(request_sync)) {print("[CMD] Failed to read request sync"); return;}

    if (request_sync && isServer())
    {
        SyncRoomsGrid(this);
        return;
    }

    uint rooms_count;
    if (!params.saferead_u16(rooms_count)) {print("[CMD] Failed to read rooms count [0]"); return;}

    Vec2f[] room_coords;
    for (uint i = 0; i < rooms_count; i++)
    {
        Vec2f room_pos;
        if (!params.saferead_Vec2f(room_pos)) {print("[CMD] Failed to read room pos"); return;}
        room_coords.push_back(room_pos);
    }

    CreateRoomsGrid(this, room_coords);
    print("[CMD] Received rooms grid with " + room_coords.length + " rooms");
}

void SetRoomCommand(CRules@ this, CBitStream@ params)
{
    u16 pid;
    if (!params.saferead_u16(pid)) {print("[CMD] Failed to read player id"); return;}

    if (pid != 0) // we sent this from server
    {
        CPlayer@ p = getPlayerByNetworkId(pid);
        if (p is null) return;

        string user_call = "last_room_set_time_" + p.getUsername();
        if (this.exists(user_call) && getGameTime() - this.get_u32(user_call) < base_room_set_delay)
        {
            print("[VAL] Ignoring rapid room set request from " + p.getUsername());
            return;
        }
        this.set_u32(user_call, getGameTime());
    }

    u8 level_type;
    if (!params.saferead_u8(level_type)) {print("[CMD] Failed to read room type"); return;}

    int level_id;
    if (!params.saferead_s32(level_id)) {print("[CMD] Failed to read level id"); return;}

    Vec2f room_size;
    if (!params.saferead_Vec2f(room_size)) {print("[CMD] Failed to read room size"); return;}

    Vec2f start_pos;
    if (!params.saferead_Vec2f(start_pos)) {print("[CMD] Failed to read start pos"); return;}

    print("[INF] Loaded level " + level_id + " of type " + level_type + " with size " + room_size + " at pos " + start_pos);

    // set client vars
    if (pid != 0)
    {
        CPlayer@ p = getPlayerByNetworkId(pid);
        if (p !is null && p.isMyPlayer())
        {
            this.set_u8("current_level_type", level_type);
            this.set_s32("current_level_id", level_id);

            this.set_Vec2f("current_room_pos", start_pos);
            this.set_Vec2f("current_room_size", room_size);
            this.set_Vec2f("current_room_center", start_pos + room_size * 0.5f);

            print("[INF] Client: set current room to " + level_id + " of type " + level_type + " at pos " + start_pos);
        }
    }

    string file = level_type == RoomType::chess ? "ChessLevel.png" : GetRoomFile(level_type, level_id);
    CFileImage fm(file);
    if (!fm.isLoaded())
    {
        error("[ERR] Room file " + file + " not found, loading empty room");
        file = "Maps/Hub.png";
    }

    EraseRoom(this, start_pos, room_size); // tag for room creation
    CreateRoomFromFile(this, file, start_pos, pid);
    onRoomCreated(this, level_type, level_id, pid);
}

void CreateRoomCommand(CRules@ this, CBitStream@ params)
{
    if (!isServer()) return;

    u16 pid;
    if (!params.saferead_u16(pid)) {print("[CMD] Failed to read player id"); return;}

    CPlayer@ p = getPlayerByNetworkId(pid);
    if (p is null) return;
    
    u8[]@ room_ids;
    if (!this.get("room_ids", @room_ids)) {print("[CMD] Failed to get room ids"); return;}

    u16[]@ room_owners;
    if (!this.get("room_owners", @room_owners)) {print("[CMD] Failed to get room owners"); return;}

    if (room_ids is null || room_owners is null)
    {
        print("[CMD] Room ids or owners not found");
        return;
    }

    if (room_ids.length != room_owners.length)
    {
        print("[CMD] Room ids and owners length mismatch");
        return;
    }

    // check if we own one already and set that one instead
    u8 free_room_id = 255;
    for (uint i = 0; i < room_ids.size(); i++)
    {
        if (room_owners[i] == pid) // already owned
        {
            print("[INF] Player " + p.getUsername() + " already owns room id " + room_ids[i]);
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
                free_room_id = room_ids[i];
                room_owners[i] = pid; // claim ownership
                break;
            }
        }
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

void SyncRoomOwnerCommand(CRules@ this, CBitStream@ params)
{
    if (!isClient()) return;

    u16 pid;
    if (!params.saferead_u16(pid)) {print("[CMD] Failed to read player id"); return;}

    u8 free_room_id;
    if (!params.saferead_u8(free_room_id)) {print("[CMD] Failed to read free room id"); return;}

    u8 rooms_count;
    if (!params.saferead_u8(rooms_count)) {print("[CMD] Failed to read rooms count [1]"); return;}

    u8[] room_ids;
    u16[] room_owners;

    for (uint i = 0; i < rooms_count; i++)
    {
        u8 room_id;
        if (!params.saferead_u8(room_id)) {print("[CMD] Failed to read room id"); return;}
        room_ids.push_back(room_id);

        u16 owner_id;
        if (!params.saferead_u16(owner_id)) {print("[CMD] Failed to read room owner id"); return;}
        room_owners.push_back(owner_id);
    }

    print("[INF] Synced room owners with " + rooms_count + " rooms count, " + room_ids.length + " room ids and " + room_owners.length + " owners");
    
    this.set("room_ids", @room_ids);
    this.set("room_owners", @room_owners);
    
    CPlayer@ p = getPlayerByNetworkId(pid);
    if (p !is null)
    {
        warn("[INF] Player " + p.getUsername() + " assigned room id " + free_room_id);
        this.set_u8("captured_room_id", free_room_id);
    }
}

void ClientMessageCommand(CRules@ this, CBitStream@ params)
{
    if (!isClient()) return;

    u16 pid;
    if (!params.saferead_u16(pid)) {print("[CMD] Failed to read player id"); return;}

    string msg;
    if (!params.saferead_string(msg)) {print("[CMD] Failed to read client message"); return;}

    f32 max_width = max_message_width;
    string font = "Terminus_14";
    GUI::SetFont(font);

    // wrap text
    string wrapped = wrapText(msg, max_width, font);

    // calculate pane size based on wrapped text
    Vec2f text_dim;
    GUI::GetTextDimensions(wrapped, text_dim);
    Vec2f pane_size = Vec2f(max_width, text_dim.y);

    this.set_u32("_client_message_time", getGameTime());
    this.set_string("_client_message", wrapped);
    this.set_Vec2f("_client_message_size", pane_size);
}
