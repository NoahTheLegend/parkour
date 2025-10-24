
// sends a command to the server to set the room for the player
void sendRoomCommand(CRules@ rules, u8 type, int level_id, Vec2f pos)
{
    CBitStream params;
    params.write_u16(getLocalPlayer().getNetworkID()); // player id
    params.write_u8(type);
    params.write_s32(level_id); // level id
    params.write_Vec2f(ROOM_SIZE); // room size
    params.write_Vec2f(pos); // start pos // todo: get from level data

    rules.SendCommand(rules.getCommandID("set_room"), params);
    print("[CMD] Sent " + rules.getCommandID("set_room"));
}

// returns the file path for a given room based on its type and ID
string GetRoomFile(u8 level_type, uint level_id)
{
    return "Rooms/" + getTypeName(level_type) + "_" + level_id + ".png";
}

string getTypeName(u8 level_type)
{
    switch (level_type)
    {
        case RoomType::knight: return "k";
        case RoomType::archer: return "a";
        case RoomType::builder: return "b";
        default: return "unknown";
    }

    return "unknown";
}

string getFullTypeName(u8 level_type)
{
    switch (level_type)
    {
        case RoomType::knight: return "Knight";
        case RoomType::archer: return "Archer";
        case RoomType::builder: return "Builder";
        case RoomType::chess: return "Chess";
        default: return "Unknown";
    }

    return "Unknown";
}

u8 getTypeFromName(string type_name)
{
    if (type_name == "k") return RoomType::knight;
    if (type_name == "a") return RoomType::archer;
    if (type_name == "b") return RoomType::builder;
    return 255;
}

Vec2f getRoomPosFromID(int room_id)
{
    CRules@ rules = getRules();
    if (rules is null) return Vec2f_zero;

    CMap@ map = getMap();
    if (map is null) return Vec2f_zero;

    print("[INF] Calculating position for room ID " + room_id);

    int map_width = map.tilemapwidth * 8;
    int map_height = map.tilemapheight * 8;

    u8 rooms_count = (map_width / ROOM_SIZE.x) * (map_height / ROOM_SIZE.y);
    u8 middle_hub_id = Maths::Floor(rooms_count / 2.0f);

    if (room_id >= middle_hub_id)
    {
        room_id += 1; // skip middle hub
    }

    int rooms_per_row = 0;
    if (ROOM_SIZE.x > 0.0f && map_width > 0)
    {
        rooms_per_row = int(map_width / ROOM_SIZE.x);
    }

    if (rooms_per_row <= 0)
    {
        // fallback to avoid division/modulo by zero
        rooms_per_row = 1;
        warn("[WRN] Rooms_per_row was zero, falling back to 1");
    }

    f32 x = (room_id % rooms_per_row) * ROOM_SIZE.x;
    f32 y = (room_id / rooms_per_row) * ROOM_SIZE.y;

    return Vec2f(x, y);
}