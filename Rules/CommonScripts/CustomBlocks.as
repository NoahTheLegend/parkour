
/**
 *	Template for modders - add custom blocks by
 *		putting this file in your mod with custom
 *		logic for creating tiles in HandleCustomTile.
 *
 * 		Don't forget to check your colours don't overlap!
 *
 *		Note: don't modify this file directly, do it in a mod!
 */

namespace CMap
{
	enum CustomTiles
	{
		tile_ground_fake = 512,
		tile_ground_fake_v0 = tile_ground_fake + 1,
		tile_ground_fake_v1 = tile_ground_fake + 2,
		tile_ground_fake_v2 = tile_ground_fake + 3,
		tile_ground_fake_v3 = tile_ground_fake + 4,
		tile_ground_fake_v4 = tile_ground_fake + 5,
		tile_ground_fake_v5 = tile_ground_fake + 6,
		tile_ground_fake_g0 = tile_ground_fake + 7,
		tile_ground_fake_g1 = tile_ground_fake + 8,
		
		tile_gold_fake = tile_ground_fake + 16,
		tile_gold_fake_v0 = tile_gold_fake + 1,
		tile_gold_fake_v1 = tile_gold_fake + 2,
		tile_gold_fake_v2 = tile_gold_fake + 3,
		tile_gold_fake_v3 = tile_gold_fake + 4,

		tile_stone_fake = tile_gold_fake + 16,
		tile_stone_fake_v0 = tile_stone_fake + 1,

		tile_thickstone_fake = tile_stone_fake + 16,
		tile_thickstone_fake_v0 = tile_thickstone_fake + 1,

		tile_bedrock_fake = tile_thickstone_fake + 16,
		tile_bedrock_fake_v0 = tile_bedrock_fake + 1,
		tile_bedrock_fake_v1 = tile_bedrock_fake + 2,
		tile_bedrock_fake_v2 = tile_bedrock_fake + 3,
		tile_bedrock_fake_v3 = tile_bedrock_fake + 4,
		tile_bedrock_fake_v4 = tile_bedrock_fake + 5,

        TOTAL
	};
};

bool isTileFirstOfType(u16 tile)
{
    return tile % 16 == 0;
}

bool isTileFake(u16 tile)
{
	return tile >= CMap::tile_ground_fake && tile < 512 + 80;
}

void HandleCustomTile(CMap@ map, int offset, SColor pixel)
{
	//change this in your mod
}

bool isSameFake(u16 tile, u16 tile2)
{
    if (tile >= CMap::tile_ground_fake && tile < CMap::tile_ground_fake + 16)
    {
        return tile2 >= CMap::tile_ground_fake && tile2 < CMap::tile_ground_fake + 16;
    }
    else if (tile >= CMap::tile_bedrock_fake && tile < CMap::tile_bedrock_fake + 16)
    {
        return tile2 >= CMap::tile_bedrock_fake && tile2 < CMap::tile_bedrock_fake + 16;
    }
    else if (tile >= CMap::tile_gold_fake && tile < CMap::tile_gold_fake + 16)
    {
        return tile2 >= CMap::tile_gold_fake && tile2 < CMap::tile_gold_fake + 16;
    }
    else if (tile >= CMap::tile_stone_fake && tile < CMap::tile_stone_fake + 16)
    {
        return tile2 >= CMap::tile_stone_fake && tile2 < CMap::tile_stone_fake + 16;
    }
    else if (tile >= CMap::tile_thickstone_fake && tile < CMap::tile_thickstone_fake + 16)
    {
        return tile2 >= CMap::tile_thickstone_fake && tile2 < CMap::tile_thickstone_fake + 16;
    }

    return false;
}

void MakeTileVariation_Custom(CMap@ map, int x, int y, TileType tile_new, TileType tback)
{
    int tilemapwidth = map.tilemapwidth;
    int tilemapheight = map.tilemapheight;

    if (x < 0 || y < 0 || x > tilemapwidth-1 || y > tilemapheight-1) {
        return;
    }

    TileType t = tile_new;
    Vec2f pos = Vec2f(x * 8, y * 8);
    int index = map.getTileOffset(pos);

    bool on_left = (x == 0);
    bool on_top = (y == 0);
    bool on_right = (x == tilemapwidth-1);
    bool on_bottom = (y == tilemapheight-1);

    // Only apply variation for custom fake tiles
    if (t >= CMap::tile_ground_fake && t < CMap::TOTAL)
    {
        bool is_ground = (t >= CMap::tile_ground_fake && t < CMap::tile_ground_fake + 16);
        bool is_bedrock = (t >= CMap::tile_bedrock_fake && t < CMap::tile_bedrock_fake + 16);

        if (is_ground || is_bedrock)
        {
            u16 base = is_ground ? CMap::tile_ground_fake : CMap::tile_bedrock_fake;

            // Check for grass on top (only for ground)
            if (is_ground && !on_top && map.isTileGrass(map.getTile(pos + Vec2f(0, -8)).type))
            {
                t = base + 7 + ((x + y) % 2);
            }
            else
            {
                // around bitmask
                TileType tile_top = map.getTile(pos + Vec2f(0, -8)).type;
                TileType tile_bottom = map.getTile(pos + Vec2f(0, 8)).type;
                TileType tile_left = map.getTile(pos + Vec2f(-8, 0)).type;
                TileType tile_right = map.getTile(pos + Vec2f(8, 0)).type;
                TileType tile_top2 = map.getTile(pos + Vec2f(0, -16)).type;
                TileType tile_topleft = map.getTile(pos + Vec2f(-8, -8)).type;
                TileType tile_topright = map.getTile(pos + Vec2f(8, -8)).type;

                int around = 0;
                around |= ((on_top || tile_top == 0) ? 1 : 0);
                around |= ((on_bottom || tile_bottom == 0) ? 2 : 0);
                around |= ((on_left || tile_left == 0) ? 4 : 0);
                around |= ((on_right || tile_right == 0) ? 8 : 0);
                around |= ((y <= 1 || tile_top2 == 0) ? 16 : 0);
                around |= ((on_left || on_top || tile_topleft == 0) ? 32 : 0);
                around |= ((on_right || on_top || tile_topright == 0) ? 64 : 0);

                if ((around & 1) != 0)
                {
                    // nothing, we win
                }
                else if ((around & 2) != 0)
                {
                    t = base + 4;
                }
                else if ((around & 4) != 0 && (around & 8) != 0)
                {
                    t = base + (3 + (y % 2));
                }
                else if ((around & 4) != 0)
                {
                    t = base + 3;
                }
                else if ((around & 8) != 0)
                {
                    t = base + 2;
                }
                else if ((around & 16) != 0 || (around & 32) != 0 || (around & 64) != 0)
                {
                    t = base + 1;
                }
                else
                {
                    t = base + 5 + ((x + y) % 2);
                }
            }

            map.server_SetTile(pos, t);
            return;
        }

        // gold, stone, thickstone
        if (t == CMap::tile_gold_fake)
            t = CMap::tile_gold_fake + (x + y) % 5;
        else if (t == CMap::tile_stone_fake)
            t = CMap::tile_stone_fake + (x + y) % 2;
        else if (t == CMap::tile_thickstone_fake)
            t = CMap::tile_thickstone_fake + (x + y) % 2;
    }

    map.server_SetTile(pos, t);
}

int fastrandom(int seed, int range)
{
    u32 n = u32(seed);
    n = (n << 13) ^ n;
    u32 nn = (n * (n * n * 15731 + 789221) + 1376312589);
    return int((nn & 0x7fffffff) % u32(range));
}