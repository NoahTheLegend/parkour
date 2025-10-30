#include "Helpers.as";
#include "RoomsCommon.as";
#include "RoomsHooks.as";
#include "RoomsHandlers.as";

// sends a command to the server to set the room for the player
void sendRoomCommand(CRules@ rules, u16 pid, u8 type, int level_id, Vec2f pos)
{
    CBitStream params;
    params.write_u16(pid); // player id
    params.write_u8(type);
    params.write_s32(level_id); // level id
    params.write_Vec2f(ROOM_SIZE); // room size
    params.write_Vec2f(pos); // start pos // todo: get from level data

    if (isClient())
    {
        CPlayer@ p = getPlayerByNetworkId(pid);
        if (p is null || !p.isMyPlayer()) return;

        rules.SendCommand(rules.getCommandID("set_room"), params);
        print("[CMD] Sent " + rules.getCommandID("set_room"));
    }
    else
    {
        print("[CMD] Executed SetRoomCommand directly on server");
        BuildRoom(rules, pid, type, level_id, ROOM_SIZE, pos);
    }
}

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
    print("[CMD] SetRoomCommand called");
    if (!isServer()) return;

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

        u16[]@ room_owners;
        if (!this.get("room_owners", @room_owners)) {print("[CMD] Failed to get room owners"); return;}
        
        if (room_owners is null)
        {
            print("[CMD] Room owners not found");
            return;
        }
    
        if (room_owners.find(pid) == -1)
        {
            print("[VAL] Player " + pid + " tried to set a room they don't own");
            SetClientMessage(pid, "You need to create a room before loading levels");
            return;
        }
    }

    u8 level_type;
    if (!params.saferead_u8(level_type)) {print("[CMD] Failed to read room type"); return;}

    int level_id;
    if (!params.saferead_s32(level_id)) {print("[CMD] Failed to read level id"); return;}

    Vec2f room_size;
    if (!params.saferead_Vec2f(room_size)) {print("[CMD] Failed to read room size"); return;}

    Vec2f start_pos;
    if (!params.saferead_Vec2f(start_pos)) {print("[CMD] Failed to read start pos"); return;}

    // delegate main loading logic
    BuildRoom(this, pid, level_type, level_id, room_size, start_pos);
}

void SyncRoomCommand(CRules@ this, CBitStream@ params)
{
    if (!isClient()) return;

    u16 pid;
    if (!params.saferead_u16(pid)) {print("[CMD] Failed to read player id"); return;}

    u8 level_type;
    if (!params.saferead_u8(level_type)) {print("[CMD] Failed to read room type"); return;}

    int level_id;
    if (!params.saferead_s32(level_id)) {print("[CMD] Failed to read level id"); return;}

    Vec2f room_size;
    if (!params.saferead_Vec2f(room_size)) {print("[CMD] Failed to read room size"); return;}

    Vec2f start_pos;
    if (!params.saferead_Vec2f(start_pos)) {print("[CMD] Failed to read start pos"); return;}

    Vec2f center_pos;
    if (!params.saferead_Vec2f(center_pos)) {print("[CMD] Failed to read center pos"); return;}

    s32 complexity;
    if (!params.saferead_s32(complexity)) {print("[CMD] Failed to read complexity"); return;}
    
    string level_type_name;
    if (!params.saferead_string(level_type_name)) {print("[CMD] Failed to read level type name"); return;}

    this.set_u8("current_level_type", level_type);
    this.set_s32("current_level_id", level_id);
    this.set_s32("current_level_complexity", getComplexity(level_type, level_id));    

    this.set_Vec2f("current_room_pos", start_pos);
    this.set_Vec2f("current_room_size", room_size);
    this.set_Vec2f("current_room_center", center_pos);

    this.set_s32("current_complexity", complexity);
    this.set_string("current_level_type_name", level_type_name);

    print("[INF] Synced current room to " + level_id + " of type " + level_type + " at pos " + start_pos);
}

