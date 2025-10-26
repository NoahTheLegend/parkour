#include "PseudoVideoPlayer.as";
#include "Helpers.as";
#include "RoomsCommon.as";;
#include "RoomsHandlers.as";
#include "CommandHandlers.as";

// global menu switcher
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

// handles main page button clicks to switch between frames
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

    active_help_videos.clear();
    active_help_video_positions.clear();

    if (name == "infoButton")
    {
        infoFrame.isEnabled = true;
        at_least_one_enabled = infoFrame.isEnabled;
    }
    else if (name == "levelsButton")
    {
        levelsFrame.isEnabled = true;
        at_least_one_enabled = levelsFrame.isEnabled;

        if (levelsFrame.isEnabled)
        {
            Rectangle@ slider = cast<Rectangle@>(knightLevelsFrame.getChild("slider"));
            if (slider is null) return;

            if (slider._customData == -1)
            {
                Button@ levelsFrameScrollerLeft = cast<Button@>(knightLevelsFrame.getChild("levelsFrameScrollerLeft"));
                if (levelsFrameScrollerLeft is null) return;

                Vec2f scroller_pos = levelsFrameScrollerLeft.getAbsolutePosition();
                scrollerClickListener(scroller_pos.x, scroller_pos.y + 1, 1, levelsFrameScrollerLeft);
            }
        }
    }
    else if (name == "helpButton")
    {
        helpFrame.isEnabled = true;
        at_least_one_enabled = helpFrame.isEnabled;

        if (helpFrame.isEnabled)
        {
            UpdateHelpFrameVideos(cast<Rectangle@>(helpFrame.getChild("slider")), default_grid);

            Rectangle@ slider = cast<Rectangle@>(helpFrame.getChild("slider"));
            if (slider is null) return;

            if (slider._customData == -1)
            {
                Button@ helpFrameScrollerLeft = cast<Button@>(helpFrame.getChild("helpFrameScrollerLeft"));
                if (helpFrameScrollerLeft is null) return;

                Vec2f scroller_pos = helpFrameScrollerLeft.getAbsolutePosition();
	            scrollerClickListener(scroller_pos.x, scroller_pos.y + 1, 1, helpFrameScrollerLeft);
            }
        }
    }
    else if (name == "settingsButton")
    {
        settingsFrame.isEnabled = true;
        at_least_one_enabled = settingsFrame.isEnabled;
    }
    else if (name == "chessInfoButton")
    {
        chessInfoFrame.isEnabled = true;
        at_least_one_enabled = chessInfoFrame.isEnabled;
    }

    if (!at_least_one_enabled)
    {
        mainFrame.isEnabled = true;
        infoFrame.isEnabled = false;
        levelsFrame.isEnabled = false;
        helpFrame.isEnabled = false;
        settingsFrame.isEnabled = false;
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

// handles settings buttons
void toggleListener(int x, int y, int button, IGUIItem@ sender)
{
    if (sender is null) return;

    Button@ btn = cast<Button@>(sender);
    if (btn is null) return;

    // note for developers: all buttons are ON by default when config is firstly created

    string name = btn.name;
    if (name == "nextLevelSwapToggle")
    {
        btn.toggled = !btn.toggled;
        btn.saveBool("next_level_swap", btn.toggled, "parkour_settings");
    }
    else if (name == "disablePathLineToggle")
    {
        btn.toggled = !btn.toggled;
        btn.saveBool("enable_pathline", btn.toggled, "parkour_settings");
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
    else if (name == "continuousTeleportToggle")
    {
        btn.toggled = !btn.toggled;
        btn.saveBool("continuous_teleport", btn.toggled, "parkour_settings");
    }
    else if (name == "closeOnRoomSelectToggle")
    {
        btn.toggled = !btn.toggled;
        btn.saveBool("close_on_room_select", btn.toggled, "parkour_settings");
    }

    CRules@ rules = getRules();
    if (rules is null) return;
    
    UpdateSettings(rules);
}

// requests server to create a new room, the rest of the logic is handled on server
void createRoomClickListener(int x, int y, int button, IGUIItem@ sender)
{
    if (getLocalPlayer() is null) return;

    CRules@ rules = getRules();
    if (rules is null) return;

    CBitStream params;
    params.write_u16(getLocalPlayer().getNetworkID()); // player id

    rules.SendCommand(rules.getCommandID("create_room"), params);
}

// switcher for levels categories
void levelsCategoryClickListener(int x, int y, int button, IGUIItem@ sender)
{
    if (sender is null) return;

    Button@ btn = cast<Button@>(sender);
    if (btn is null) return;

    Button@ createRoom = cast<Button@>(levelsFrame.getChild("createRoomButton"));
    if (createRoom is null) return;

    Rectangle@ levelsWrapper = cast<Rectangle@>(levelsFrame.getChild("levelsWrapper"));
    if (levelsWrapper is null) return;

    Button@ knightLevelsButton = cast<Button@>(levelsWrapper.getChild("knightLevelsButton"));
    Button@ archerLevelsButton = cast<Button@>(levelsWrapper.getChild("archerLevelsButton"));
    Button@ builderLevelsButton = cast<Button@>(levelsWrapper.getChild("builderLevelsButton"));
    Button@ customLevelsButton = cast<Button@>(levelsWrapper.getChild("customLevelsButton"));

    string name = btn.name;
    Rectangle@ selected_frame;

    // handle knight/archer/builder/custom level buttons with less duplicate code
    if (name == "knightLevelsButton" ||
        name == "archerLevelsButton" ||
        name == "builderLevelsButton" ||
        name == "customLevelsButton")
    {
        array<string> levelBtns = { "knightLevelsButton", "archerLevelsButton", "builderLevelsButton", "customLevelsButton" };
        array<Rectangle@> framesArr = { @knightLevelsFrame, @archerLevelsFrame, @builderLevelsFrame, @customLevelsFrame };
        array<Button@> btnArr = { @knightLevelsButton, @archerLevelsButton, @builderLevelsButton, @customLevelsButton };

        int selectedIdx = -1;
        for (int i = 0; i < int(levelBtns.size()); i++)
        {
            if (name == levelBtns[i])
            {
                selectedIdx = i;
                break;
            }
        }

        if (selectedIdx != -1)
        {
            for (int i = 0; i < int(framesArr.size()); i++)
            {
                Rectangle@ f = framesArr[i];
                if (f !is null) f.isEnabled = (i == selectedIdx);

                Button@ b = btnArr[i];
                if (b !is null)
                {
                    b.rectColor = (i == selectedIdx) ? SColor(255, 255, 25, 55) : SColor(255, 155, 25, 55);
                }

                if (i == selectedIdx)
                    @selected_frame = framesArr[i];
            }
        }

        // build levels grid for the selected frame
        if (selected_frame !is null && selected_frame.isEnabled)
        {
            Rectangle@ slider = cast<Rectangle@>(selected_frame.getChild("slider"));
            if (slider is null) return;

            Vec2f grid = default_grid_levels;
            UpdateLevels(slider, grid);
        }
    }
}

// updates the levels frame based on the current page and grid size
void UpdateLevels(Rectangle@ slider, Vec2f grid)
{
    const bool debug_levels_bg = false; // set to true to enable debug background coloring

    Rectangle@ parent = cast<Rectangle@>(slider.parent);
    if (parent is null) return;

    int showing_page = slider._customData;
    int showing_count = int(grid.x * grid.y);

    // padding from slider edges for the whole grid area
    Vec2f padding = Vec2f(12, -24);
    Vec2f area_start = Vec2f(padding.x * (1.0f + 1.0f / grid.x), 24);
    Vec2f area_size = slider.size - padding;

    // hide all children first
    for (uint i = 0; i < slider.children.size(); i++)
    {
        Rectangle@ child = cast<Rectangle@>(slider.children[i]);
        if (child is null) continue;
        child.isEnabled = false;
    }

    if (area_size.x <= 0.0f || area_size.y <= 0.0f) return;

    // compute equal cells (space-between style) and center each child in its cell
    float cell_w = area_size.x / grid.x;
    float cell_h = area_size.y / grid.y;

    // position and enable children
    for (uint i = 0; i < showing_count; i++)
    {
        uint index = i + (showing_page * showing_count);
        if (index >= slider.children.size()) break;

        Rectangle@ child = cast<Rectangle@>(slider.children[index]);
        if (child is null) continue;

        int col = i % int(grid.x);
        int row = i / int(grid.x);

        // center child inside its cell
        float x = area_start.x + col * cell_w + (cell_w - child.size.x) * 0.5f;
        float y = area_start.y + row * cell_h + (cell_h - child.size.y) * 0.5f;

        // clamp to slider interior to avoid overflow
        x = Maths::Clamp(x, padding.x, slider.size.x - padding.x - child.size.x);
        y = Maths::Clamp(y, padding.y, slider.size.y - padding.y - child.size.y / 2);

        Vec2f pos = Vec2f(x, y);

        child.setPosition(pos);
        child.isEnabled = true;

        Icon@ icon = cast<Icon@>(child.getChild("icon"));
        if (icon !is null)
        {
            // compute the displayed size (icon.size * icon.scale) and center that inside the child
            f32 icon_scale = icon.scale;
            Vec2f displayed = Vec2f(icon.size.x * icon_scale, icon.size.y * icon_scale);

            Vec2f icon_pos = Vec2f((child.size.x - displayed.x) * 0.5f, (child.size.y - displayed.y) * 0.5f);
            icon.setPosition(icon_pos - displayed / 2);
        }

        // place text pane below the child, centered
        Button@ text_pane = cast<Button@>(child.getChild("text_pane"));
        if (text_pane !is null)
        {
            Vec2f middle_bottom = Vec2f(
                child.size.x / 2 - text_pane.size.x / 2,
                child.size.y + 4
            );
            text_pane.setPosition(middle_bottom);
        }

        if (debug_levels_bg)
        {
            int shade = Maths::Clamp(255 - int(i) * 5, 0, 255);
            child.color = SColor(255, shade, shade, shade);
        }
    }
}

// click callback for loading a level
void loadLevelClickListener(int x, int y, int button, IGUIItem@ sender)
{
    CPlayer@ local = getLocalPlayer();
    if (local is null) return;

    CRules@ rules = getRules();
    if (rules is null) return;
    if (sender is null) return;

    u8 room_id = rules.get_u8("captured_room_id");
    if (room_id == 255)
    {
        print("No free room id available for level");
        return;
    }

    Rectangle@ level = cast<Rectangle@>(sender);
    if (level is null) return;

    string name = level.name;
    string[] spl = name.split("_");
    if (spl.length < 2) return;

    u8 type = getTypeFromName(spl[0]);
    int level_id = parseInt(spl[1]);
    if (level_id < 0) return;

    Vec2f pos = getRoomPosFromID(room_id);
    sendRoomCommand(rules, local.getNetworkID(), type, level_id, pos);
}

// visual hover effect for level buttons
void levelHoverListener(bool is_over, IGUIItem@ sender)
{
    if (sender is null) return;

    Rectangle@ level = cast<Rectangle@>(sender);
    if (level is null) return;

    Icon@ icon = cast<Icon@>(level.getChild("icon"));
    if (icon is null) return;

    Button@ text_pane = cast<Button@>(level.getChild("text_pane"));
    if (text_pane is null) return;

    if (is_over)
    {
        icon.color.set(255, 215, 215, 215);
        text_pane.rectColor = SColor(255, 215, 0, 0);

        hovering_filename = level.name;
        hovering_size = icon.size;
    }
    else
    {
        icon.color.set(255, 255, 255, 255);
        text_pane.rectColor = SColor(255, 255, 0, 0);

        if (hovering_filename == level.name)
        {
            hovering_filename = "";
            hovering_size = Vec2f_zero;
        }
    }
}

// scroller switcher for frames
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

    int slider_data = slider._customData;
    slider.setCustomData(slider_data + data);
    if (parent.name == "helpFrame")
    {
        Vec2f grid = default_grid;
        slider._customData = Maths::Clamp(slider._customData, 0, help_videos.size() / (grid.x * grid.y));
        UpdateHelpFrameVideos(slider, grid);
    }
    else
    {
        Vec2f grid = default_grid_levels;
        slider._customData = Maths::Clamp(slider._customData, 0, slider.children.size() / (grid.x * grid.y));
        UpdateLevels(slider, grid);
    }
}

// updates the help frame videos based on the current page and grid size
void UpdateHelpFrameVideos(Rectangle@ slider, Vec2f grid)
{
    Label@ parent_title = cast<Label@>(helpFrame.getChild("title"));
    if (parent_title !is null)
    {
        int suffix = parent_title.label.findLast("[");
        if (suffix != -1)
        {
            // replace suffix of current page and format to [01]
            string base_label = parent_title.label.substr(0, suffix);
            int page_num = slider._customData + 1;
            string page_str = page_num < 10 ? "0" + page_num : "" + page_num;
            parent_title.label = base_label + "[" + page_str + "]";
        }
    }
    int showing_page = slider._customData;
    int showing_count = int(grid.x * grid.y);
    Vec2f starting_position = helpFrame.getAbsolutePosition() + Vec2f(50, 25);

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

        Vec2f gap = Vec2f(0, 0);
        Vec2f parent_size = helpFrame.size - Vec2f(100, 50);
        Vec2f new_size = Vec2f(
            (parent_size.x - (grid.x - 1) * gap.x) / grid.x,
            (parent_size.y - (grid.y - 1) * gap.y) / grid.y
        );

        help_videos[index].rescale(new_size * 0.5f);
        Vec2f pos = starting_position + Vec2f(i % int(grid.x) * (new_size.x + gap.x), i / int(grid.x) * (new_size.y + gap.y));
        
        active_help_video_positions.push_back(pos);
        help_videos[index].show();
    }
}

// click callback for loading the chess level
void loadChessListener(int x, int y, int button, IGUIItem@ sender)
{
    if (getLocalPlayer() is null) return;

    CRules@ rules = getRules();
    if (rules is null) return;
    if (sender is null) return;

    Button@ level = cast<Button@>(sender);
    if (level is null) return;

    CPlayer@ localPlayer = getLocalPlayer();
    if (localPlayer is null) return;

    LoadChessLevel(rules, localPlayer.getNetworkID());
}

// switcher for editor, todo
void openEditorListener(int x, int y, int button, IGUIItem@ sender)
{
    if (getLocalPlayer() is null) return;

    CRules@ rules = getRules();
    if (rules is null) return;

    CBitStream params;
    params.write_u16(getLocalPlayer().getNetworkID()); // player id

    rules.SendCommand(rules.getCommandID("editor"), params);
}