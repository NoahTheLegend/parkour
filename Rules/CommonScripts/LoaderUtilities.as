// LoaderUtilities.as

#include "DummyCommon.as";

bool onMapTileCollapse(CMap@ map, u32 offset)
{
	CBlob@ blob = getBlobByNetworkID(server_getDummyGridNetworkID(offset));
	if (blob !is null)
	{
		blob.server_Die();
	}

	return false;
}

/*
TileType server_onTileHit(CMap@ this, f32 damage, u32 index, TileType oldTileType)
{
}
*/

void onSetTile(CMap@ map, u32 index, TileType tile_new, TileType tile_old)
{
	map.SetTileSupport(index, 255);

	if(isDummyTile(tile_new))
	{
		switch(tile_new)
		{
			case Dummy::SOLID:
			case Dummy::OBSTRUCTOR:
				map.AddTileFlag(index, Tile::SOLID | Tile::COLLISION);
				break;
			case Dummy::BACKGROUND:
			case Dummy::OBSTRUCTOR_BACKGROUND:
				map.AddTileFlag(index, Tile::BACKGROUND | Tile::LIGHT_PASSES | Tile::WATER_PASSES);
				break;
			case Dummy::LADDER:
				map.AddTileFlag(index, Tile::BACKGROUND | Tile::LIGHT_PASSES | Tile::LADDER | Tile::WATER_PASSES);
				break;
			case Dummy::PLATFORM:
				map.AddTileFlag(index, Tile::PLATFORM);
				break;
		}
	}

	if (isTileFake(tile_new))
	{
		map.AddTileFlag(index, Tile::SOLID | Tile::COLLISION);
	}

	if (tile_old != tile_new && isTileFirstOfType(tile_new))
	{
		u32 x = index % map.tilemapwidth;
		u32 y = index / map.tilemapwidth;

		MakeTileVariation_Custom(map, x, y, tile_new, tile_old);
	}
}
