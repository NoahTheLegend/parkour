#include "Hitters.as"

#include "FireCommon.as"

void onInit(CBlob@ this)
{
	this.SetFacingLeft(XORRandom(128) > 64);

	this.getShape().getConsts().waterPasses = true;

	CShape@ shape = this.getShape();
	shape.AddPlatformDirection(Vec2f(0, -1), 89, false);
	shape.SetRotationsAllowed(false);

	this.server_setTeamNum(0); //allow anyone to break them
	this.set_TileType("background tile", CMap::tile_wood_back);
	this.set_s16(burn_duration , 300*10000);
	//transfer fire to underlying tiles
	this.Tag(spread_fire_tag);

	if (this.getName() == "wooden_platform")
	{
		if (getNet().isServer())
		{
			dictionary harvest;
			harvest.set('mat_wood', 4);
			this.set('harvest', harvest);
		}
	}
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic) return;

	this.getSprite().PlaySound("/build_wood.ogg");
}

void onTick(CBlob@ this)
{
	//if (getGameTime()==30 && isServer())
	//{
	//	CBlob@ p = server_CreateBlob("wooden_platform", 0, this.getPosition());
	//	if (p !is null)
	//	{
	//		p.SetFacingLeft(this.isFacingLeft());
	//		if (p.getShape() !is null)
	//		{
	//			p.getShape().SetAngleDegrees(this.getAngleDegrees());
	//			p.getShape().SetStatic(true);
	//			this.server_Die();
	//		}
	//		else p.server_Die();
	//	}
	//}
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}
