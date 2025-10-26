#define CLIENT_ONLY

#include "TeamColour.as";
#include "KGUI.as";
#include "Listeners.as";
#include "RoomsCommon.as";
#include "CommandHandlers.as";
#include "PseudoVideoPlayer.as";

const Vec2f menuSize = Vec2f(720, 480);
const f32 slideOffset = 100.0f; // extra height
const u32 warn_menu_movement_time = 30;
const Vec2f default_grid = Vec2f(4, 4);
const Vec2f default_grid_levels = Vec2f(4, 3);

string hovering_filename = "";
Vec2f hovering_size = Vec2f_zero;
VideoPlayer@[] help_videos;

VideoPlayer@[] active_help_videos;
Vec2f[] active_help_video_positions;

bool showMenu = false;
f32 active_time = 0;

bool previous_showMenu = true;
bool justJoined = true;

//key names
const string party_key = getControls().getActionKeyKeyName( AK_PARTY );
const string inv_key = getControls().getActionKeyKeyName( AK_INVENTORY );
const string pick_key = getControls().getActionKeyKeyName( AK_PICKUP );
const string taunts_key = getControls().getActionKeyKeyName( AK_TAUNTS );
const string use_key = getControls().getActionKeyKeyName( AK_USE );
const string action1_key = getControls().getActionKeyKeyName( AK_ACTION1 );
const string action2_key = getControls().getActionKeyKeyName( AK_ACTION2 );
const string action3_key = getControls().getActionKeyKeyName( AK_ACTION3 );
const string map_key = getControls().getActionKeyKeyName( AK_MAP );
const string zoomIn_key = getControls().getActionKeyKeyName( AK_ZOOMIN );
const string zoomOut_key = getControls().getActionKeyKeyName( AK_ZOOMOUT );

//----KGUI ELEMENTS----\\
Window@ menuWindow;
Rectangle@ mainFrame;
Rectangle@ infoFrame;
Rectangle@ levelsFrame;
Rectangle@ knightLevelsFrame;
Rectangle@ archerLevelsFrame;
Rectangle@ builderLevelsFrame;
Rectangle@ customLevelsFrame;
Rectangle@ helpFrame;
Rectangle@ settingsFrame;
Rectangle@ chessInfoFrame;

bool isGUINull()
{
	return
               @menuWindow == null
			|| @infoFrame == null
			|| @mainFrame == null
			|| @levelsFrame == null
			|| @knightLevelsFrame == null
			|| @archerLevelsFrame == null
			|| @builderLevelsFrame == null
			|| @customLevelsFrame == null
			|| @helpFrame == null
			|| @chessInfoFrame == null;
}

bool isHidden()
{
    return !showMenu;
}

void LoadLevels()
{
	// knight
	Rectangle@ k_slider = cast<Rectangle@>(knightLevelsFrame.getChild("slider"));
	uint knight_count = 0;
	if (k_slider !is null)
	{
		LoadClassLevels("Rooms/Knight/", "k_", k_slider, SColor(0, 225, 179, 126), "knight", knight_count);
	}

	// archer
	Rectangle@ a_slider = cast<Rectangle@>(archerLevelsFrame.getChild("slider"));
	uint archer_count = 0;
	if (a_slider !is null)
	{
		LoadClassLevels("Rooms/Archer/", "a_", a_slider, SColor(0, 179, 225, 126), "archer", archer_count);
	}
}

void LoadClassLevels(const string &in dir, const string &in filePrefix, Rectangle@ slider, const SColor &in rectColor, const string &in logName, uint &out level_count)
{
	level_count = 0;
	for (uint i = 0; i < 256; i++)
	{
		string path = CFileMatcher(dir + filePrefix + i + ".png").getFirst();
		if (path == "") break;

		CFileImage@ img = @CFileImage(path);
		if (img is null) continue;

		Vec2f img_size = Vec2f(img.getWidth(), img.getHeight());
		if (img_size.x > ROOM_SIZE.x / 8 || img_size.y > ROOM_SIZE.y / 8)
		{
			warn("[WRN] Skipping level " + path + " due to excessive size: " + img_size.x + "x" + img_size.y);
			continue;
		}

		f32 icon_scale = 1.0f;
		f32 max = 80.0f;

		Rectangle@ level = @Rectangle(Vec2f(0, 0), Vec2f(Maths::Min(max * 2, img_size.x * 2), Maths::Min(max * 2, img_size.y * 2)), rectColor);
		level.name = filePrefix + i;
		level.addClickListener(loadLevelClickListener);
		level.addHoverStateListener(levelHoverListener);
		slider.addChild(level);

		if (img_size.x > max || img_size.y > max)
		{
			f32 biggest = Maths::Max(img_size.x, img_size.y);
			icon_scale = max / biggest;
		}

		Icon@ icon = @Icon(path, Vec2f_zero, img_size, 0, icon_scale, false);
		icon.name = "icon";
		icon.size = img_size;
		icon.scale = icon_scale;
		level.addChild(icon);

		Button@ text_pane = @Button(Vec2f_zero, Vec2f(40, 20), "", SColor(255, 0, 0, 0), "Terminus_12");
		text_pane.name = "text_pane";
		text_pane.rectColor = SColor(255, 255, 0, 0);
		level.addChild(text_pane);

		Vec2f pane_size = Vec2f(text_pane.size.x / 2 - 2, 8);
		Label@ text = @Label(pane_size + Vec2f(0, 1), pane_size, "" + i, SColor(255, 255, 255, 255), true, "Terminus_12");
		text_pane.addChild(text);

		level_count++;
	}

	print("Loaded " + level_count + " " + logName + " levels");
}

void LoadVideos()
{
	f32 _10fps = 0.5f;
	f32 _60fps = 3.0f / 1.0f;
}

void onInit(CRules@ this)
{
	this.set_bool("GUI initialized", false);
	this.addCommandID("join");
	u_showtutorial = true;

	string configstr = "../Cache/NoahsParkour.cfg";
	ConfigFile cfg = ConfigFile(configstr);
	if (!cfg.exists("init"))
	{
        // init values
		cfg.saveFile("NoahsParkour.cfg");
	}
}

