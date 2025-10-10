#define CLIENT_ONLY

#include "TeamColour.as";
#include "KGUI.as";
#include "Listeners.as";
#include "PseudoVideoPlayer.as";

const Vec2f menuSize = Vec2f(500, 400);
const f32 slideOffset = 100.0f; // extra height
const u32 warn_menu_movement_time = 30;
const Vec2f default_grid = Vec2f(3, 4);
const Vec2f default_grid_levels = Vec2f(3, 3);

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
	string k_path = "Rooms/Knight/";
	string k_prefix = "k_";

	u32 level_count = 0;
	Rectangle@ slider = cast<Rectangle@>(knightLevelsFrame.getChild("slider"));
	for (uint i = 0; i < 512; i++)
	{
		string path = CFileMatcher(k_path + k_prefix + i + ".png").getFirst();
		if (path != "")
		{
			CFileImage@ img = @CFileImage(path);
			if (img is null) continue;
			Vec2f img_size = Vec2f(img.getWidth(), img.getHeight());

			Rectangle@ level = @Rectangle(Vec2f(0, 0), img_size, SColor(0, 225, 179, 126));
			level.name = "k_" + i;
			level.addClickListener(loadLevelClickListener);
			level.addHoverStateListener(levelHoverListener);
			slider.addChild(level);

			Icon@ icon = @Icon(path, -img_size / 2, img_size, 0, 1.0f, false);
			icon.name = "icon";
			level.addChild(icon);

			Button@ text_pane = @Button(Vec2f_zero, Vec2f(40, 20), "", SColor(255, 0, 0, 0), "Terminus_12");
			text_pane.name = "text_pane";
			text_pane.rectColor = SColor(255, 255, 0, 0);
			level.addChild(text_pane);

			Vec2f pane_size = Vec2f(text_pane.size.x / 2 - 2, 8);
			Label@ text = @Label(pane_size, pane_size, "" + i, SColor(255, 255, 255, 255), true, "Terminus_12");
			text_pane.addChild(text);

			level_count++;
		}
		else
		{
			break;
		}
	}

	print("Loaded " + level_count + " knight levels");
	level_count = 0;
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
	bool initialized = this.get_bool("GUI initialized");
	if ((!initialized || isGUINull()))
	{
		LoadVideos(); // must be before InitializeGUI
        InitializeGUI(this);
		LoadLevels(); // must be after InitializeGUI

		updateOptionSliderValues();
    	setCachedStates(this);
	}

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
		else if (levelsFrame.isEnabled)
		{
			
			bool knight_levels = knightLevelsFrame.isEnabled;
			bool archer_levels = archerLevelsFrame.isEnabled;
			bool builder_levels = builderLevelsFrame.isEnabled;
	
			Button@ scroller;
			Rectangle@ slider;

			if (knight_levels)
			{
				@scroller = cast<Button@>(levelsFrame.getChild("knightLevelsFrame").getChild("levelsFrameScrollerLeft"));
				@slider = cast<Rectangle@>(levelsFrame.getChild("knightLevelsFrame").getChild("slider"));
			}
			else if (archer_levels)
			{
				@scroller = cast<Button@>(levelsFrame.getChild("archerLevelsFrame").getChild("levelsFrameScrollerLeft"));
				@slider = cast<Rectangle@>(levelsFrame.getChild("archerLevelsFrame").getChild("slider"));
			}
			else if (builder_levels)
			{
				@scroller = cast<Button@>(levelsFrame.getChild("builderLevelsFrame").getChild("levelsFrameScrollerLeft"));
				@slider = cast<Rectangle@>(levelsFrame.getChild("builderLevelsFrame").getChild("slider"));
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
		else if (levelsFrame.isEnabled)
		{
			bool knight_levels = knightLevelsFrame.isEnabled;
			bool archer_levels = archerLevelsFrame.isEnabled;
			bool builder_levels = builderLevelsFrame.isEnabled;
	
			Button@ scroller;
			Rectangle@ slider;

			if (knight_levels)
			{
				@scroller = cast<Button@>(levelsFrame.getChild("knightLevelsFrame").getChild("levelsFrameScrollerRight"));
				@slider = cast<Rectangle@>(levelsFrame.getChild("knightLevelsFrame").getChild("slider"));
			}
			else if (archer_levels)
			{
				@scroller = cast<Button@>(levelsFrame.getChild("archerLevelsFrame").getChild("levelsFrameScrollerRight"));
				@slider = cast<Rectangle@>(levelsFrame.getChild("archerLevelsFrame").getChild("slider"));
			}
			else if (builder_levels)
			{
				@scroller = cast<Button@>(levelsFrame.getChild("builderLevelsFrame").getChild("levelsFrameScrollerRight"));
				@slider = cast<Rectangle@>(levelsFrame.getChild("builderLevelsFrame").getChild("slider"));
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
	menuWindow.setLevel(ContainerLevel::WINDOW);

	// default page frame
	Vec2f framePos = Vec2f(0, 50);
	Vec2f frameSize = Vec2f(menuSize.x - framePos.x, menuSize.y - framePos.y);

	@mainFrame = @Rectangle(framePos, frameSize, SColor(0, 0, 0, 0));
	mainFrame.name = "mainFrame";
	mainFrame.setLevel(ContainerLevel::PAGE_FRAME);
	menuWindow.addChild(mainFrame);

	Label@ title = @Label(Vec2f(mainFrame.size.x / 2, 4), Vec2f(frameSize.x - 12, 16), "", SColor(255, 0, 0, 0), true, "Terminus_18");
	title.name = "title";
	title.setText(title.textWrap("Welcome to the Parkour Mod!", "Terminus_18"));
	mainFrame.addChild(title);

	Label@ subtitle = @Label(Vec2f(8, 26), Vec2f(frameSize.x - 12, 16), "", SColor(255, 0, 0, 0), false, "Terminus_14");
	subtitle.name = "subtitle";
	subtitle.setText(subtitle.textWrap("* Load a level into your room to start.\n\n* Write !create to make a room, it is located inside the white square.\n\n* You can create and load own levels! Write !editor, !save [name], or !load [name]. ((todo: path))\n\n* Navigate through the menu for more info.", "Terminus_14"));
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
	Button@ infoButton = @Button(Vec2f(menuSize.x - 500, 0), Vec2f(100, 30), "Info", SColor(255, 255, 255, 255), "Sakana_16");
	infoButton.addClickListener(pageClickListener);
	infoButton.name = "infoButton";
	infoButton.setLevel(ContainerLevel::PAGE_FRAME);
	infoButton.rectColor = SColor(255, 200, 55, 185);
	menuWindow.addChild(infoButton);

	@infoFrame = @Rectangle(mainFrame.localPosition, mainFrame.size, mainFrame.color);
	infoFrame.name = "infoFrame";
	infoFrame.isEnabled = false;
	menuWindow.addChild(infoFrame);

	Label@ infoTitle = @Label(title.localPosition, title.size, "", SColor(255, 0, 0, 0), true, title.font);
	infoTitle.name = "title";
	infoTitle.setText(infoTitle.textWrap("Useful information!", title.font));
	infoFrame.addChild(infoTitle);

	Label@ infoSubtitle = @Label(subtitle.localPosition, subtitle.size, "", SColor(255, 0, 0, 0), false, subtitle.font);
	infoSubtitle.name = "subtitle";
	infoSubtitle.setText(infoSubtitle.textWrap("* Each of the official levels is possible to complete.\n\nSome levels, though, require you to know theory and the moveset.\n\nEnable the path line in settings and watch particular videos in \"Help\" section if you are stuck.", subtitle.font));
	infoFrame.addChild(infoSubtitle);

	Vec2f scrollerLeftPos = Vec2f(10, 25);
	Vec2f scrollerLeftSize = Vec2f(25, mainFrame.size.y - 40);
	Vec2f scrollerRightPos = Vec2f(mainFrame.size.x - 35, 25);
	Vec2f scrollerRightSize = Vec2f(25, mainFrame.size.y - 40);

	// levels frame
	Button@ levelsButton = @Button(Vec2f(menuSize.x - 400, 0), Vec2f(100, 30), "Levels", SColor(255, 255, 255, 255), "Sakana_16");
	levelsButton.addClickListener(pageClickListener);
	levelsButton.name = "levelsButton";
	levelsButton.setLevel(ContainerLevel::PAGE_FRAME);
	levelsButton.rectColor = SColor(255, 255, 25, 55);
	menuWindow.addChild(levelsButton);

	@levelsFrame = @Rectangle(mainFrame.localPosition, mainFrame.size, mainFrame.color);
	levelsFrame.name = "levelsFrame";
	levelsFrame.isEnabled = false;
	menuWindow.addChild(levelsFrame);

	Label@ levelsTitle = @Label(title.localPosition, title.size, "", SColor(255, 0, 0, 0), true, title.font);
	levelsTitle.name = "title";
	levelsTitle.setText(levelsTitle.textWrap("", title.font)); // not used, hidden under the tab buttons
	levelsFrame.addChild(levelsTitle);

	// LEVELS
	Vec2f levelsButtonSize = Vec2f(menuSize.x / 3 - 30, 30);
	Vec2f starting_pos = Vec2f((menuSize.x - levelsButtonSize.x * 3) / 2, -10);

	Vec2f knightButtonPos = Vec2f(starting_pos.x, starting_pos.y);
	Vec2f archerButtonPos = knightButtonPos + Vec2f(levelsButtonSize.x, 0);
	Vec2f builderButtonPos = archerButtonPos + Vec2f(levelsButtonSize.x, 0);

	// KNIGHT
	Button@ knightLevelsButton = @Button(knightButtonPos, levelsButtonSize, "Knight", SColor(255, 255, 255, 255), "Sakana_14");
	knightLevelsButton.addClickListener(levelsClickListener);
	knightLevelsButton.name = "knightLevelsButton";
	knightLevelsButton.rectColor = SColor(255, 255, 25, 55);
	levelsFrame.addChild(knightLevelsButton);

	// knight levels frame
	@knightLevelsFrame = @Rectangle(Vec2f_zero, mainFrame.size, mainFrame.color);
	knightLevelsFrame.name = "knightLevelsFrame";
	knightLevelsFrame.isEnabled = true; // default visible for knight levels
	levelsFrame.addChild(knightLevelsFrame);

	// slider and scrollers for knight levels
	Rectangle@ knightLevelsFrameContentSlider = @Rectangle(mainFrame.localPosition + Vec2f(10, 32), mainFrame.size - Vec2f(20, 62), SColor(0, 0, 0, 0));
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
	archerLevelsButton.addClickListener(levelsClickListener);
	archerLevelsButton.name = "archerLevelsButton";
	archerLevelsButton.rectColor = SColor(255, 155, 25, 55);
	levelsFrame.addChild(archerLevelsButton);

	// archer levels frame
	@archerLevelsFrame = @Rectangle(Vec2f_zero, mainFrame.size, mainFrame.color);
	archerLevelsFrame.name = "archerLevelsFrame";
	archerLevelsFrame.isEnabled = false;
	levelsFrame.addChild(archerLevelsFrame);

	// slider and scrollers for archer levels
	Rectangle@ archerLevelsFrameContentSlider = @Rectangle(mainFrame.localPosition + Vec2f(10, 32), mainFrame.size - Vec2f(20, 62), SColor(0, 0, 0, 0));
	archerLevelsFrameContentSlider.name = "slider";
	archerLevelsFrameContentSlider._customData = -1;
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
	builderLevelsButton.addClickListener(levelsClickListener);
	builderLevelsButton.name = "builderLevelsButton";
	builderLevelsButton.rectColor = SColor(255, 155, 25, 55);
	levelsFrame.addChild(builderLevelsButton);

	// builder levels frame
	@builderLevelsFrame = @Rectangle(Vec2f_zero, mainFrame.size, mainFrame.color);
	builderLevelsFrame.name = "builderLevelsFrame";
	builderLevelsFrame.isEnabled = false;
	levelsFrame.addChild(builderLevelsFrame);

	// slider and scrollers for builder levels
	Rectangle@ builderLevelsFrameContentSlider = @Rectangle(mainFrame.localPosition + Vec2f(10, 32), mainFrame.size - Vec2f(20, 62), SColor(0, 0, 0, 0));
	builderLevelsFrameContentSlider.name = "slider";
	builderLevelsFrameContentSlider._customData = -1;
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

	// help frame
	Button@ helpButton = @Button(Vec2f(menuSize.x - 300, 0), Vec2f(100, 30), "Help", SColor(255, 255, 255, 255), "Sakana_16");
	helpButton.addClickListener(pageClickListener);
	helpButton.name = "helpButton";
	helpButton.setLevel(ContainerLevel::PAGE_FRAME);
	helpButton.rectColor = SColor(255, 65, 185, 85);
	menuWindow.addChild(helpButton);

	@helpFrame = @Rectangle(mainFrame.localPosition, mainFrame.size, mainFrame.color);
	helpFrame.name = "helpFrame";
	helpFrame.isEnabled = false;
	menuWindow.addChild(helpFrame);

	Label@ helpTitle = @Label(title.localPosition, title.size, "", SColor(255, 0, 0, 0), true, title.font);
	helpTitle.name = "title";
	helpTitle.setText(helpTitle.textWrap("Hover on the videos to watch them (A/D) [01]", title.font));
	helpFrame.addChild(helpTitle);

	// slider and scrollers
	Rectangle@ helpFrameContentSlider = @Rectangle(mainFrame.localPosition + Vec2f(10, 32), mainFrame.size - Vec2f(20, 62), SColor(0, 0, 0, 0));
	helpFrameContentSlider.name = "slider";
	helpFrameContentSlider._customData = -1; // sign for init
	helpFrame.addChild(helpFrameContentSlider);

	Button@ helpFrameScrollerLeft = @Button(scrollerLeftPos, scrollerLeftSize, "<", SColor(255, 255, 255, 255), "Terminus_18");
	helpFrameScrollerLeft.name = "helpFrameScrollerLeft";
	helpFrameScrollerLeft.rectColor = SColor(255, 65, 185, 85);
	
	helpFrameScrollerLeft._customData = -1;
	helpFrame.addChild(helpFrameScrollerLeft);
	helpFrameScrollerLeft.addClickListener(scrollerClickListener);

	Button@ helpFrameScrollerRight = @Button(scrollerRightPos, scrollerRightSize, ">", SColor(255, 255, 255, 255), "Terminus_18");
	helpFrameScrollerRight.name = "helpFrameScrollerRight";
	helpFrameScrollerRight.rectColor = SColor(255, 65, 185, 85);
	helpFrameScrollerRight.addClickListener(scrollerClickListener);
	helpFrameScrollerRight._customData = 1;
	helpFrame.addChild(helpFrameScrollerRight);

	// settings frame
	Button@ settingsButton = @Button(Vec2f(menuSize.x - 200, 0), Vec2f(100, 30), "Settings", SColor(255, 255, 255, 255), "Sakana_16");
	settingsButton.addClickListener(pageClickListener);
	settingsButton.name = "settingsButton";
	settingsButton.setLevel(ContainerLevel::PAGE_FRAME);
	settingsButton.rectColor = SColor(255, 55, 125, 185);
	menuWindow.addChild(settingsButton);

	@settingsFrame = @Rectangle(mainFrame.localPosition, mainFrame.size, mainFrame.color);
	settingsFrame.name = "settingsFrame";
	settingsFrame.isEnabled = false;
	menuWindow.addChild(settingsFrame);

	// load the settings menu
	AddSettings(this, settingsFrame);

	// chess info frame
	Button@ chessInfoButton = @Button(Vec2f(menuSize.x - 100, 0), Vec2f(100, 30), "Chess", SColor(255, 255, 255, 255), "Sakana_16");
	chessInfoButton.addClickListener(pageClickListener);
	chessInfoButton.name = "chessInfoButton";
	chessInfoButton.setLevel(ContainerLevel::PAGE_FRAME);
	chessInfoButton.rectColor = SColor(255, 175, 85, 0);
	menuWindow.addChild(chessInfoButton);

	@chessInfoFrame = @Rectangle(mainFrame.localPosition, mainFrame.size, mainFrame.color);
	chessInfoFrame.name = "chessInfoFrame";
	chessInfoFrame.isEnabled = false;
	menuWindow.addChild(chessInfoFrame);

	Button@ loadChessButton = @Button(Vec2f(chessInfoFrame.size.x / 2 - 50, chessInfoFrame.size.y - 40), Vec2f(75, 30), "Play", SColor(255, 255, 255, 255), "Sakana_14");
	loadChessButton.addClickListener(loadChessListener);
	loadChessButton.name = "loadChessButton";
	loadChessButton.rectColor = SColor(255, 55, 125, 185);
	chessInfoFrame.addChild(loadChessButton);

	Label@ chessInfoTitle = @Label(title.localPosition, title.size, "", SColor(255, 0, 0, 0), true, title.font);
	chessInfoTitle.name = "title";
	chessInfoTitle.setText(chessInfoTitle.textWrap("Chess?", title.font));
	chessInfoFrame.addChild(chessInfoTitle);

	Label@ chessInfoSubtitle = @Label(subtitle.localPosition, subtitle.size, "", SColor(255, 0, 0, 0), false, subtitle.font);
	chessInfoSubtitle.name = "subtitle";
	chessInfoSubtitle.setText(chessInfoSubtitle.textWrap("\"Chess\" is a special level where players can hang out and play chess together. Please, note that players with high ping might encounter some minor control artifacts.\n\nWASD - Move, LMB - Select/Place, RMB - Deselect, END key - end a match.", subtitle.font));
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

	// path line toggle (off by default)
	bool path_line = this.get_bool("path_line");
	Button@ disablePathLineToggle = @Button(Vec2f(10, 0), buttonSize, "Disable path line: " + (path_line ? "ON" : "OFF"), SColor(255, 255, 255, 255));
	disablePathLineToggle.name = "disablePathLineToggle";
	disablePathLineToggle.selfLabeled = true;
	disablePathLineToggle.rectColor = SColor(255, 55, 125, 185);
	disablePathLineToggle.toggled = path_line;
	disablePathLineToggle.addClickListener(toggleListener);
	settingsFrame.addChild(disablePathLineToggle);
	prevHeight += buttonSize.y + gap;

	// disable movement while menu is open (on by default)
	bool disable_movement = this.get_bool("disable_movement");
	Button@ disableMovementToggle = @Button(Vec2f(10, prevHeight), buttonSize, "Menu disables movement: " + (disable_movement ? "ON" : "OFF"), SColor(255, 255, 255, 255));
	disableMovementToggle.name = "disableMovementToggle";
	disableMovementToggle.selfLabeled = true;
	disableMovementToggle.rectColor = SColor(255, 55, 125, 185);
	disableMovementToggle.toggled = disable_movement;
	disableMovementToggle.addClickListener(toggleListener);
	settingsFrame.addChild(disableMovementToggle);
	prevHeight += buttonSize.y + gap;

	// can open menu while moving (off by default)
	bool allow_moving_menu = this.get_bool("allow_moving_menu");
	Button@ allowMovingMenuToggle = @Button(Vec2f(10, prevHeight), buttonSize, "Require stop for menu: " + (allow_moving_menu ? "ON" : "OFF"), SColor(255, 255, 255, 255));
	allowMovingMenuToggle.name = "allowMovingMenuToggle";
	allowMovingMenuToggle.selfLabeled = true;
	allowMovingMenuToggle.rectColor = SColor(255, 55, 125, 185);
	allowMovingMenuToggle.toggled = allow_moving_menu;
	allowMovingMenuToggle.addClickListener(toggleListener);
	settingsFrame.addChild(allowMovingMenuToggle);
	prevHeight += buttonSize.y + gap;
}

void UpdateSettings(CRules@ this)
{
	// updates the buttons in GUI
	Button@ disablePathLineToggle = cast<Button@>(settingsFrame.getChild("disablePathLineToggle"));
	if (disablePathLineToggle !is null)
	{
		bool path_line = disablePathLineToggle.toggled;
		this.set_bool("path_line", path_line);
		disablePathLineToggle.desc = "Disable path line: " + (path_line ? "ON" : "OFF");
	}

	Button@ disableMovementToggle = cast<Button@>(settingsFrame.getChild("disableMovementToggle"));
	if (disableMovementToggle !is null)
	{
		bool disable_movement = disableMovementToggle.toggled;
		this.set_bool("disable_movement", disable_movement);
		disableMovementToggle.desc = "Menu disables movement: " + (disable_movement ? "ON" : "OFF");
	}

	Button@ allowMovingMenuToggle = cast<Button@>(settingsFrame.getChild("allowMovingMenuToggle"));
	if (allowMovingMenuToggle !is null)
	{
		bool allow_moving_menu = allowMovingMenuToggle.toggled;
		this.set_bool("allow_moving_menu", allow_moving_menu);
		allowMovingMenuToggle.desc = "Require stop for menu: " + (allow_moving_menu ? "ON" : "OFF");
	}
}

void setCachedStates(CRules@ this)
{
	Button@ disablePathLineToggle = cast<Button@>(settingsFrame.getChild("disablePathLineToggle"));
	if (disablePathLineToggle !is null)
	{
		bool path_line = disablePathLineToggle.getBool("path_line", "parkour_settings");
		this.set_bool("path_line", path_line);
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

void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{
	
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

	RenderShownVideos(active_help_videos, active_help_video_positions, showMenu);

	bool initialized = this.get_bool("GUI initialized");
	if (!initialized) return;

    // draw render inherits here
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
