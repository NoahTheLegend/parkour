// PressurePlate.as

#include "MechanismsCommon.as";

class Plate : Component
{
	Plate(Vec2f position)
	{
		x = position.x;
		y = position.y;
	}
};

void onInit(CBlob@ this)
{
	// used by BuilderHittable.as
	this.Tag("builder always hit");

	// used by KnightLogic.as
	this.Tag("blocks sword");

	// used by TileBackground.as
	this.set_TileType("background tile", CMap::tile_wood_back);

	this.addCommandID("activate client");
	this.addCommandID("deactivate client");
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic || this.exists("component")) return;

	const Vec2f position = this.getPosition() / 8;

	Plate component(position);
	this.set("component", component);

	this.set_u8("state", 0);
	this.set_u32("cooldown", getGameTime() + 40);
	this.set_u16("angle", this.getAngleDegrees());

	if (isServer())
	{
		MapPowerGrid@ grid;
		if (!getRules().get("power grid", @grid)) return;

		grid.setAll(
		component.x,                        // x
		component.y,                        // y
		TOPO_NONE,                          // input topology
		TOPO_CARDINAL,                      // output topology
		INFO_SOURCE,                        // information
		0,                                  // power
		0);                                 // id
	}

	this.getSprite().SetZ(100);
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (!isServer()) return;

	Component@ component = null;
	if (!this.get("component", @component)) return;

	// if active, ignore
	if (this.get_u8("state") > 0) return;

	if (blob is null || !canActivatePlate(blob) || !isTouchingPlate(this, blob)) return;

	Activate(this);
}

void onEndCollision(CBlob@ this, CBlob@ blob)
{
	if (!isServer()) return;

	Component@ component = null;
	if (!this.get("component", @component)) return;

	// if !active, ignore
	if (this.get_u8("state") == 0) return;

	const uint touching = this.getTouchingCount();
	for(uint i = 0; i < touching; i++)
	{
		CBlob@ t = this.getTouchingByIndex(i);
		if (t !is null && canActivatePlate(t) && isTouchingPlate(this, t)) return;
	}

	Deactivate(this);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("activate client") && isClient())
	{
		CSprite@ sprite = this.getSprite();
		if (sprite is null) return;

		sprite.SetFrameIndex(1);
		sprite.PlaySound("LeverToggle.ogg");
	}
	else if (cmd == this.getCommandID("deactivate client") && isClient())
	{
		CSprite@ sprite = this.getSprite();
		if (sprite is null) return;

		sprite.SetFrameIndex(0);
		sprite.PlaySound("LeverToggle.ogg");
	}
}

void Activate(CBlob@ this)
{
	Component@ component = null;
	if (!this.get("component", @component)) return;

	this.set_u8("state", 1);
	this.Sync("state", true);

	// setInfo is too slow for fast collisions, need to set power as well
	MapPowerGrid@ grid;
	if (!getRules().get("power grid", @grid)) return;

	grid.setAll(
	component.x,                        // x
	component.y,                        // y
	TOPO_NONE,                          // input topology
	TOPO_CARDINAL,                      // output topology
	INFO_SOURCE | INFO_ACTIVE,          // information
	power_source,                       // power
	0);     

	this.SendCommand(this.getCommandID("activate client"));
}

void Deactivate(CBlob@ this)
{
	Component@ component = null;
	if (!this.get("component", @component)) return;

	this.set_u8("state", 0);
	this.Sync("state", true);

	MapPowerGrid@ grid;
	if (!getRules().get("power grid", @grid)) return;

	grid.setInfo(
	component.x,                        // x
	component.y,                        // y
	INFO_SOURCE);                       // information

	this.SendCommand(this.getCommandID("deactivate client"));
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}

bool canActivatePlate(CBlob@ blob)
{
	if (blob is null) return false;
	CShape@ shape = blob.getShape();
	if (shape is null || shape.isStatic() || !blob.isCollidable())
	{
		return false;
	}
	if (blob.hasTag("was_hit"))
	{
		return false;
	}
	return true;
}

bool isTouchingPlate(CBlob@ this, CBlob@ blob)
{
	Vec2f touch = this.getTouchingOffsetByBlob(blob);
	f32 angle = touch.Angle();

	switch (this.get_u16("angle"))
	{
		case 0: if (angle <= 135 && angle >= 45) return true;
			break;

		case 90: if (angle <= 45 || angle >= 315) return true;
			break;

		case 180: if (angle <= 315 && angle >= 225) return true;
			break;

		case 270: if (angle <= 225 && angle >= 135) return true;
			break;
	}

	return false;
}

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;
	if (!blob.isOnScreen()) return;

	GUI::SetFont("menu");
	Vec2f pos2d = getDriver().getScreenPosFromWorldPos(blob.getPosition());
	 
	int touching = blob.getTouchingCount();
	for (int i = 0; i < touching; i++)
	{
		CBlob@ b = blob.getTouchingByIndex(i);
		if (b is null) continue;

		if (b.isMyPlayer() && b.hasTag("was_hit"))
		{
			GUI::DrawTextCentered("You need to complete the level without taking any damage!\nRestart with touching a sensor", pos2d+Vec2f(0,20), SColor(255,255,0,0));
			break;
		}
	}
}