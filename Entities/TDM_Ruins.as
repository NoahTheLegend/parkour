// TDM Ruins logic

#include "ClassSelectMenu.as"
#include "StandardRespawnCommand.as"
#include "StandardControlsCommon.as"
#include "GenericButtonCommon.as"

void onInit(CBlob@ this)
{
	this.CreateRespawnPoint("ruins", Vec2f(0.0f, 16.0f));
	AddIconToken("$change_class$", "/GUI/InteractionIcons.png", Vec2f(32, 32), 12, 2);
	//TDM classes
	//addPlayerClass(this, "Knight", "$knight_class_icon$", "knight", "Hack and Slash.");
	//addPlayerClass(this, "Archer", "$archer_class_icon$", "archer", "The Ranged Advantage.");
	this.getShape().SetStatic(true);
	this.getShape().getConsts().mapCollisions = false;
	this.addCommandID("change class");

	this.Tag("change class drop inventory");

	this.getSprite().SetZ(-50.0f);   // push to background

	// minimap
	this.SetMinimapOutsideBehaviour(CBlob::minimap_snap);
	this.SetMinimapVars("GUI/Minimap/MinimapIcons.png", 29, Vec2f(8, 8));
	this.SetMinimapRenderAlways(true);

	for (u8 i = 0; i < font_names.length; i++)
	{
		string[] parts = font_names[i].split("_");
		if (parts.length == 2)
		{
			string full_font_name = font_names[i];
			string font_name = parts[0];
			string font_size = parts[1];
			
			if (!GUI::isFontLoaded(font_name))
			{
				string font_path = CFileMatcher(full_font_name + ".ttf").getFirst();
				GUI::LoadFont(full_font_name, font_path, parseInt(font_size), true);
			}
		}
	}
}

const string[] font_names = {
     "Sakana_8",
     "Sakana_10",
     "Sakana_12",
     "Sakana_14",
     "Sakana_16",
     "Sakana_18",
     "Terminus_8",
     "Terminus_10",
     "Terminus_12",
     "Terminus_14",
	 "Terminus_16",
     "Terminus_18"
};

void onTick(CBlob@ this)
{
	if (enable_quickswap)
	{
		//quick switch class
		CBlob@ blob = getLocalPlayerBlob();
		if (blob !is null && blob.isMyPlayer())
		{
			if (
				isInRadius(this, blob) && //blob close enough to ruins
				blob.isKeyJustReleased(key_use) && //just released e
				isTap(blob, 7) && //tapped e
				blob.getTickSinceCreated() > 1 //prevents infinite loop of swapping class
			) {
				CycleClass(this, blob);
			}
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	onRespawnCommand(this, cmd, params);
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	AddIconToken("$knight_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 12, caller.getTeamNum());
	AddIconToken("$archer_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 16, caller.getTeamNum());
	
	if (!canSeeButtons(this, caller)) return;

	if (canChangeClass(this, caller))
	{
		if (isInRadius(this, caller))
		{
			BuildRespawnMenuFor(this, caller);
		}
		else
		{
			CBitStream params;
			caller.CreateGenericButton("$change_class$", Vec2f(0, 0), this, buildSpawnMenu, getTranslatedString("Change class"));
		}
	}

	// warning: if we don't have this button just spawn menu here we run into that infinite menus game freeze bug
}

bool isInRadius(CBlob@ this, CBlob @caller)
{
	return (this.getPosition() - caller.getPosition()).Length() < this.getRadius();
}