void onTick(CRules@ this)
{
	if (this.hasTag("close_menu"))
	{
		warn("[INF] Closing menu as requested");
		showMenu = false;
		this.Untag("close_menu");
	}

	bool initialized = this.get_bool("GUI initialized");
	if ((!initialized || isGUINull()))
	{
		LoadVideos(); // must be before InitializeGUI
        InitializeGUI(this);
		LoadLevels(); // must be after InitializeGUI

		updateOptionSliderValues();
    	setCachedStates(this);
	}

	EnsureRoomOwned(this);

	CControls@ controls = getControls();
	if (controls.isKeyJustPressed(KEY_F1)) showMenu = !showMenu;
	
	CPlayer@ player = getLocalPlayer();  
	if (player is null) return;

	HandleInput(this, controls, player);

	string name = player.getUsername();
    bool previous_showMenu = showMenu; // must be last
	this.set_bool("showMenu", showMenu);
}

void HandleInput(CRules@ rules, CControls@ controls, CPlayer@ player)
{
	if (!showMenu) return;

	Rectangle@ levelsWrapper = cast<Rectangle@>(levelsFrame.getChild("levelsWrapper"));
	if (levelsWrapper is null) return;

	// A / D interaction
	if (controls.isKeyJustPressed(KEY_KEY_A))
	{
		if (helpFrame.isEnabled)
		{
			Button@ scroller = cast<Button@>(helpFrame.getChild("helpFrameScrollerLeft"));
			if (scroller is null) return;

			Vec2f scroller_pos = scroller.getAbsolutePosition();
			scrollerClickListener(scroller_pos.x, scroller_pos.y + 1, 1, scroller);
		}
		else if (levelsWrapper.isEnabled)
		{
			bool knight_levels = knightLevelsFrame.isEnabled;
			bool archer_levels = archerLevelsFrame.isEnabled;
			bool builder_levels = builderLevelsFrame.isEnabled;
	
			Button@ scroller;
			Rectangle@ slider;

			if (knight_levels)
			{
				@scroller = cast<Button@>(levelsWrapper.getChild("knightLevelsFrame").getChild("levelsFrameScrollerLeft"));
				@slider = cast<Rectangle@>(levelsWrapper.getChild("knightLevelsFrame").getChild("slider"));
			}
			else if (archer_levels)
			{
				@scroller = cast<Button@>(levelsWrapper.getChild("archerLevelsFrame").getChild("levelsFrameScrollerLeft"));
				@slider = cast<Rectangle@>(levelsWrapper.getChild("archerLevelsFrame").getChild("slider"));
			}
			else if (builder_levels)
			{
				@scroller = cast<Button@>(levelsWrapper.getChild("builderLevelsFrame").getChild("levelsFrameScrollerLeft"));
				@slider = cast<Rectangle@>(levelsWrapper.getChild("builderLevelsFrame").getChild("slider"));
			}

			Vec2f scroller_pos = scroller.getAbsolutePosition();
			scrollerClickListener(scroller_pos.x, scroller_pos.y + 1, 1, scroller);
		}
	}
	else if (controls.isKeyJustPressed(KEY_KEY_D))
	{
		if (helpFrame.isEnabled)
		{
			Button@ scroller = cast<Button@>(helpFrame.getChild("helpFrameScrollerRight"));
			if (scroller is null) return;

			Vec2f scroller_pos = scroller.getAbsolutePosition();
			scrollerClickListener(scroller_pos.x, scroller_pos.y + 1, 1, scroller);
		}
		else if (levelsWrapper.isEnabled)
		{
			bool knight_levels = knightLevelsFrame.isEnabled;
			bool archer_levels = archerLevelsFrame.isEnabled;
			bool builder_levels = builderLevelsFrame.isEnabled;
	
			Button@ scroller;
			Rectangle@ slider;

			if (knight_levels)
			{
				@scroller = cast<Button@>(levelsWrapper.getChild("knightLevelsFrame").getChild("levelsFrameScrollerRight"));
				@slider = cast<Rectangle@>(levelsWrapper.getChild("knightLevelsFrame").getChild("slider"));
			}
			else if (archer_levels)
			{
				@scroller = cast<Button@>(levelsWrapper.getChild("archerLevelsFrame").getChild("levelsFrameScrollerRight"));
				@slider = cast<Rectangle@>(levelsWrapper.getChild("archerLevelsFrame").getChild("slider"));
			}
			else if (builder_levels)
			{
				@scroller = cast<Button@>(levelsWrapper.getChild("builderLevelsFrame").getChild("levelsFrameScrollerRight"));
				@slider = cast<Rectangle@>(levelsWrapper.getChild("builderLevelsFrame").getChild("slider"));
			}

			Vec2f scroller_pos = scroller.getAbsolutePosition();
			scrollerClickListener(scroller_pos.x, scroller_pos.y + 1, 1, scroller);
		}
	}
}

