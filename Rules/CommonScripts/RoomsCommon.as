Vec2f MAP_GRID = Vec2f(3, 3);
Vec2f ROOM_SIZE = Vec2f(150, 150) * 8; // pathline offset issue, todo

const u32 base_room_set_delay = 15;
const u8 tiles_per_tick_base = 5;
const u32 room_creation_delay_base = 0;
const u32 base_exit_delay = 5;

TileType filler_tile = CMap::tile_ground_back;
const f32 max_message_width = 400.0f;

const f32 MAX_POS = 20000.0f; // maximum absolute coordinate value for encoding to cache
string[] cached_positions; // packed player pathing data as strings, used for recording pathlines
Vec2f[]@ local_room_coords;

namespace RoomType {
    enum RoomType {
        knight = 0,
        archer,
        builder,
        chess
    };
};

const u16[] collapseable_tiles = {
    CMap::tile_castle,
    CMap::tile_castle_back,
    CMap::tile_wood,
    CMap::tile_wood_back,
    CMap::tile_castle_moss,
    CMap::tile_castle_back_moss
};

const u16[] support_tiles = {
    CMap::tile_ground,
    CMap::tile_ground_back,
    CMap::tile_bedrock,
    CMap::tile_stone,
    CMap::tile_thickstone,
    CMap::tile_gold
};

const u8[] difficulty_knight = {
    0,  0,  1,  1,  1,
    1,  2,  2,  2,  1,
    2,  4,  3,  3,  4,
    4,  5,  5,  6,  6,
    6,  1,  2,  3,  4,
    5,  5,  6,  6,  2,
    8,  1,  2,  2,  3,
    5,  7,  7,  8,  6,
    7,  5,  6,  8,  6,
    6,  8,  3,  3,  3,
    5,  5,  6,  5,  7,
    6,  7,  8,  6,  7,
    8,  7,  6,  8,  9,
    8,  10, 12
};

const u8[] difficulty_archer = {
    2,  3,  5,  4,  4,
    0,  1,  2,  3,  4,
    3,  3,  2,  2,  2,
    3,  3,  4,  5,  5,
    4,  5,  5,  7,  6,
    5,  6,  7,  7,  3,
    0,  1,  3,  4,  3,
    6,  5,  2,  4,  6,
    7,  5,  6,  7,  6,
    5,  6,  7,  8,  8,
    8,  7,  7,  3,  4,
    5,  5,  6,  14, 0,
    2,  3,  4,  5,  2,
    3,  1,  2,  3,  4,
    5,  7,  5,  4,  6,
    8,  10, 10, 12, 11,
    8,  12, 13, 0
};

const u8[] difficulty_builder = {
    0
};