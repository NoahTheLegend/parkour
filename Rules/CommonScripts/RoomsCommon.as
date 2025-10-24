Vec2f MAP_GRID = Vec2f(2, 2);
Vec2f ROOM_SIZE = Vec2f(200, 200) * 8; // pathline offset issue, todo

const u32 base_room_set_delay = 15;
const u8 tiles_per_tick_base = 15;
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