void InitializeGUI(CRules@ this)
{
	ConfigFile cfg;
    if (cfg.loadFile("../Cache/NoahsParkour.cfg"))
    {
        print("Loaded main config");
    }

	// main window (hidden by default)
    Vec2f screen_size = getDriver().getScreenDimensions();
    Vec2f menuPosHidden = getMenuPosHidden();

	@menuWindow = @Window(menuPosHidden, menuSize, 0, "Menu");
	menuWindow.name = "Menu";
	menuWindow.isEnabled = true;
	menuWindow.nodraw = false;
	menuWindow.setLevel(ContainerLevel::WINDOW);

	// default page frame
	Vec2f framePos = Vec2f(0, 50);
	Vec2f frameSize = Vec2f(menuSize.x - framePos.x, menuSize.y - framePos.y);

	// button positions
	Vec2f button_size = Vec2f(menuSize.x / 5, 30);
	Vec2f infoButtonPos = Vec2f(0, 0);
	Vec2f levelsButtonPos = Vec2f(button_size.x * 2, 0);
	Vec2f helpButtonPos = Vec2f(button_size.x, 0);
	Vec2f settingsButtonPos = Vec2f(button_size.x * 3, 0);
	Vec2f chessInfoButtonPos = Vec2f(button_size.x * 4, 0);

	@mainFrame = @Rectangle(framePos, frameSize, SColor(0, 0, 0, 0));
	mainFrame.name = "mainFrame";
	mainFrame.setLevel(ContainerLevel::PAGE_FRAME);
	mainFrame.isEnabled = false;
	menuWindow.addChild(mainFrame);

	Label@ title = @Label(Vec2f(mainFrame.size.x / 2, 4), Vec2f(frameSize.x - 12, 16), "", SColor(255, 0, 0, 0), true, "Terminus_18");
	title.name = "title";
	mainFrame.addChild(title);

	Label@ subtitle = @Label(Vec2f(8, 26), Vec2f(frameSize.x - 12, 16), "", SColor(255, 0, 0, 0), false, "Terminus_14");
	subtitle.name = "subtitle";
	mainFrame.addChild(subtitle);

	// switchers
	Button@ switchButton = @Button(Vec2f(menuSize.x, -30), Vec2f(30, 30), "", SColor(255, 200, 50, 50));
	switchButton.name = "switchButton";
	switchButton.addClickListener(menuSwitchListener);
	menuWindow.addChild(switchButton);
	
	Icon@ switchButtonIcon = @Icon("MiniIcons.png", Vec2f(-1.5f, -1.5f), Vec2f(16, 16), 24, 1.0f, false);
	switchButtonIcon.name = "switchButtonIcon";
	switchButton.addChild(switchButtonIcon);

	// info frame
	Button@ infoButton = @Button(infoButtonPos, button_size, "Info", SColor(255, 255, 255, 255), "Sakana_16");
	infoButton.addClickListener(pageClickListener);
	infoButton.name = "infoButton";
	infoButton.setLevel(ContainerLevel::PAGE_FRAME);
	infoButton.rectColor = SColor(255, 185, 55, 255);
	menuWindow.addChild(infoButton);

	@infoFrame = @Rectangle(mainFrame.localPosition, mainFrame.size, mainFrame.color);
	infoFrame.name = "infoFrame";
	infoFrame.isEnabled = true;
	menuWindow.addChild(infoFrame);

	Label@ infoTitle = @Label(title.localPosition, title.size, "", SColor(255, 0, 0, 0), true, title.font);
	infoTitle.name = "title";
	infoTitle.setText(infoTitle.textWrap("Useful information!", title.font));
	infoFrame.addChild(infoTitle);

	Label@ infoSubtitle = @Label(subtitle.localPosition, subtitle.size, "", SColor(255, 0, 0, 0), false, subtitle.font);
	infoSubtitle.name = "subtitle";
	infoSubtitle.setText(infoSubtitle.textWrap("CONTROLS - check game settings for binding names\n\n[Build Modifier] or  [SHIFT]        - Teleport\n[Mark Player]    or  [R]            - Teleport to Anchor\n[Build Modifier] +   [Mark Player]  - Replace Anchor\n[Left Control]                      - Show pathline\n\nCHAT COMMANDS: !next (!n), !prev (!p), !restart (!r), !level [id] [class]\n\n\n* Open the Levels section to create a room, white square will highlight it. You can't create one if all slots are occupied\n\nChat \n\n* Load a level into your room to start\n\n* Tiles and background tiles have different properties, for example, a knight won't be able to slide or slash while inside any background\n\n* Navigate through the menu for more info\n\n* Each of the official levels is possible to complete\n\nSome levels, though, require you to know theory and the moveset\n\n* Watch particular videos in \"Help\" section if you are stuck", subtitle.font));
	infoFrame.addChild(infoSubtitle);

	Vec2f scrollerLeftPos = Vec2f(10, 25);
	Vec2f scrollerLeftSize = Vec2f(25, mainFrame.size.y - 40);
	Vec2f scrollerRightPos = Vec2f(mainFrame.size.x - 35, 25);
	Vec2f scrollerRightSize = Vec2f(25, mainFrame.size.y - 40);

	// help frame
	Button@ helpButton = @Button(helpButtonPos, button_size, "Help", SColor(255, 255, 255, 255), "Sakana_16");
	helpButton.addClickListener(pageClickListener);
	helpButton.name = "helpButton";
	helpButton.setLevel(ContainerLevel::PAGE_FRAME);
	helpButton.rectColor = SColor(255, 245, 25, 185);
	menuWindow.addChild(helpButton);

	@helpFrame = @Rectangle(mainFrame.localPosition, mainFrame.size, mainFrame.color);
	helpFrame.name = "helpFrame";
	helpFrame.isEnabled = false;
	menuWindow.addChild(helpFrame);

	Label@ helpTitle = @Label(title.localPosition, title.size, "", SColor(255, 0, 0, 0), true, title.font);
	helpTitle.name = "title";
	helpTitle.setText(helpTitle.textWrap("(WIP) Hover on the videos to watch them (A/D) [01]", title.font));
	helpFrame.addChild(helpTitle);

	// slider and scrollers
	Rectangle@ helpFrameContentSlider = @Rectangle(mainFrame.localPosition + Vec2f(10, 32), mainFrame.size - Vec2f(20, 62), SColor(0, 0, 0, 0));
	helpFrameContentSlider.name = "slider";
	helpFrameContentSlider._customData = -1; // sign for init
	helpFrame.addChild(helpFrameContentSlider);

	Button@ helpFrameScrollerLeft = @Button(scrollerLeftPos, scrollerLeftSize, "<", SColor(255, 255, 255, 255), "Terminus_18");
	helpFrameScrollerLeft.name = "helpFrameScrollerLeft";
	helpFrameScrollerLeft.rectColor = SColor(255, 245, 25, 185);
	
	helpFrameScrollerLeft._customData = -1;
	helpFrame.addChild(helpFrameScrollerLeft);
	helpFrameScrollerLeft.addClickListener(scrollerClickListener);

	Button@ helpFrameScrollerRight = @Button(scrollerRightPos, scrollerRightSize, ">", SColor(255, 255, 255, 255), "Terminus_18");
	helpFrameScrollerRight.name = "helpFrameScrollerRight";
	helpFrameScrollerRight.rectColor = SColor(255, 245, 25, 185);
	helpFrameScrollerRight.addClickListener(scrollerClickListener);
	helpFrameScrollerRight._customData = 1;
	helpFrame.addChild(helpFrameScrollerRight);

	// levels frame
	Button@ levelsButton = @Button(levelsButtonPos, button_size, "Levels", SColor(255, 255, 255, 255), "Sakana_16");
	levelsButton.addClickListener(pageClickListener);
	levelsButton.name = "levelsButton";
	levelsButton.setLevel(ContainerLevel::PAGE_FRAME);
	levelsButton.rectColor = SColor(255, 255, 25, 55);
	menuWindow.addChild(levelsButton);

	@levelsFrame = @Rectangle(mainFrame.localPosition, mainFrame.size, mainFrame.color);
	levelsFrame.name = "levelsFrame";
	levelsFrame.isEnabled = false;
	menuWindow.addChild(levelsFrame);

	Vec2f create_room_size = Vec2f(menuSize) * 0.75f;
	Vec2f create_room_pos = Vec2f((levelsFrame.size.x - create_room_size.x) / 2 - 0, (levelsFrame.size.y - create_room_size.y) / 2 - 16);
	Button@ createRoomButton = @Button(create_room_pos, create_room_size, "Create a room", SColor(255, 255, 255, 255), "Sakana_18");
	createRoomButton.name = "createRoomButton";
	createRoomButton.addClickListener(createRoomClickListener);
	createRoomButton.rectColor = SColor(255, 255, 25, 25);
	levelsFrame.addChild(createRoomButton);

	Label@ levelsTitle = @Label(title.localPosition, title.size, "", SColor(255, 0, 0, 0), true, title.font);
	levelsTitle.name = "title";
	levelsTitle.setText(levelsTitle.textWrap("", title.font)); // not used, hidden under the tab buttons
	levelsFrame.addChild(levelsTitle);

	// LEVELS
	u8 buttons_count = 4;
	Vec2f levelsButtonSize = Vec2f(menuSize.x / buttons_count - 30, 30);
	Vec2f starting_pos = Vec2f((menuSize.x - levelsButtonSize.x * buttons_count) / 2, -10);

	Vec2f knightButtonPos = Vec2f(starting_pos.x, starting_pos.y);
	Vec2f archerButtonPos = knightButtonPos + Vec2f(levelsButtonSize.x, 0);
	Vec2f builderButtonPos = archerButtonPos + Vec2f(levelsButtonSize.x, 0);
	Vec2f customButtonPos = builderButtonPos + Vec2f(levelsButtonSize.x, 0);

	Rectangle@ levelsWrapper = @Rectangle(Vec2f_zero, mainFrame.size, mainFrame.color);
	levelsWrapper.name = "levelsWrapper";
	levelsWrapper.isEnabled = false; // player has to press the create room button first
	levelsFrame.addChild(levelsWrapper);

	// KNIGHT
	Button@ knightLevelsButton = @Button(knightButtonPos, levelsButtonSize, "Knight", SColor(255, 255, 255, 255), "Sakana_14");
	knightLevelsButton.addClickListener(levelsCategoryClickListener);
	knightLevelsButton.name = "knightLevelsButton";
	knightLevelsButton.rectColor = SColor(255, 255, 25, 55);
	levelsWrapper.addChild(knightLevelsButton);

	// knight levels frame
	@knightLevelsFrame = @Rectangle(Vec2f_zero, mainFrame.size, mainFrame.color);
	knightLevelsFrame.name = "knightLevelsFrame";
	knightLevelsFrame.isEnabled = true; // default visible for knight levels
	levelsWrapper.addChild(knightLevelsFrame);

	// slider and scrollers for knight levels
	Rectangle@ knightLevelsFrameContentSlider = @Rectangle(Vec2f_zero, mainFrame.size - Vec2f(20, 62), SColor(0, 0, 0, 0));
	knightLevelsFrameContentSlider.name = "slider";
	knightLevelsFrameContentSlider._customData = -1;
	knightLevelsFrame.addChild(knightLevelsFrameContentSlider);

	Button@ knightLevelsFrameScrollerLeft = @Button(scrollerLeftPos, scrollerLeftSize, "<", SColor(255, 255, 255, 255), "Terminus_18");
	knightLevelsFrameScrollerLeft.name = "levelsFrameScrollerLeft";
	knightLevelsFrameScrollerLeft.rectColor = SColor(255, 255, 25, 55);
	knightLevelsFrameScrollerLeft.addClickListener(scrollerClickListener);
	knightLevelsFrameScrollerLeft._customData = -1;
	knightLevelsFrame.addChild(knightLevelsFrameScrollerLeft);

	Button@ knightLevelsFrameScrollerRight = @Button(scrollerRightPos, scrollerRightSize, ">", SColor(255, 255, 255, 255), "Terminus_18");
	knightLevelsFrameScrollerRight.name = "levelsFrameScrollerRight";
	knightLevelsFrameScrollerRight.rectColor = SColor(255, 255, 25, 55);
	knightLevelsFrameScrollerRight.addClickListener(scrollerClickListener);
	knightLevelsFrameScrollerRight._customData = 1;
	knightLevelsFrame.addChild(knightLevelsFrameScrollerRight);

	// ARCHER
	Button@ archerLevelsButton = @Button(archerButtonPos, levelsButtonSize, "Archer", SColor(255, 255, 255, 255), "Sakana_14");
	archerLevelsButton.addClickListener(levelsCategoryClickListener);
	archerLevelsButton.name = "archerLevelsButton";
	archerLevelsButton.rectColor = SColor(255, 155, 25, 55);
	levelsWrapper.addChild(archerLevelsButton);

	// archer levels frame
	@archerLevelsFrame = @Rectangle(Vec2f_zero, mainFrame.size, mainFrame.color);
	archerLevelsFrame.name = "archerLevelsFrame";
	archerLevelsFrame.isEnabled = false;
	levelsWrapper.addChild(archerLevelsFrame);

	// slider and scrollers for archer levels
	Rectangle@ archerLevelsFrameContentSlider = @Rectangle(Vec2f_zero, mainFrame.size - Vec2f(20, 62), SColor(0, 0, 0, 0));
	archerLevelsFrameContentSlider.name = "slider";
	archerLevelsFrameContentSlider._customData = 0;
	archerLevelsFrame.addChild(archerLevelsFrameContentSlider);

	Button@ archerLevelsFrameScrollerLeft = @Button(scrollerLeftPos, scrollerLeftSize, "<", SColor(255, 255, 255, 255), "Terminus_18");
	archerLevelsFrameScrollerLeft.name = "levelsFrameScrollerLeft";
	archerLevelsFrameScrollerLeft.rectColor = SColor(255, 255, 25, 55);
	archerLevelsFrameScrollerLeft.addClickListener(scrollerClickListener);
	archerLevelsFrameScrollerLeft._customData = -1;
	archerLevelsFrame.addChild(archerLevelsFrameScrollerLeft);

	Button@ archerLevelsFrameScrollerRight = @Button(scrollerRightPos, scrollerRightSize, ">", SColor(255, 255, 255, 255), "Terminus_18");
	archerLevelsFrameScrollerRight.name = "levelsFrameScrollerRight";
	archerLevelsFrameScrollerRight.rectColor = SColor(255, 255, 25, 55);
	archerLevelsFrameScrollerRight.addClickListener(scrollerClickListener);
	archerLevelsFrameScrollerRight._customData = 1;
	archerLevelsFrame.addChild(archerLevelsFrameScrollerRight);

	// BUILDER
	Button@ builderLevelsButton = @Button(builderButtonPos, levelsButtonSize, "Builder", SColor(255, 255, 255, 255), "Sakana_14");
	builderLevelsButton.addClickListener(levelsCategoryClickListener);
	builderLevelsButton.name = "builderLevelsButton";
	builderLevelsButton.rectColor = SColor(255, 155, 25, 55);
	levelsWrapper.addChild(builderLevelsButton);

	// builder levels frame
	@builderLevelsFrame = @Rectangle(Vec2f_zero, mainFrame.size, mainFrame.color);
	builderLevelsFrame.name = "builderLevelsFrame";
	builderLevelsFrame.isEnabled = false;
	levelsWrapper.addChild(builderLevelsFrame);

	// slider and scrollers for builder levels
	Rectangle@ builderLevelsFrameContentSlider = @Rectangle(Vec2f_zero, mainFrame.size - Vec2f(20, 62), SColor(0, 0, 0, 0));
	builderLevelsFrameContentSlider.name = "slider";
	builderLevelsFrameContentSlider._customData = 0;
	builderLevelsFrame.addChild(builderLevelsFrameContentSlider);

	Button@ builderLevelsFrameScrollerLeft = @Button(scrollerLeftPos, scrollerLeftSize, "<", SColor(255, 255, 255, 255), "Terminus_18");
	builderLevelsFrameScrollerLeft.name = "levelsFrameScrollerLeft";
	builderLevelsFrameScrollerLeft.rectColor = SColor(255, 255, 25, 55);
	builderLevelsFrameScrollerLeft.addClickListener(scrollerClickListener);
	builderLevelsFrameScrollerLeft._customData = -1;
	builderLevelsFrame.addChild(builderLevelsFrameScrollerLeft);

	Button@ builderLevelsFrameScrollerRight = @Button(scrollerRightPos, scrollerRightSize, ">", SColor(255, 255, 255, 255), "Terminus_18");
	builderLevelsFrameScrollerRight.name = "levelsFrameScrollerRight";
	builderLevelsFrameScrollerRight.rectColor = SColor(255, 255, 25, 55);
	builderLevelsFrameScrollerRight.addClickListener(scrollerClickListener);
	builderLevelsFrameScrollerRight._customData = 1;
	builderLevelsFrame.addChild(builderLevelsFrameScrollerRight);

	// CUSTOM LEVELS (and editor button)
	Button@ customLevelsButton = @Button(customButtonPos, levelsButtonSize, "Custom", SColor(255, 255, 255, 255), "Sakana_14");
	customLevelsButton.addClickListener(levelsCategoryClickListener);
	customLevelsButton.name = "customLevelsButton";
	customLevelsButton.rectColor = SColor(255, 155, 25, 55);
	levelsWrapper.addChild(customLevelsButton);

	// custom levels frame
	@customLevelsFrame = @Rectangle(Vec2f_zero, mainFrame.size, mainFrame.color);
	customLevelsFrame.name = "customLevelsFrame";
	customLevelsFrame.isEnabled = false;
	levelsWrapper.addChild(customLevelsFrame);

	// editor button
	Vec2f editor_size = Vec2f(150, 30);
	Button@ openEditorButton = @Button(Vec2f(customLevelsFrame.size.x / 2 - editor_size.x / 2, customLevelsFrame.size.y - 40), editor_size, "Editor (WIP)", SColor(255, 255, 255, 255), "Sakana_14");
	openEditorButton.addClickListener(openEditorListener);
	openEditorButton.name = "openEditorButton";
	openEditorButton.rectColor = SColor(255, 255, 25, 55);
	customLevelsFrame.addChild(openEditorButton);
	
	// settings frame
	Button@ settingsButton = @Button(settingsButtonPos, button_size, "Settings", SColor(255, 255, 255, 255), "Sakana_16");
	settingsButton.addClickListener(pageClickListener);
	settingsButton.name = "settingsButton";
	settingsButton.setLevel(ContainerLevel::PAGE_FRAME);
	settingsButton.rectColor = SColor(255, 255, 115, 55);
	menuWindow.addChild(settingsButton);

	@settingsFrame = @Rectangle(mainFrame.localPosition, mainFrame.size, mainFrame.color);
	settingsFrame.name = "settingsFrame";
	settingsFrame.isEnabled = false;
	menuWindow.addChild(settingsFrame);

	// load the settings menu
	AddSettings(this, settingsFrame);

	// chess info frame
	Button@ chessInfoButton = @Button(chessInfoButtonPos, button_size, "Chess", SColor(255, 255, 255, 255), "Sakana_16");
	chessInfoButton.addClickListener(pageClickListener);
	chessInfoButton.name = "chessInfoButton";
	chessInfoButton.setLevel(ContainerLevel::PAGE_FRAME);
	chessInfoButton.rectColor = SColor(255, 175, 85, 0);
	menuWindow.addChild(chessInfoButton);

	@chessInfoFrame = @Rectangle(mainFrame.localPosition, mainFrame.size, mainFrame.color);
	chessInfoFrame.name = "chessInfoFrame";
	chessInfoFrame.isEnabled = false;
	menuWindow.addChild(chessInfoFrame);

	Vec2f play_size = Vec2f(150, 30);
	Button@ loadChessButton = @Button(Vec2f(chessInfoFrame.size.x / 2 - play_size.x / 2, chessInfoFrame.size.y - 40), play_size, "Play", SColor(255, 255, 255, 255), "Sakana_14");
	loadChessButton.addClickListener(loadChessListener);
	loadChessButton.name = "loadChessButton";
	loadChessButton.rectColor = SColor(255, 175, 85, 0);
	chessInfoFrame.addChild(loadChessButton);

	Label@ chessInfoTitle = @Label(title.localPosition, title.size, "", SColor(255, 0, 0, 0), true, title.font);
	chessInfoTitle.name = "title";
	chessInfoTitle.setText(chessInfoTitle.textWrap("Chess?", title.font));
	chessInfoFrame.addChild(chessInfoTitle);

	Label@ chessInfoSubtitle = @Label(subtitle.localPosition, subtitle.size, "", SColor(255, 0, 0, 0), false, subtitle.font);
	chessInfoSubtitle.name = "subtitle";
	chessInfoSubtitle.setText(chessInfoSubtitle.textWrap("\"Chess\" is a special level where players can hang out and play chess together. Please, note that players with high ping might encounter some minor control artifacts.\n\nWASD - Move, LMB - Select/Place, RMB - Deselect, END key - end the match.", subtitle.font));
	chessInfoFrame.addChild(chessInfoSubtitle);

	// switcher pointer
	Rectangle@ switcherPointer = @Rectangle(Vec2f(0, 0), Vec2f(8, 3), SColor(255, 0, 0, 0));
	switcherPointer.name = "switcherPointer";
	switcherPointer.isEnabled = false;
	menuWindow.addChild(switcherPointer);

	// decorator line
	// Rectangle@ decoratorLine = @Rectangle(Vec2f(8, 40), Vec2f(menuSize.x - 16, 1), SColor(255, 0, 0, 0));
	// decoratorLine.name = "decoratorLine";
	// menuWindow.addChild(decoratorLine);

	// set gui to active state
	this.set_bool("GUI initialized", true);
	print("GUI has been initialized");
}

