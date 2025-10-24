#include "Hitters.as"

void onInit(CBlob@ this)
{
	this.SetFacingLeft(XORRandom(128) > 64);
	this.getShape().getConsts().waterPasses = false;

	CShape@ shape = this.getShape();
	shape.AddPlatformDirection(Vec2f(0, -1), 89, false);
	shape.SetRotationsAllowed(false);

	this.server_setTeamNum(255);
	this.set_TileType("background tile", CMap::tile_wood_back);

	MakeDamageFrame(this);
}

void onTick(CBlob@ this)
{

}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return true;
}

void onHealthChange(CBlob@ this, f32 oldHealth)
{
	f32 hp = this.getHealth();
	bool repaired = (hp > oldHealth);
	MakeDamageFrame(this, repaired);
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	return 0;
}

void MakeDamageFrame(CBlob@ this, bool repaired = false)
{
	f32 hp = this.getHealth();
	f32 full_hp = this.getInitialHealth();
	int frame_count = this.getSprite().animation.getFramesCount();
	int frame = frame_count - frame_count * (hp / full_hp);
	this.getSprite().animation.frame = frame;

	if (repaired)
	{
		this.getSprite().PlaySound("/build_wood.ogg");
	}
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic) return;

	this.getSprite().PlaySound("/build_wood.ogg");
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}
