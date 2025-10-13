#include "RoomsCommon.as";

void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed(false);
	this.getSprite().getConsts().accurateLighting = true;
	this.getCurrentScript().tickFrequency = 0;

	this.Tag("blocks sword");
	this.Tag("blocks water");

	this.getShape().SetStatic(true);
	getMap().server_SetTile(this.getPosition(), CMap::tile_ground_back);
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob is null) return;
	if (!blob.hasTag("player")) return;

	// teleport player into next room
	if (this.getTickSinceCreated() < 30) return; // wait a bit after creation
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return false;
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}