void AddSettings(CRules@ this, Rectangle@ settingsFrame)
{
	Vec2f buttonSize = Vec2f(settingsFrame.size.x / 2 - 25, 30);

	f32 gap = 5;
	f32 prevHeight = 0;

	// all settings are on by default
	// next level swap toggle
	bool next_level_swap = this.get_bool("next_level_swap");
	Button@ nextLevelSwapToggle = @Button(Vec2f(10, prevHeight), buttonSize, "Auto next level: " + (next_level_swap ? "YES" : "NO"), SColor(255, 255, 255, 255));
	nextLevelSwapToggle.name = "nextLevelSwapToggle";
	nextLevelSwapToggle.selfLabeled = true;
	nextLevelSwapToggle.rectColor = SColor(255, 255, 115, 55);
	nextLevelSwapToggle.toggled = next_level_swap;
	nextLevelSwapToggle.addClickListener(toggleListener);
	settingsFrame.addChild(nextLevelSwapToggle);
	prevHeight += buttonSize.y + gap;
	
	// path line toggle
	bool path_line = this.get_bool("enable_pathline");
	Button@ disablePathLineToggle = @Button(Vec2f(10, prevHeight), buttonSize, "Enable path line: " + (path_line ? "YES" : "NO"), SColor(255, 255, 255, 255));
	disablePathLineToggle.name = "disablePathLineToggle";
	disablePathLineToggle.selfLabeled = true;
	disablePathLineToggle.rectColor = SColor(255, 255, 115, 55);
	disablePathLineToggle.toggled = path_line;
	disablePathLineToggle.addClickListener(toggleListener);
	settingsFrame.addChild(disablePathLineToggle);
	prevHeight += buttonSize.y + gap;

	// disable movement while menu is open
	bool disable_movement = this.get_bool("disable_movement");
	Button@ disableMovementToggle = @Button(Vec2f(10, prevHeight), buttonSize, "Menu disables movement: " + (disable_movement ? "YES" : "NO"), SColor(255, 255, 255, 255));
	disableMovementToggle.name = "disableMovementToggle";
	disableMovementToggle.selfLabeled = true;
	disableMovementToggle.rectColor = SColor(255, 255, 115, 55);
	disableMovementToggle.toggled = disable_movement;
	disableMovementToggle.addClickListener(toggleListener);
	settingsFrame.addChild(disableMovementToggle);
	prevHeight += buttonSize.y + gap;

	// can open menu while moving
	bool allow_moving_menu = this.get_bool("allow_moving_menu");
	Button@ allowMovingMenuToggle = @Button(Vec2f(10, prevHeight), buttonSize, "Require stop for menu: " + (allow_moving_menu ? "YES" : "NO"), SColor(255, 255, 255, 255));
	allowMovingMenuToggle.name = "allowMovingMenuToggle";
	allowMovingMenuToggle.selfLabeled = true;
	allowMovingMenuToggle.rectColor = SColor(255, 255, 115, 55);
	allowMovingMenuToggle.toggled = allow_moving_menu;
	allowMovingMenuToggle.addClickListener(toggleListener);
	settingsFrame.addChild(allowMovingMenuToggle);
	prevHeight += buttonSize.y + gap;

	// continuous teleport
	bool continuous_teleport = this.get_bool("continuous_teleport");
	Button@ continuousTeleportToggle = @Button(Vec2f(10, prevHeight), buttonSize, "Immediate teleport: " + (continuous_teleport ? "YES" : "NO"), SColor(255, 255, 255, 255));
	continuousTeleportToggle.name = "continuousTeleportToggle";
	continuousTeleportToggle.selfLabeled = true;
	continuousTeleportToggle.rectColor = SColor(255, 255, 115, 55);
	continuousTeleportToggle.toggled = continuous_teleport;
	continuousTeleportToggle.addClickListener(toggleListener);
	settingsFrame.addChild(continuousTeleportToggle);
	prevHeight += buttonSize.y + gap;

	// close menu on room select
	bool close_on_room_select = this.get_bool("close_on_room_select");
	Button@ closeOnRoomSelectToggle = @Button(Vec2f(10, prevHeight), buttonSize, "Close menu on select: " + (close_on_room_select ? "YES" : "NO"), SColor(255, 255, 255, 255));
	closeOnRoomSelectToggle.name = "closeOnRoomSelectToggle";
	closeOnRoomSelectToggle.selfLabeled = true;
	closeOnRoomSelectToggle.rectColor = SColor(255, 255, 115, 55);
	closeOnRoomSelectToggle.toggled = close_on_room_select;
	closeOnRoomSelectToggle.addClickListener(toggleListener);
	settingsFrame.addChild(closeOnRoomSelectToggle);
	prevHeight += buttonSize.y + gap;
}

