#include "PseudoVideoPlayer.as";

void menuSwitchListener(int x, int y, int button, IGUIItem@ sender)
{
    if (sender is null) return;

    CRules@ rules = getRules();
    if (rules is null) return;
    
    CBlob@ local = getLocalPlayerBlob();
    if (rules.get_bool("allow_moving_menu") && local !is null && local.getVelocity().Length() > 0.1f)
    {
        if (!showMenu)
        {
            CRules@ rules = getRules();
            rules.set_u32("warn_menu_movement", getGameTime()); // 1 second
        }

        showMenu = false;
        return;
    }
    
    showMenu = !showMenu;
}

void infoHoverListener(bool hover, IGUIItem@ item)
{
	if (item is null) return;

    Button@ button = cast<Button@>(item);
    if (button is null) return;

    button.setToolTip(hover ? "todo" : "", 1, SColor(255, 255, 255, 255));
}

void pageClickListener(int x, int y, int button, IGUIItem@ sender)
{
    if (sender is null) return;

    Button@ btn = cast<Button@>(sender);
    if (btn is null) return;

    bool mainFrameEnabled = mainFrame.isEnabled;
    bool infoFrameEnabled = infoFrame.isEnabled;
    bool levelsFrameEnabled = levelsFrame.isEnabled;
    bool helpFrameEnabled = helpFrame.isEnabled;
    bool settingsFrameEnabled = settingsFrame.isEnabled;
    bool chessInfoFrameEnabled = chessInfoFrame.isEnabled;

    mainFrame.isEnabled = false;
    infoFrame.isEnabled = false;
    levelsFrame.isEnabled = false;
    helpFrame.isEnabled = false;
    settingsFrame.isEnabled = false;
    chessInfoFrame.isEnabled = false;

    bool at_least_one_enabled = false;
    string name = btn.name;

    if (name == "infoButton")
    {
        infoFrame.isEnabled = !infoFrameEnabled;
        at_least_one_enabled = infoFrame.isEnabled;
    }
    else if (name == "levelsButton")
    {
        levelsFrame.isEnabled = !levelsFrame.isEnabled;
        at_least_one_enabled = levelsFrame.isEnabled;
    }
    else if (name == "helpButton")
    {
        helpFrame.isEnabled = !helpFrame.isEnabled;
        at_least_one_enabled = helpFrame.isEnabled;
    }
    else if (name == "settingsButton")
    {
        settingsFrame.isEnabled = !settingsFrameEnabled;
        at_least_one_enabled = settingsFrame.isEnabled;
    }
    else if (name == "chessInfoButton")
    {
        chessInfoFrame.isEnabled = !chessInfoFrameEnabled;
        at_least_one_enabled = chessInfoFrame.isEnabled;
    }

    if (!at_least_one_enabled)
    {
        mainFrame.isEnabled = true;

        chessInfoFrame.isEnabled = false;
    }

    Rectangle@ switcherPointer = cast<Rectangle@>(menuWindow.getChild("switcherPointer"));
    if (switcherPointer !is null)
    {
        if (!at_least_one_enabled)
        {
            switcherPointer.isEnabled = false;
            return;
        }

        Vec2f selected_pos = btn.localPosition + Vec2f(btn.size.x / 2 - switcherPointer.size.x / 2, btn.size.y - 2);
        switcherPointer.setPosition(selected_pos);
        switcherPointer.isEnabled = true;
    }
}

void scrollerClickListener(int x, int y, int button, IGUIItem@ sender)
{
    if (sender is null) return;

    Button@ btn = cast<Button@>(sender);
    if (btn is null) return;

    int data = btn._customData;

    IGUIItem@ parent = btn.parent;
    if (parent is null) return;

    Rectangle@ slider = cast<Rectangle@>(parent.getChild("slider"));
    if (slider is null) return;

    Vec2f grid = Vec2f(3, 2);
    slider._customData += data;
    slider._customData = Maths::Clamp(slider._customData, 0, slider.children.size() / (grid.x * grid.y) - 1);

    if (parent.name == "helpFrame")
    {
        u8 showing_page = slider._customData;
        u8 showing_count = grid.x * grid.y;
        Vec2f starting_position = parent.getAbsolutePosition() + Vec2f(50, 25); // debug test for now

        // set all to hidden first
        for (uint i = 0; i < active_help_videos.size(); i++)
        {
            if (active_help_videos[i] is null) continue;
            active_help_videos[i].hide();
        }
        active_help_videos.clear();
        active_help_video_positions.clear();

        // then show showing_count with starting index depending on the page
        for (uint i = 0; i < showing_count; i++)
        {
            uint index = i + (showing_page * showing_count);
            if (index >= help_videos.size()) break;
            if (help_videos[index] is null) continue;

            active_help_videos.push_back(@help_videos[index]);
            Vec2f parent_size = parent.size - Vec2f(100, 50);
            Vec2f new_size = Vec2f(parent_size.x / grid.x, parent_size.y / grid.y);
            help_videos[index].rescale(new_size * 0.5f);

            Vec2f pos = starting_position + Vec2f(i % int(grid.x) * new_size.x, i / int(grid.x) * new_size.y);
            active_help_video_positions.push_back(pos);

            help_videos[index].show();
        }
    }
}

void loadChessListener(int x, int y, int button, IGUIItem@ sender)
{
    if (sender is null) return;

    Button@ btn = cast<Button@>(sender);
    if (btn is null) return;

    // todo
}

void toggleListener(int x, int y, int button, IGUIItem@ sender)
{
    if (sender is null) return;

    Button@ btn = cast<Button@>(sender);
    if (btn is null) return;

    // note for developers: all buttons are ON by default when config is firstly created

    string name = btn.name;
    if (name == "disablePathLineToggle")
    {
        btn.toggled = !btn.toggled;
        btn.saveBool("path_line", btn.toggled, "parkour_settings");
    }
    else if (name == "disableMovementToggle")
    {
        btn.toggled = !btn.toggled;
        btn.saveBool("disable_movement", btn.toggled, "parkour_settings");
    }
    else if (name == "allowMovingMenuToggle")
    {
        btn.toggled = !btn.toggled;
        btn.saveBool("allow_moving_menu", btn.toggled, "parkour_settings");
    }

    CRules@ rules = getRules();
    if (rules is null) return;
    
    UpdateSettings(rules);
}
