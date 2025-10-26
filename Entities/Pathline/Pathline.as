#include "RoomsCommon.as";
#include "RoomsHandlers.as";
#include "CommandHandlers.as";

void onInit(CBlob@ this)
{
	this.addCommandID("sync");

	this.getShape().SetRotationsAllowed(false);
	this.getSprite().getConsts().accurateLighting = true;

	this.getShape().SetStatic(true);
	this.getShape().SetGravityScale(0.0f);
	this.getShape().getConsts().mapCollisions = false;
}

void onTick(CBlob@ this)
{

}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return false;
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}