void UpdateSettings(CRules@ this)
{
	// updates the buttons in GUI
	Button@ nextLevelSwapToggle = cast<Button@>(settingsFrame.getChild("nextLevelSwapToggle"));
	if (nextLevelSwapToggle !is null)
	{
		bool next_level_swap = nextLevelSwapToggle.toggled;
		this.set_bool("next_level_swap", next_level_swap);
		nextLevelSwapToggle.desc = "Auto next level: " + (next_level_swap ? "YES" : "NO");
	}

	Button@ disablePathLineToggle = cast<Button@>(settingsFrame.getChild("disablePathLineToggle"));
	if (disablePathLineToggle !is null)
	{
		bool path_line = disablePathLineToggle.toggled;
		this.set_bool("enable_pathline", path_line);
		disablePathLineToggle.desc = "Enable path line: " + (path_line ? "YES" : "NO");
	}

	Button@ disableMovementToggle = cast<Button@>(settingsFrame.getChild("disableMovementToggle"));
	if (disableMovementToggle !is null)
	{
		bool disable_movement = disableMovementToggle.toggled;
		this.set_bool("disable_movement", disable_movement);
		disableMovementToggle.desc = "Menu disables movement: " + (disable_movement ? "YES" : "NO");
	}

	Button@ allowMovingMenuToggle = cast<Button@>(settingsFrame.getChild("allowMovingMenuToggle"));
	if (allowMovingMenuToggle !is null)
	{
		bool allow_moving_menu = allowMovingMenuToggle.toggled;
		this.set_bool("allow_moving_menu", allow_moving_menu);
		allowMovingMenuToggle.desc = "Require stop for menu: " + (allow_moving_menu ? "YES" : "NO");
	}

	Button@ continuousTeleportToggle = cast<Button@>(settingsFrame.getChild("continuousTeleportToggle"));
	if (continuousTeleportToggle !is null)
	{
		bool continuous_teleport = continuousTeleportToggle.toggled;
		this.set_bool("continuous_teleport", continuous_teleport);
		continuousTeleportToggle.desc = "Immediate teleport: " + (continuous_teleport ? "YES" : "NO");
	}

	Button@ closeOnRoomSelectToggle = cast<Button@>(settingsFrame.getChild("closeOnRoomSelectToggle"));
	if (closeOnRoomSelectToggle !is null)
	{
		bool close_on_room_select = closeOnRoomSelectToggle.toggled;
		this.set_bool("close_on_room_select", close_on_room_select);
		closeOnRoomSelectToggle.desc = "Close menu on select: " + (close_on_room_select ? "YES" : "NO");
	}
}

