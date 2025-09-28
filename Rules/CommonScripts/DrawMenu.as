#define CLIENT_ONLY

#include "TeamColour.as";
#include "KGUI.as";
#include "Listeners.as";

const Vec2f menuSize = Vec2f(500, 200);
const f32 slideOffset = 100.0f; // extra height

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

bool isGUINull()
{
	return
            @menuWindow == null;
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
	}

	CControls@ controls = getControls();
	if (controls.isKeyJustPressed(KEY_F1)) showMenu = !showMenu;
	
	CPlayer@ player = getLocalPlayer();  
	if (player is null) return;

	string name = player.getUsername();

    updateOptionSliderValues();
    setCachedStates(this);

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

    Vec2f screen_size = getDriver().getScreenDimensions();
    Vec2f menuPosHidden = getMenuPosHidden();

	// main window (hidden by default)
	@menuWindow = @Window(menuPosHidden, menuSize, 0, "Menu");
	menuWindow.name = "Menu";
	menuWindow.setLevel(ContainerLevel::WINDOW);
	
	Button@ switchButton = @Button(Vec2f(menuSize.x, -30), Vec2f(30, 30), "", SColor(255, 200, 50, 50));
	switchButton.name = "switchButton";
	switchButton.addClickListener(menuSwitchListener);
	menuWindow.addChild(switchButton);
	
	Icon@ switchButtonIcon = @Icon("MiniIcons.png", Vec2f(-1.5f, -1.5f), Vec2f(16, 16), 24, 1.0f, false);
	switchButtonIcon.name = "switchButtonIcon";
	switchButton.addChild(switchButtonIcon);

	Button@ infoButton = @Button(Vec2f(menuSize.x, 35), Vec2f(30, 30), "", SColor(255, 100, 200, 100));
	infoButton.addHoverStateListener(infoHoverListener);
	infoButton.name = "infoButton";
	menuWindow.addChild(infoButton);

	Icon@ infoButtonIcon = @Icon("InteractionIcons.png", Vec2f(-9, -8), Vec2f(32, 32), 14, 0.75f, false);
	infoButtonIcon.name = "infoButtonIcon";
	infoButton.addChild(infoButtonIcon);

	this.set_bool("GUI initialized", true);
	print("GUI has been initialized");
}

void setCachedStates(CRules@ this)
{
    /*
	showMenu = startCloseBtn.getBool("Start Closed", "WizardWars");

	startCloseBtn.toggled = !startCloseBtn.getBool("Start Closed","WizardWars");
	startCloseBtn.desc = (startCloseBtn.toggled) ? "Start Help Closed Enabled" : "Start Help Closed Disabled";
    */
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

	if (menuWindow is null) return;
	menuWindow.draw();

    Vec2f screen_size = driver.getScreenDimensions();
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
