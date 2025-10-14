#define SERVER_ONLY

void onTick(CBlob@ this)
{
	if (this.getTickSinceCreated() >= 1)
	{
		if (!this.getShape().isStatic())
		{
			return;
		}
		
		if (this.exists("background tile") && this.get_TileType("background tile") != 0)
		{
			CMap@ map = getMap();
			Vec2f position = this.getPosition();
			const u16 type = this.get_TileType("background tile");
	
			if (map.getTile(position).type != CMap::tile_castle_back)
			{
				map.server_SetTile(position, type);
			}
		}
	
		this.getCurrentScript().runFlags |= Script::remove_after_this;
	}
}