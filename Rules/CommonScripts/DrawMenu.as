#define CLIENT_ONLY

#include "TeamColour.as";
#include "KGUI.as";
#include "Listeners.as";

const Vec2f menuSize = Vec2f(500, 200);
const f32 slideOffset = 100.0f; // extra height
const u32 warn_menu_movement_time = 30;

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
			|| @helpFrame == null
			|| @chessInfoFrame == null;
}

bool isHidden()
{
    return !showMenu;
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
        InitializeGUI(this);

		updateOptionSliderValues();
    	setCachedStates(this);
	}

	CControls@ controls = getControls();
	if (controls.isKeyJustPressed(KEY_F1)) showMenu = !showMenu;
	
	CPlayer@ player = getLocalPlayer();  
	if (player is null) return;

	string name = player.getUsername();
    bool previous_showMenu = showMenu; // must be last
	this.set_bool("showMenu", showMenu);
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
	subtitle.setText(subtitle.textWrap("* Load a level into your room to start.\n\n* Your room is inside the white square.\n\n* You can create and load own levels right now - see \"Help\".\n\n* Navigate through the menu for more info.", "Terminus_14"));
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
	infoSubtitle.setText(infoSubtitle.textWrap("Each of the official levels is possible to complete, and all of them have been at least one time.\nSome levels, though, require you to know theory and the moveset.\nEnable path line in settings and watch particular videos in \"Help\" section if you are stuck.", subtitle.font));
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
	levelsTitle.setText(levelsTitle.textWrap("Select a level (A/D)", title.font));
	levelsFrame.addChild(levelsTitle);

	// slider and scrollers for levels
	Rectangle@ levelsFrameContentSlider = @Rectangle(mainFrame.localPosition + Vec2f(10, 32), mainFrame.size - Vec2f(20, 62), SColor(0, 0, 0, 0));
	levelsFrameContentSlider.name = "slider";
	levelsFrameContentSlider._customData = 0;
	levelsFrame.addChild(levelsFrameContentSlider);

	Button@ levelsFrameScrollerLeft = @Button(scrollerLeftPos, scrollerLeftSize, "<", SColor(255, 255, 255, 255), "Terminus_18");
	levelsFrameScrollerLeft.name = "levelsFrameScrollerLeft";
	levelsFrameScrollerLeft.rectColor = SColor(255, 255, 25, 55);
	levelsFrameScrollerLeft.addClickListener(scrollerClickListener);
	levelsFrameScrollerLeft._customData = -1;
	levelsFrame.addChild(levelsFrameScrollerLeft);

	Button@ levelsFrameScrollerRight = @Button(scrollerRightPos, scrollerRightSize, ">", SColor(255, 255, 255, 255), "Terminus_18");
	levelsFrameScrollerRight.name = "levelsFrameScrollerRight";
	levelsFrameScrollerRight.rectColor = SColor(255, 255, 25, 55);
	levelsFrameScrollerRight.addClickListener(scrollerClickListener);
	levelsFrameScrollerRight._customData = 1;
	levelsFrame.addChild(levelsFrameScrollerRight);

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
	helpTitle.setText(helpTitle.textWrap("Hover on the videos to watch them (A/D)", title.font));
	helpFrame.addChild(helpTitle);

	// slider and scrollers
	Rectangle@ helpFrameContentSlider = @Rectangle(mainFrame.localPosition + Vec2f(10, 32), mainFrame.size - Vec2f(20, 62), SColor(0, 0, 0, 0));
	helpFrameContentSlider.name = "slider";
	helpFrameContentSlider._customData = 0;
	helpFrame.addChild(helpFrameContentSlider);

	Button@ helpFrameScrollerLeft = @Button(scrollerLeftPos, scrollerLeftSize, "<", SColor(255, 255, 255, 255), "Terminus_18");
	helpFrameScrollerLeft.name = "helpFrameScrollerLeft";
	helpFrameScrollerLeft.rectColor = SColor(255, 65, 185, 85);
	helpFrameScrollerLeft.addClickListener(scrollerClickListener);
	helpFrameScrollerLeft._customData = -1;
	helpFrame.addChild(helpFrameScrollerLeft);

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
	Vec2f buttonSize = Vec2f(settingsFrame.size.x / 2 - 10, 30);

	f32 gap = 5;
	f32 prevHeight = 0;

	// path line toggle (off by default)
	bool path_line = this.get_bool("path_line");
	Button@ disablePathLineToggle = @Button(Vec2f(20, 0), buttonSize, "Disable path line: " + (path_line ? "ON" : "OFF"), SColor(255, 255, 255, 255));
	disablePathLineToggle.name = "disablePathLineToggle";
	disablePathLineToggle.selfLabeled = true;
	disablePathLineToggle.rectColor = SColor(255, 55, 125, 185);
	disablePathLineToggle.toggled = path_line;
	disablePathLineToggle.addClickListener(toggleListener);
	settingsFrame.addChild(disablePathLineToggle);
	prevHeight += buttonSize.y + gap;

	// disable movement while menu is open (on by default)
	bool disable_movement = this.get_bool("disable_movement");
	Button@ disableMovementToggle = @Button(Vec2f(20, prevHeight), buttonSize, "Disable movement in menu: " + (disable_movement ? "ON" : "OFF"), SColor(255, 255, 255, 255));
	disableMovementToggle.name = "disableMovementToggle";
	disableMovementToggle.selfLabeled = true;
	disableMovementToggle.rectColor = SColor(255, 55, 125, 185);
	disableMovementToggle.toggled = disable_movement;
	disableMovementToggle.addClickListener(toggleListener);
	settingsFrame.addChild(disableMovementToggle);
	prevHeight += buttonSize.y + gap;

	// can open menu while moving (off by default)
	bool allow_moving_menu = this.get_bool("allow_moving_menu");
	Button@ allowMovingMenuToggle = @Button(Vec2f(20, prevHeight), buttonSize, "Require stop for menu: " + (allow_moving_menu ? "ON" : "OFF"), SColor(255, 255, 255, 255));
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
		disableMovementToggle.desc = "Disable movement in menu: " + (disable_movement ? "ON" : "OFF");
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

void onCommand( CRules@ this, u8 cmd, CBitStream @params )
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
	menuWindow.draw();

	f32 tick = 2;

	#ifdef STAGING
	tick = Maths::Max(2, f32(v_fpslimit) / 60);
	#endif

	f32 mod = Maths::Clamp(0.0f, 1.0f, active_time / slideOffset * tick);
	
	Vec2f posHidden = getMenuPosHidden();
	Vec2f posShown = getMenuPosShown();

	active_time = showMenu ? active_time + 1.0f / tick : 0;
	menuWindow.setPosition(Vec2f_lerp(menuWindow.localPosition, showMenu ? posShown : posHidden, 0.35f));

	Button@ switcher = cast<Button@>(menuWindow.getChild("switchButton"));
	if (switcher !is null)
	{
		switcher.setPosition(Vec2f_lerp(switcher.localPosition, switcher.initialPosition + Vec2f(0, showMenu ? 30 : 0), 0.35f));
	}

	bool initialized = this.get_bool("GUI initialized");
	if (!initialized) return;

    // draw render inherits here
}

Vec2f getMenuPosHidden()
{
	Vec2f screen_size = getDriver().getScreenDimensions();
	return Vec2f(screen_size.x / 2 - 470, screen_size.y);
}

Vec2f getMenuPosShown()
{
	Vec2f screen_size = getDriver().getScreenDimensions();
	return Vec2f(screen_size.x / 2 - 470, screen_size.y - menuSize.y - slideOffset);
}
