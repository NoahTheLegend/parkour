#include "RoomsCommon.as";
#include "RoomsHandlers.as";
#include "RoomsHooks.as";

void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed(false);
	this.getSprite().getConsts().accurateLighting = true;

	//this.set_TileType("background tile", CMap::tile_groundback);
	this.Tag("blocks sword");
	this.Tag("blocks water");

	this.getShape().SetGravityScale(0.0f);
	this.getShape().getConsts().mapCollisions = false;
	this.getSprite().setRenderStyle(RenderStyle::additive);

	this.addCommandID("replace");
}

void onTick(CBlob@ this)
{
	if (!this.hasTag("set_background")) SetMostLikelyBackground(this);

	u16 owner_id = this.get_u16("owner_id");
	if (owner_id == 0) return;

	CPlayer@ player = getPlayerByNetworkId(owner_id);
	if (player is null) return;

	if (!player.isMyPlayer()) return;
	if (isClient() && this.getTickSinceCreated() == 1)
	{
		CRules@ rules = getRules();
		if (rules !is null) rules.set_Vec2f("current_anchor_pos", this.getPosition());
	}

	CBlob@ blob = player.getBlob();
	if (blob is null) return;

	CControls@ controls = getControls();
	if (controls is null) return;

	bool was_pressed_key_mark = this.get_bool("was_pressed_key_mark");
	bool pressed_key_build_modifier = controls.ActionKeyPressed(AK_BUILD_MODIFIER);

	bool just_pressed_key_mark = controls.ActionKeyPressed(AK_PARTY) && !was_pressed_key_mark;
	this.set_bool("was_pressed_key_mark", controls.ActionKeyPressed(AK_PARTY));

	bool teleport = just_pressed_key_mark && !pressed_key_build_modifier;
	bool replace = just_pressed_key_mark && pressed_key_build_modifier;

	if (!this.hasTag("teleported") || teleport)
	{
		Vec2f pos = this.getPosition();
		pos.y -= this.getHeight() * 0.5f;

		blob.setVelocity(Vec2f_zero);
		blob.setPosition(pos);
		blob.AddForce(Vec2f_zero); // update shape;

		this.Tag("teleported");
	}
	else if (replace)
	{
		Vec2f blob_pos = blob.getPosition();
		blob_pos.y += this.getHeight() * 0.5f;

		CBitStream params;
		params.write_Vec2f(blob_pos);
		this.SendCommand(this.getCommandID("replace"), params);
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("replace"))
	{
		Vec2f pos = params.read_Vec2f();
		this.set_Vec2f("init_pos", pos);

		this.set_u32("set_static", getGameTime() + 1);
		this.setPosition(pos);
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