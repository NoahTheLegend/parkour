//knight HUD
#include "/Entities/Common/GUI/ActorHUDStartPos.as";

const string iconsFilename = "Entities/Characters/Knight/KnightIcons.png";
const int slotsSize = 6;

bool mouseWasPressed1 = false;
bool mouseWasPressed2 = false;

void onInit(CSprite@ this)
{
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
	this.getCurrentScript().removeIfTag = "dead";
	this.getBlob().set_u8("gui_HUD_slots_width", slotsSize);

	
}

void ManageCursors(CBlob@ this)
{
	if (getHUD().hasButtons())
	{
		getHUD().SetDefaultCursor();
	}
	else
	{
		if (this.isAttached() && this.isAttachedToPoint("GUNNER"))
		{
			getHUD().SetCursorImage("Entities/Characters/Archer/ArcherCursor.png", Vec2f(32, 32));
			getHUD().SetCursorOffset(Vec2f(-32, -32));
		}
		else
		{
			getHUD().SetCursorImage("Entities/Characters/Knight/KnightCursor.png", Vec2f(32, 32));
			getHUD().SetCursorOffset(Vec2f(-22, -22));
		}
	}
}

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	ManageCursors(blob);

	if (g_videorecording)
		return;

	CPlayer@ player = blob.getPlayer();

	// draw inventory

	Vec2f tl = getActorHUDStartPosition(blob, slotsSize);
	DrawInventoryOnHUD(blob, tl);

	u8 type = blob.get_u8("bomb type");
	u8 frame = 1;
	if (type == 0)
	{
		frame = 0;
	}
	else if (type < 255)
	{
		frame = 1 + type;
	}

	// draw coins

	const int coins = player !is null ? player.getCoins() : 0;
	DrawCoinsOnHUD(blob, coins, tl, slotsSize - 2);

	// draw class icon

	GUI::DrawIcon(iconsFilename, frame, Vec2f(16, 32), tl + Vec2f(8 + (slotsSize - 1) * 40, -16), 1.0f, player.getTeamNum());
	GUI::DrawTextCentered("SPACEBAR - teleport", tl + Vec2f(-80 + (slotsSize - 1) * 40, -16), SColor(255, 255, 255, 255));

	makeWebsiteLink(Vec2f(15, 15), "Guides ", "https://www.youtube.com/playlist?list=PLEBLbNnH0gxFViieG6VQmoM6KMY3Cr1YT");	

	if (blob.isMyPlayer())
	{
		CControls@ controls = getControls();
		if (controls !is null)
		{
			mouseWasPressed1 = controls.mousePressed1; 
			mouseWasPressed2 = controls.mousePressed2; 
		}
	}
}

void makeWebsiteLink(Vec2f pos, const string&in text, const string&in website)
{
	Vec2f dim;
	GUI::GetTextDimensions(text, dim);

	const f32 width = dim.x + 20;
	const f32 height = 32;
	const Vec2f tl = Vec2f(getScreenWidth() - 10 - width - pos.x, pos.y);
	const Vec2f br = Vec2f(getScreenWidth() - 10 - pos.x, tl.y + height);

	CControls@ controls = getControls();
	const Vec2f mousePos = controls.getMouseScreenPos();

	const bool hover = (mousePos.x > tl.x && mousePos.x < br.x && mousePos.y > tl.y && mousePos.y < br.y);
	if (hover)
	{
		GUI::DrawButton(tl, br);

		if (controls.mousePressed1 && !mouseWasPressed1)
		{
			Sound::Play("option");
			OpenWebsite(website);
		}
	}
	else
	{
		GUI::DrawPane(tl, br, 0xffcfcfcf);
	}

	GUI::DrawTextCentered(text, Vec2f(tl.x + (width * 0.50f), tl.y + (height * 0.50f)), 0xffffffff);
}