void setCachedStates(CRules@ this)
{
	Button@ nextLevelSwapToggle = cast<Button@>(settingsFrame.getChild("nextLevelSwapToggle"));
	if (nextLevelSwapToggle !is null)
	{
		bool next_level_swap = nextLevelSwapToggle.getBool("next_level_swap", "parkour_settings");
		this.set_bool("next_level_swap", next_level_swap);
		nextLevelSwapToggle.toggled = next_level_swap;
	}

	Button@ disablePathLineToggle = cast<Button@>(settingsFrame.getChild("disablePathLineToggle"));
	if (disablePathLineToggle !is null)
	{
		bool path_line = disablePathLineToggle.getBool("enable_pathline", "parkour_settings");
		this.set_bool("enable_pathline", path_line);
		disablePathLineToggle.toggled = path_line;
	}

	Button@ disableMovementToggle = cast<Button@>(settingsFrame.getChild("disableMovementToggle"));
	if (disableMovementToggle !is null)
	{
		bool disable_movement = disableMovementToggle.getBool("disable_movement", "parkour_settings");
		this.set_bool("disable_movement", disable_movement);
		disableMovementToggle.toggled = disable_movement;
	}

	Button@ allowMovingMenuToggle = cast<Button@>(settingsFrame.getChild("allowMovingMenuToggle"));
	if (allowMovingMenuToggle !is null)
	{
		bool allow_moving_menu = allowMovingMenuToggle.getBool("allow_moving_menu", "parkour_settings");
		this.set_bool("allow_moving_menu", allow_moving_menu);
		allowMovingMenuToggle.toggled = allow_moving_menu;
	}

	Button@ continuousTeleportToggle = cast<Button@>(settingsFrame.getChild("continuousTeleportToggle"));
	if (continuousTeleportToggle !is null)
	{
		bool continuous_teleport = continuousTeleportToggle.getBool("continuous_teleport", "parkour_settings");
		this.set_bool("continuous_teleport", continuous_teleport);
		continuousTeleportToggle.toggled = continuous_teleport;
	}

	UpdateSettings(this);
}

