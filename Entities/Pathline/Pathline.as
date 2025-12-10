#include "RoomsCommon.as";
#include "RoomsHandlers.as";
#include "CommandHandlers.as";

void onInit(CBlob@ this)
{
	this.addCommandID("sync");
	this.addCommandID("switch");

	this.getShape().SetRotationsAllowed(false);
	this.getSprite().getConsts().accurateLighting = true;

	this.getShape().SetStatic(true);
	this.getShape().SetGravityScale(0.0f);
	this.getShape().getConsts().mapCollisions = false;

	this.set_u8("room_id", 0);
	this.set_bool("active", false);
	this.set_u32("start_time", 0);
	this.set_Vec2f("room_pos", Vec2f(0,0));
}

void onTick(CBlob@ this)
{
	if (isServer() && this.hasTag("sync"))
	{
		// sync pathline data
		CBitStream params;
		params.write_string(this.get_string("pathline_tag"));
		params.write_Vec2f(this.get_Vec2f("grapple_pos"));
		params.write_u32(this.get_u32("time"));
		params.write_u16(this.get_u16("pathline_owner_id"));
		this.SendCommand(this.getCommandID("sync"), params);
		
		this.Untag("sync");
	}

	u32 time = this.get_u32("time");
	if (time + 1 >= getGameTime())
	{
		return;
	}

	if (!isClient()) return;
	//if (!this.get_bool("active")) return;
	if (!this.isOnScreen()) return;
	
	Vec2f offset = Vec2f(0, -3);
	Vec2f thispos = this.getPosition() + offset;

	Vec2f thisoldpos = this.get_Vec2f("oldpos");
	this.set_Vec2f("oldpos", thispos);

	if (thisoldpos.x < 8 && thisoldpos.y < 8) return;
	if ((thisoldpos - thispos).Length() >= 48.0f) return;

	bool is_archer = Maths::Abs(this.getHealth() - 2.0f) < 0.001f;
	Vec2f grapple_pos_raw = this.get_Vec2f("grapple_pos");
	Vec2f grapple_pos = grapple_pos_raw + offset;

	// main particle at blob position
	{
		Vec2f dir = thispos - thisoldpos;
		f32 dist = dir.Length();

		f32 spacing = 1.0f;
		u32 line_qty = u32(Maths::Ceil(dist / spacing));
		if (line_qty == 0) line_qty = 1;

		for (u32 d = 0; d < line_qty; d++)
		{
			f32 tt = dist > 0.0f ? d / dist : 0.0f;
			Vec2f at = thisoldpos + dir * tt;
			int time = 15;

			CParticle@ p = ParticleAnimated("PathlineCursor.png", at, Vec2f(0,0), 0, 0, time, 0.0f, true);
			if (p !is null)
			{
				p.fastcollision = true;
				p.gravity = Vec2f(0, 0);
				p.scale = 0.75f;
				p.growth = -0.075f;
				p.deadeffect = -1;
				p.collides = false;
				p.Z = 150.0f;

				f32 phase = (getGameTime() + d) * 0.1f;
				f32 t = Maths::Sin(phase) * 0.5f + 0.5f;
				u8 g = u8(255 - int(t * 85));
				u8 b = u8(255 - int(t * 25));
				SColor col = SColor(255, 255, g, b);

				p.colour = col;
				p.forcecolor = col;
			}
		}
	}

	// if in archer mode (health == 2.0f) spawn a trail from aim pos to this pos
	if (is_archer)
	{
		Vec2f dir = thispos - grapple_pos;
		f32 dist = dir.Length();

		if (dist > 8.0f && grapple_pos_raw != Vec2f_zero)
		{
			// spacing (pixels) between trail particles
			f32 spacing = 1.0f;
			u32 line_qty = u32(Maths::Ceil(dist / spacing));
			if (line_qty == 0) line_qty = 1;

			for (u32 j = 0; j < line_qty; j++)
			{
				f32 tt = line_qty > 1 ? f32(j) / f32(line_qty - 1) : 0.0f;
				Vec2f at = grapple_pos + dir * tt;
				int time = 2;

				CParticle@ lp = ParticleAnimated("PathlineCursorGrapple.png", at, Vec2f(0,0), 0, 0, time, 0.0f, true);
				if (lp !is null)
				{
					lp.fastcollision = true;
					lp.gravity = Vec2f(0, 0);
					lp.scale = 0.25f;
					lp.growth = -0.01f;
					lp.deadeffect = -1;
					lp.collides = false;
					lp.Z = 151.0f;
				}
			}
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("sync"))
	{
		if (!isClient()) return;

		string pathline_tag;
		if (!params.saferead_string(pathline_tag)) return;

		Vec2f grapple_pos;
		if (!params.saferead_Vec2f(grapple_pos)) return;

		u32 time;
		if (!params.saferead_u32(time)) return;

		u16 owner_id;
		if (!params.saferead_u16(owner_id)) return;

		this.Tag(pathline_tag);
		this.set_Vec2f("grapple_pos", grapple_pos);
		this.set_u32("time", time);
		this.set_u16("pathline_owner_id", owner_id);
	}
	else if (cmd == this.getCommandID("switch"))
	{
		u16 pid;
		if (!params.saferead_u16(pid)) return;

		CPlayer@ player = getPlayerByNetworkId(pid);
		if (player is null) return;

		u32 gt;
		if (!params.saferead_u32(gt)) return;

		u8 current_type;
		if (!params.saferead_u8(current_type)) return;

		// hack, using health as type switcher
		if (isServer()) this.server_SetHealth(current_type + 1.0f);

		this.set_u32("start_time", gt);
		this.set_bool("active", !this.get_bool("active"));
		this.set_u32("time", getGameTime());

	    this.Sync("active", true);
		this.Sync("start_time", true);
		this.Sync("time", true);
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
