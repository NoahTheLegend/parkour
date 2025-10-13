#include "Default/DefaultGUI.as"
#include "Default/DefaultLoaders.as"
#include "PrecacheTextures.as"
#include "EmotesCommon.as"

void onInit(CRules@ this)
{
	this.addCommandID("create_rooms_grid");
	this.addCommandID("set_room");
	
	LoadDefaultMapLoaders();
	LoadDefaultGUI();

	// comment this out if you want to restore legacy net command script
	// compatibility. mods that include scripts from before build 4541 may
	// additionally want to bring back scripts they share commands with.
	getNet().legacy_cmd = false;
	getMap().legacyTileEffects = false;

	if (isServer())
	{
		getSecurity().reloadSecurity();
	}

	sv_gravity = 9.81f;
	particles_gravity.y = 0.25f;
	sv_visiblity_scale = 1.25f;
	cc_halign = 2;
	cc_valign = 2;

	s_effects = false;

	sv_max_localplayers = 1;

	PrecacheTextures();

	//smooth shader
	Driver@ driver = getDriver();

	driver.AddShader("hq2x", 1.0f);
	driver.SetShader("hq2x", true);

	//reset var if you came from another gamemode that edits it
	SetGridMenusSize(24,2.0f,32);

	//also restart stuff
	onRestart(this);
}

bool need_sky_check = true;
void onRestart(CRules@ this)
{
	//map borders
	CMap@ map = getMap();
	if (map !is null)
	{
		map.SetBorderFadeWidth(24.0f);
		map.SetBorderColourTop(SColor(0xff000000));
		map.SetBorderColourLeft(SColor(0xff000000));
		map.SetBorderColourRight(SColor(0xff000000));
		map.SetBorderColourBottom(SColor(0xff000000));

		//do it first tick so the map is definitely there
		//(it is on server, but not on client unfortunately)
		need_sky_check = true;
	}

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

void onTick(CRules@ this)
{
	//TODO: figure out a way to optimise so we don't need to keep running this hook
	if (need_sky_check)
	{
		need_sky_check = false;
		CMap@ map = getMap();
		//find out if there's any solid tiles in top row
		// if not - semitransparent sky
		// if yes - totally solid, looks buggy with "floating" tiles
		bool has_solid_tiles = false;
		for(int i = 0; i < map.tilemapwidth; i++) {
			if(map.isTileSolid(map.getTile(i))) {
				has_solid_tiles = true;
				break;
			}
		}
		map.SetBorderColourTop(SColor(has_solid_tiles ? 0xff000000 : 0x80000000));
	}
}

//chat stuff!

void onEnterChat(CRules @this)
{
	if (getChatChannel() != 0) return; //no dots for team chat

	CBlob@ localblob = getLocalPlayerBlob();
	if (localblob !is null)
		set_emote(localblob, "dots", 100000);
}

void onExitChat(CRules @this)
{
	CBlob@ localblob = getLocalPlayerBlob();
	if (localblob !is null)
		set_emote(localblob, "", 0);
}