void updateOptionSliderValues()
{
    /*
    float item_distance = 0.3f;//used for changing the value and storing the final value
    for(uint i = 0; i < itemDistance.value; i++)
    {
        item_distance += 0.1f;
    }
    item_distance = WheelMenu::default_item_distance * item_distance;
    */
}

void onRender(CRules@ this)
{
	CPlayer@ player = getLocalPlayer();
	if (player is null)
		return;

	Driver@ driver = getDriver();
	if (driver is null) return;

	CControls@ controls = getControls();
	if (controls is null) return;

	Vec2f screen_size = driver.getScreenDimensions();
	if (this.exists("warn_menu_movement"))
	{
		Vec2f cursor_pos = controls.getInterpMouseScreenPos();
		u32 warn_time = this.get_u32("warn_menu_movement");
		u32 diff = getGameTime() - warn_time;
		
		f32 fade = 0.0f;
		string text = "Stop to open the menu";

		u32 gametime = getGameTime();
		if (diff < 8)
		{
			fade = Maths::Clamp(f32(diff) / 8.0f, 0.0f, 1.0f);
		}
		else
		{
			if (diff > warn_menu_movement_time)
			{
				fade = Maths::Clamp(1.0f - (f32(diff - warn_menu_movement_time) / 8.0f), 0.0f, 1.0f);
			}
			else
			{
				fade = 1.0f;
			}
		}

		f32 mouse_y_factor = Maths::Clamp((cursor_pos.y - 720) / (screen_size.y / 2) * 2, 0.0f, 1.0f);
		fade *= mouse_y_factor;
		
		GUI::SetFont("menu");
		GUI::DrawTextCentered(text, Vec2f(cursor_pos.x, cursor_pos.y - 52), SColor(fade * 255, 255, 255, 255));
	}

	if (menuWindow is null) return;
	if (menuWindow._customData == 0) menuWindow.draw();

	f32 tick = 2;

	#ifdef STAGING
	tick = Maths::Max(2, f32(v_fpslimit) / 60);
	#endif

	f32 mod = Maths::Clamp(0.0f, 1.0f, active_time / slideOffset * tick);
	
	Vec2f posHidden = getMenuPosHidden();
	Vec2f posShown = getMenuPosShown();

	active_time = showMenu ? active_time + 1.0f / tick : 0;
	Vec2f new_position = Vec2f_lerp(menuWindow.localPosition, showMenu ? posShown : posHidden, 0.35f);
	if (menuWindow.localPosition != new_position)
	{
		UpdateHelpFrameVideos(cast<Rectangle@>(helpFrame.getChild("slider")), default_grid);
	}
	menuWindow.setPosition(new_position);

	Button@ switcher = cast<Button@>(menuWindow.getChild("switchButton"));
	if (switcher !is null)
	{
		switcher.setPosition(Vec2f_lerp(switcher.localPosition, switcher.initialPosition + Vec2f(0, showMenu ? 30 : 0), 0.35f));
	}

	RenderHovering(this);
	RenderShownVideos(active_help_videos, active_help_video_positions, showMenu);

	bool initialized = this.get_bool("GUI initialized");
	if (!initialized) return;

    // draw render inherits here
}

