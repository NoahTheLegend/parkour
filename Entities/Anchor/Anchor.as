#include "RoomsCommon.as";

void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed(false);
	this.getSprite().getConsts().accurateLighting = true;

	//this.set_TileType("background tile", CMap::tile_groundback);
	this.Tag("blocks sword");
	this.Tag("blocks water");

	this.getShape().SetStatic(true);
	this.getShape().SetGravityScale(0.0f);
	this.getShape().getConsts().mapCollisions = false;
	this.getSprite().setRenderStyle(RenderStyle::additive);

	this.addCommandID("replace");
}

void onTick(CBlob@ this)
{
	u16 owner_id = this.get_u16("owner_id");
	if (owner_id == 0) return;

	CPlayer@ player = getPlayerByNetworkId(owner_id);
	if (player is null) return;

	if (!player.isMyPlayer()) return;

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

	if (this.hasTag("set_static"))
	{
		this.setPosition(this.get_Vec2f("init_pos"));
		this.getShape().SetStatic(true);
		this.Untag("set_static");
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("replace"))
	{
		Vec2f pos = params.read_Vec2f();

		this.getShape().SetStatic(false);
		this.setPosition(pos);
		this.set_Vec2f("init_pos", pos);

		this.Tag("set_static");
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