
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
		tile_gold_fake_v4 = tile_gold_fake + 5,

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

void MakeTileVariation_Custom(CMap@ map, int x, int y, TileType tile, TileType &out t, TileType &out tback, bool &out mirror, bool &out flip, bool &out rotate, bool &out backmirror, bool &out backflip, bool &out backrotate, bool &out front)
{
    int tilemapwidth = map.tilemapwidth;
    int tilemapheight = map.tilemapheight;

    if (x < 0 || y < 0 || x > tilemapwidth-1 || y > tilemapheight-1) {
        return;
    }

    t = tile;

    TileType dummy = 0;
    bool dummybool = false;
    mirror = flip = rotate = backmirror = backflip = backrotate = false;
    front = true;
    tback = 0;

    Vec2f pos = Vec2f(x * 8, y * 8);

    bool on_left = (x == 0);
    bool on_top = (y == 0);
    bool on_right = (x == tilemapwidth-1);
    bool on_bottom = (y == tilemapheight-1);

    switch (t)
    {
    case CMap::tile_ground_fake:
        if ( !on_top && map.isTileGrass(map.getTile(pos + Vec2f(0, -8)).type) ) { // grass
            t = CMap::tile_ground_fake_g0 + (x + y) % 2;
        }
        else
        {
            TileType around = ((on_top || map.getTile(pos + Vec2f(0, -8)).type == CMap::tile_empty) ? 1 : 0) |
                              ((on_bottom || map.getTile(pos + Vec2f(0, 8)).type == CMap::tile_empty) ? 2 : 0) |
                              ((on_left || map.getTile(pos + Vec2f(-8, 0)).type == CMap::tile_empty) ? 4 : 0) |
                              ((on_right || map.getTile(pos + Vec2f(8, 0)).type== CMap::tile_empty) ? 8 : 0) |
                              ((y <= 1 || map.getTile(pos + Vec2f(0, -16)).type == CMap::tile_empty) ? 16 : 0) |
                              ((on_left || on_top || map.getTile(pos + Vec2f(-8, -8)).type == CMap::tile_empty) ? 32 : 0) |
                              ((on_right || on_top || map.getTile(pos + Vec2f(8, -8)).type == CMap::tile_empty) ? 64 : 0);

            if ((around & 1) != 0)
                {;} //nothing, we win
            else if ((around & 2) != 0) {
                t = CMap::tile_ground_fake_v4;
            }
            else if (((around & 4) != 0) && ((around & 8) != 0)) {
                t = CMap::tile_ground_fake_v3 + y%2;
            }
            else if ((around & 4) != 0) {
                t = CMap::tile_ground_fake_v3;
            }
            else if ((around & 8) != 0) {
                t = CMap::tile_ground_fake_v2;
            }
            else if (((around & 16) != 0) || ((around & 32) != 0) || ((around & 64) != 0)) {
                t = CMap::tile_ground_fake_v1;
            }
            else {
                t = CMap::tile_ground_fake_v5 + ((x+y)%2);
            }
        }

        break;

    case CMap::tile_bedrock_fake:
        if (on_top || !map.isTileSolid(map.getTile(pos + Vec2f(0, -8)).type)) {
            t = CMap::tile_bedrock_fake_v3 + fastrandom(x * y, 3);
        }
        else {
            t = CMap::tile_bedrock_fake_v0 + fastrandom(x * y, 4);
        }

        break;
    }

    // masks for fake ground
    if (t == CMap::tile_ground_fake_g0)
    {
        front = false;
        TileType around = ((on_top || map.getTile(pos + Vec2f(0, -8)).type == CMap::tile_empty) ? 1 : 0) |
                          ((on_bottom || map.getTile(pos + Vec2f(0, 8)).type == CMap::tile_empty) ? 2 : 0) |
                          ((on_left || map.getTile(pos + Vec2f(-8, 0)).type == CMap::tile_empty) ? 4 : 0) |
                          ((on_right || map.getTile(pos + Vec2f(8, 0)).type == CMap::tile_empty) ? 8 : 0);

        if (around != 0)
        {
            switch (around)
            {
            case 2|4|8:
                flip = true;
            case 1|4|8:
                t = CMap::tile_ground_fake_g1 + 9;
                break;
            case 1|2|4:
                mirror = true;
            case 1|2|8:
            case 1|2|4|8:
                rotate = true;
                t = CMap::tile_ground_fake_g1 + 9;
                break;
            case 4|8:
                rotate = true;
            case 1|2:
                t = CMap::tile_ground_fake_g1 + 8;
                break;
            case 2:
                flip = true;
            case 1:
                t = CMap::tile_ground_fake_g1 + 7;
                break;
            case 4:
                mirror = true;
            case 8:
                rotate = true;
                t = CMap::tile_ground_fake_g1 + 7;
                break;
            case 1|8:
                mirror = true;
            case 1|4:
                t = CMap::tile_ground_fake_g1 + 6;
                break;
            case 2|8:
                mirror = true;
            case 2|4:
                flip = true;
                t = CMap::tile_ground_fake_g1 + 6;
                break;
            }
        }
        else if ((on_bottom || map.isTileSolid(map.getTile(pos + Vec2f(0, 8)).type)) &&
            !(on_top || map.isTileSolid(map.getTile(pos + Vec2f(0, -8)).type)))
        {
            t = CMap::tile_ground_fake_g1 + 5;
        }
        else if ((on_top || map.isTileSolid(map.getTile(pos + Vec2f(0, -8)).type)) &&
            !(on_bottom || map.isTileSolid(map.getTile(pos + Vec2f(0, 8)).type)))
        {
            t = CMap::tile_ground_fake_g1 + 4;
        }
        else {
            t = CMap::tile_ground_fake_g1 + x%2 + 2*(y%2);    //meta-tiling
        }
    }

    if (tback > 0)
    {
        MakeTileVariation_Custom(map, x, y, tile, tback, dummy, backmirror, backflip, backrotate, dummybool, dummybool, dummybool, dummybool);
    }
}

int fastrandom(int seed, int range)
{
    u32 n = u32(seed);
    n = (n << 13) ^ n;
    u32 nn = (n * (n * n * 15731 + 789221) + 1376312589);
    return int((nn & 0x7fffffff) % u32(range));
}