void RenderHovering(CRules@ this)
{
	if (hovering_filename == "") return;
	Vec2f sz = getDriver().getScreenDimensions();

	f32 scale = 3.0f;
	Vec2f center = Vec2f(sz.x / 2, sz.y / 2);
	//bg
	GUI::DrawPane(center - hovering_size * scale - Vec2f(4,4), center + hovering_size * scale + Vec2f(4,4), SColor(255, 155, 25, 55));
	GUI::DrawIcon(hovering_filename, 0, hovering_size, center - hovering_size * scale, scale, SColor(255, 255, 255, 255));
}

Vec2f getMenuPosHidden()
{
	Vec2f screen_size = getDriver().getScreenDimensions();
	return Vec2f(screen_size.x / 2 - menuSize.x / 2 - 150, screen_size.y);
}

Vec2f getMenuPosShown()
{
	Vec2f screen_size = getDriver().getScreenDimensions();
	return Vec2f(screen_size.x / 2 - menuSize.x / 2 - 150, screen_size.y - menuSize.y - slideOffset);
}

void EnsureRoomOwned(CRules@ this)
{
	u8 room_id = this.get_u8("captured_room_id");
	if (room_id != 255)
	{
		// hide Create Room button and show levels
		Rectangle@ levelsWrapper = cast<Rectangle@>(levelsFrame.getChild("levelsWrapper"));
		if (levelsWrapper !is null && !levelsWrapper.isEnabled)
		{
			Button@ createRoomButton = cast<Button@>(levelsFrame.getChild("createRoomButton"));
			if (createRoomButton !is null)
			{
				createRoomButton.isEnabled = false;
			}

			levelsWrapper.isEnabled = true;
		}
	}
	else
	{
		// show Create Room button and hide levels
		Rectangle@ levelsWrapper = cast<Rectangle@>(levelsFrame.getChild("levelsWrapper"));
		if (levelsWrapper !is null && levelsWrapper.isEnabled)
		{
			Button@ createRoomButton = cast<Button@>(levelsFrame.getChild("createRoomButton"));
			if (createRoomButton !is null)
			{
				createRoomButton.isEnabled = true;
			}

			levelsWrapper.isEnabled = false;
		}
	}
}
