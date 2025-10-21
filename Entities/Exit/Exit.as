#include "RoomsCommon.as";
#include "RoomsHandlers.as";

void onInit(CBlob@ this)
{
	this.addCommandID("teleport");

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

	if (this.hasTag("ready") && this.get_u32("teleport_time") + base_exit_delay < getGameTime())
	{
		CBlob@ blob = getBlobByNetworkID(this.get_u16("teleported_blob_id"));
		if (blob is null) return;

		if (isClient() && blob.isMyPlayer())
		{
			CRules@ rules = getRules();
			if (rules is null) return;

			u8 level_type = rules.get_u8("current_level_type");
			s32 level_id = rules.get_s32("current_level_id");
			Vec2f start_pos = rules.get_Vec2f("current_room_pos");
			Vec2f room_size = rules.get_Vec2f("current_room_size");

			sendRoomCommand(rules, level_type, level_id + 1, start_pos);
		}
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	CRules@ rules = getRules();
	if (rules is null) return;

	CPlayer@ p = caller.getPlayer();
	if (p is null || p.getNetworkID() != this.get_u16("owner_id")) return;

	// check if next level swap is enabled
	bool next_level_swap = rules.get_bool("next_level_swap");
	if (next_level_swap) return;

	CBitStream params;
	params.write_u16(caller.getNetworkID());

	CButton@ button = caller.CreateGenericButton(
		11,
		Vec2f(0, 0),
		this,
		this.getCommandID("teleport"),
		"Enter next level",
		params
	);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("teleport"))
	{
		u16 pid;
		if (!params.saferead_u16(pid)) { print("Failed to read player ID"); return; }

		// handled in onTick to allow delay
		this.set_u16("teleported_blob_id", pid);
		this.set_u32("teleport_time", getGameTime());

		this.Tag("ready");
		this.getCurrentScript().tickFrequency = 1;
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob is null) return;
	if (!blob.hasTag("player")) return;

	CPlayer@ p = blob.getPlayer();
	if (p is null || p.getNetworkID() != this.get_u16("owner_id")) return;

	CRules@ rules = getRules();
	if (rules is null) return;

	// check if next level swap is enabled
	bool next_level_swap = rules.get_bool("next_level_swap");
	if (!next_level_swap) return;

	// teleport player into next room
	if (this.getTickSinceCreated() < 1) return; // wait a bit after creation

	this.set_u16("teleported_blob_id", blob.getNetworkID());
	this.set_u32("teleport_time", getGameTime());

	this.Tag("ready");
	this.getCurrentScript().tickFrequency = 1;
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