void RoomChatCommand(CRules@ this, CBitStream@ params)
{
    u16 pid;
    if (!params.saferead_u16(pid)) {print("[CMD] Failed to read player id"); return;}

    CPlayer@ player = getPlayerByNetworkId(pid);
    if (player is null) return;

    u8 count;
    if (!params.saferead_u8(count)) {print("[CMD] Failed to read chat tokens count"); return;}

    string[] tokens;
    for (u8 i = 0; i < count; i++)
    {
        string token;
        if (!params.saferead_string(token)) {print("[CMD] Failed to read chat token"); continue;}
        tokens.push_back(token);
    }

    u8 level_type = this.exists("current_level_type") ? this.get_u8("current_level_type") : 255;
    int level_id = this.exists("current_level_id") ? this.get_s32("current_level_id") : -1;
	Vec2f level_pos = this.exists("current_room_pos") ? this.get_Vec2f("current_room_pos") : Vec2f_zero;

	if (level_type != 255 && level_id != -1)
	{
		if (tokens[0] == "!n" || tokens[0] == "!next" || tokens[0] == "!skip")
		{
			sendRoomCommand(this, player.getNetworkID(), level_type, level_id + 1, level_pos);
		}
		else if (tokens[0] == "!p" || tokens[0] == "!prev" || tokens[0] == "!previous")
		{
			if (level_id > 0) sendRoomCommand(this, player.getNetworkID(), level_type, level_id - 1, level_pos);
		}
		else if (tokens[0] == "!r" || tokens[0] == "!rs" || tokens[0] == "!restart")
		{
			sendRoomCommand(this, player.getNetworkID(), level_type, level_id, level_pos);
		}
    }

    if (tokens.size() >= 2)
    {
        int type = 0;
		int requestedLevelId = parseInt(tokens[1]);
		if (requestedLevelId >= 0)
		{
			if (tokens.size() == 3)
			{
				string class_token = tokens[2];
				if (class_token == "k" || class_token == "kn" || class_token == "knight")
				{
					type = RoomType::knight;
				}
				else if (class_token == "a" || class_token == "ar" || class_token == "archer")
				{
					type = RoomType::archer;
				}
				else type = parseInt(class_token);
			}

			sendRoomCommand(this, player.getNetworkID(), type, requestedLevelId, level_pos);
		}
    }
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

    u8[]@ level_types;
    if (!this.get("level_types", @level_types)) {print("[CMD] Failed to get level types"); return;}

    u16[]@ level_ids;
    if (!this.get("level_ids", @level_ids)) {print("[CMD] Failed to get level ids"); return;}

    u16[]@ room_owners;
    if (!this.get("room_owners", @room_owners)) {print("[CMD] Failed to get room owners"); return;}

    if (room_ids is null || level_types is null || level_ids is null || room_owners is null)
    {
        print("[CMD] Room ids or owners not found");
        return;
    }

    if (room_ids.length != room_owners.length || room_ids.length != level_types.length || room_ids.length != level_ids.length)
    {
        print("[CMD] Length mismatch in CommandHandlers.as");
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
        params1.write_u8(level_types[i]);
        params1.write_u16(level_ids[i]);
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
    u8[] level_types;
    u16[] level_ids;
    u16[] room_owners;

    for (uint i = 0; i < rooms_count; i++)
    {
        u8 room_id;
        if (!params.saferead_u8(room_id)) {print("[CMD] Failed to read room id"); return;}
        room_ids.push_back(room_id);
        
        u8 level_type;
        if (!params.saferead_u8(level_type)) {print("[CMD] Failed to read level type"); return;}
        level_types.push_back(level_type);

        u16 level_id;
        if (!params.saferead_u16(level_id)) {print("[CMD] Failed to read level id"); return;}
        level_ids.push_back(level_id);

        u16 owner_id;
        if (!params.saferead_u16(owner_id)) {print("[CMD] Failed to read room owner id"); return;}
        room_owners.push_back(owner_id);
    }

    print("[INF] Synced room owners with " + rooms_count + " rooms count, " + room_ids.length + " room ids and " + room_owners.length + " owners");
    
    this.set("room_ids", @room_ids);
    this.set("level_types", @level_types);
    this.set("level_ids", @level_ids);
    this.set("room_owners", @room_owners);
    
    CPlayer@ p = getPlayerByNetworkId(pid);
    if (p !is null && p.isMyPlayer())
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

void SyncPathlineToServerCommand(CRules@ this, CBitStream@ params)
{
    if (!isServer()) return;
}