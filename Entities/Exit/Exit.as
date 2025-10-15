#include "RoomsCommon.as";

void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed(false);
	this.getSprite().getConsts().accurateLighting = true;

	this.Tag("blocks sword");
	this.Tag("blocks water");

	this.getShape().SetStatic(true);
	getMap().server_SetTile(this.getPosition(), CMap::tile_ground_back);
}

void onTick(CBlob@ this)
{
	if (!this.hasTag("set_background"))
	{
		SetMostLikelyBackground(this);
		this.getCurrentScript().tickFrequency = 0;
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob is null) return;
	if (!blob.hasTag("player")) return;

	// teleport player into next room
	if (this.getTickSinceCreated() < 1) return; // wait a bit after creation
	if (isClient() && blob.isMyPlayer())
	{
		CRules@ rules = getRules();
		if (rules is null) return;

		u8 room_type = rules.get_u8("current_room_type");
		s32 room_id = rules.get_s32("current_room_id");
		Vec2f start_pos = rules.get_Vec2f("current_room_pos");
		Vec2f room_size = rules.get_Vec2f("current_room_size");

		sendRoomCommand(rules, room_type, room_id + 1, start_pos);
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return false;
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}

void SetMostLikelyBackground(CBlob@ this)
{
	this.Tag("set_background");

	u8 adjacent_ground_back = 0;
	u8 adjacent_castle_back = 0;
	u8 adjacent_wood_back = 0;

	for (u8 i = 0; i < 4; i++)
	{
		Vec2f dir;
		if (i == 0) dir = Vec2f(8, 0);
		else if (i == 1) dir = Vec2f(-8, 0);
		else if (i == 2) dir = Vec2f(0, 8);
		else if (i == 3) dir = Vec2f(0, -8);

		Tile tile = getMap().getTile(this.getPosition() + dir);
		switch (tile.type)
		{
			case CMap::tile_ground_back:
				adjacent_ground_back++;
				break;
			case CMap::tile_castle_back:
				adjacent_castle_back++;
				break;
			case CMap::tile_wood_back:
				adjacent_wood_back++;
				break;
		}
	}

	if (adjacent_ground_back >= 2)
	{
		CMap@ map = getMap();
		if (map is null) return;

		map.server_SetTile(this.getPosition(), CMap::tile_ground_back);
	}
	else if (adjacent_castle_back >= 2)
	{
		CMap@ map = getMap();
		if (map is null) return;

		map.server_SetTile(this.getPosition(), CMap::tile_castle_back);
	}
	else if (adjacent_wood_back >= 2)
	{
		CMap@ map = getMap();
		if (map is null) return;

		map.server_SetTile(this.getPosition(), CMap::tile_wood_back);
	}
}