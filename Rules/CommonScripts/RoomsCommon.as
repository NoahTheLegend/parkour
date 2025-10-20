Vec2f MAP_GRID = Vec2f(3, 2);
Vec2f ROOM_SIZE = Vec2f(150, 150) * 8;

const u32 base_room_set_delay = 15;
const u8 tiles_per_tick_base = 15;
const u32 room_creation_delay_base = 0;
const u32 base_exit_delay = 5;

TileType filler_tile = CMap::tile_ground_back;

namespace RoomType {
    enum RoomType {
        knight = 0,
        archer,
        builder,
        chess
    };
};
