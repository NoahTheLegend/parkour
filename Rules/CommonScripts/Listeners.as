#include "PseudoVideoPlayer.as";
#include "RoomsCommon.as";

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
        infoFrame.isEnabled = !infoFrameEnabled;
        at_least_one_enabled = infoFrame.isEnabled;
    }
    else if (name == "levelsButton")
    {
        levelsFrame.isEnabled = !levelsFrameEnabled;
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
        helpFrame.isEnabled = !helpFrameEnabled;
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

void loadChessListener(int x, int y, int button, IGUIItem@ sender)
{
    if (getLocalPlayer() is null) return;

    CRules@ rules = getRules();
    if (rules is null) return;

    if (sender is null) return;

    Button@ level = cast<Button@>(sender);
    if (level is null) return;

    string name = "ChessLevel.png";
    u8 type = RoomType::chess;

    int room_id = 5012;
    Vec2f pos = Vec2f_zero;

    CBitStream params;
    params.write_u16(getLocalPlayer().getNetworkID()); // player id
    params.write_u8(type);
    params.write_s32(room_id); // room id
    params.write_Vec2f(ROOM_SIZE); // room size
    params.write_Vec2f(pos); // start pos // todo: get from level data

    rules.SendCommand(rules.getCommandID("set_room"), params);
    print("sent "+rules.getCommandID("set_room"));
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
    else if (name == "instantTeleportToggle")
    {
        btn.toggled = !btn.toggled;
        btn.saveBool("instant_teleport", btn.toggled, "parkour_settings");
    }

    CRules@ rules = getRules();
    if (rules is null) return;
    
    UpdateSettings(rules);
}

void levelsClickListener(int x, int y, int button, IGUIItem@ sender)
{
    if (sender is null) return;

    Button@ btn = cast<Button@>(sender);
    if (btn is null) return;

    Button@ knightLevelsButton = cast<Button@>(levelsFrame.getChild("knightLevelsButton"));
    Button@ archerLevelsButton = cast<Button@>(levelsFrame.getChild("archerLevelsButton"));
    Button@ builderLevelsButton = cast<Button@>(levelsFrame.getChild("builderLevelsButton"));

    string name = btn.name;
    Rectangle@ selected_frame;

    if (name == "knightLevelsButton")
    {
        @selected_frame = @knightLevelsFrame;

        knightLevelsFrame.isEnabled = true;
        archerLevelsFrame.isEnabled = false;
        builderLevelsFrame.isEnabled = false;

        if (knightLevelsButton !is null) knightLevelsButton.rectColor = SColor(255, 255, 25, 55);
        if (archerLevelsButton !is null) archerLevelsButton.rectColor = SColor(255, 155, 25, 55);
        if (builderLevelsButton !is null) builderLevelsButton.rectColor = SColor(255, 155, 25, 55);
    }
    else if (name == "archerLevelsButton")
    {
        @selected_frame = @archerLevelsFrame;

        archerLevelsFrame.isEnabled = true;
        knightLevelsFrame.isEnabled = false;
        builderLevelsFrame.isEnabled = false;

        if (archerLevelsButton !is null) archerLevelsButton.rectColor = SColor(255, 255, 25, 55);
        if (knightLevelsButton !is null) knightLevelsButton.rectColor = SColor(255, 155, 25, 55);
        if (builderLevelsButton !is null) builderLevelsButton.rectColor = SColor(255, 155, 25, 55);
    }
    else if (name == "builderLevelsButton")
    {
        @selected_frame = @builderLevelsFrame;

        builderLevelsFrame.isEnabled = true;
        knightLevelsFrame.isEnabled = false;
        archerLevelsFrame.isEnabled = false;

        if (builderLevelsButton !is null) builderLevelsButton.rectColor = SColor(255, 255, 25, 55);
        if (knightLevelsButton !is null) knightLevelsButton.rectColor = SColor(255, 155, 25, 55);
        if (archerLevelsButton !is null) archerLevelsButton.rectColor = SColor(255, 155, 25, 55);
    }

    // build levels grid using UpdateHelpFrameVideos as reference
    if (selected_frame !is null && selected_frame.isEnabled)
    {
        Rectangle@ slider = cast<Rectangle@>(selected_frame.getChild("slider"));
        if (slider is null) return;

        //slider._customData = 0; // reset to first page
        Vec2f grid = default_grid_levels;
        UpdateLevels(slider, grid);
    }
}

void UpdateLevels(Rectangle@ slider, Vec2f grid)
{
    const bool debug_levels_bg = false; // set to true to enable debug background coloring

    int showing_page = slider._customData;
    int showing_count = int(grid.x * grid.y);
    Vec2f starting_position = Vec2f(64, -40);

    // hide all children first
    for (uint i = 0; i < slider.children.size(); i++)
    {
        Rectangle@ child = cast<Rectangle@>(slider.children[i]);
        if (child is null) continue;
        child.isEnabled = false;
    }

    // prepare row/column sizes
    array<float> col_widths(int(grid.x), 0.0f);
    array<float> row_heights(int(grid.y), 0.0f);

    const f32 offsetx = 40.0f;
    const f32 offsety = 140.0f;

    // calculate max width/height per column/row
    for (uint i = 0; i < showing_count; i++)
    {
        uint index = i + (showing_page * showing_count);
        if (index >= slider.children.size()) break;

        Rectangle@ child = cast<Rectangle@>(slider.children[index]);
        if (child is null) continue;

        Icon@ icon = cast<Icon@>(child.getChild("icon"));
        Vec2f icon_size = child.size;
        if (icon !is null)
        {
            icon_size = icon.size;
        }

        int col = i % int(grid.x);
        int row = i / int(grid.x); // FIXED: use grid.x for columns, grid.y for rows

        if (icon_size.x > col_widths[col]) col_widths[col] = icon_size.x;
        if (icon_size.y > row_heights[row]) row_heights[row] = icon_size.y;
    }

    // calculate max allowed gap so total width/height does not exceed parent size
    float max_gap_x = 0.0f;
    float max_gap_y = 0.0f;
    if (col_widths.size() > 1)
    {
        float total_width = sum(col_widths);
        float available_width = slider.size.x - starting_position.x * 2 - offsetx;
        max_gap_x = Maths::Max(0.0f, (available_width - total_width) / (col_widths.size() - 1));
    }
    if (row_heights.size() > 1)
    {
        float total_height = sum(row_heights);
        float available_height = slider.size.y - starting_position.y * 2 - offsety;
        max_gap_y = Maths::Max(0.0f, (available_height - total_height) / (row_heights.size() - 1));
    }

    // position and enable children with limited gaps
    for (uint i = 0; i < showing_count; i++)
    {
        uint index = i + (showing_page * showing_count);
        if (index >= slider.children.size()) break;

        Rectangle@ child = cast<Rectangle@>(slider.children[index]);
        if (child is null) continue;

        int col = i % int(grid.x);
        int row = i / int(grid.x);

        float x = 0.0f;
        for (int c = 0; c < col; c++)
            x += col_widths[c] + max_gap_x;

        float y = 0.0f;
        for (int r = 0; r < row; r++)
            y += row_heights[r] + max_gap_y;

        Vec2f pos = starting_position + Vec2f(x, y);
        Vec2f new_size = Vec2f(col_widths[col], row_heights[row]);

        child.setPosition(pos);
        child.isEnabled = true;

        Button@ text_pane = cast<Button@>(child.getChild("text_pane"));
        if (text_pane !is null)
        {
            text_pane.setPosition(Vec2f((child.size.x - text_pane.size.x) / 2, new_size.y + text_pane.size.y * 2));
        }

        if (debug_levels_bg)
        {
            int shade = Maths::Clamp(255 - i * 5, 0, 255);
            child.color = SColor(255, shade, shade, shade);
        }
    }
}

void loadLevelClickListener(int x, int y, int button, IGUIItem@ sender)
{
    if (getLocalPlayer() is null) return;

    CRules@ rules = getRules();
    if (rules is null) return;

    if (sender is null) return;

    Rectangle@ level = cast<Rectangle@>(sender);
    if (level is null) return;

    string name = level.name;
    string[] spl = name.split("_");
    if (spl.length < 2) return;

    u8 type = getTypeFromName(spl[0]);
    int room_id = parseInt(spl[1]);
    if (room_id < 0) return;
    print(""+room_id);
    Vec2f pos = Vec2f_zero; // todo: get from level data
    sendRoomCommand(rules, type, room_id, pos);
}

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
    }
    else
    {
        icon.color.set(255, 255, 255, 255);
        text_pane.rectColor = SColor(255, 255, 0, 0);
    }
}

float sum(array<float>@ arr)
{
    float s = 0.0f;
    for (uint i = 0; i < arr.size(); i++) s += arr[i];
    return s;
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

    int slider_data = slider._customData;
    slider.setCustomData(slider_data + data);
    if (parent.name == "helpFrame")
    {
        Vec2f grid = default_grid;
        slider._customData = Maths::Clamp(slider._customData, 0, help_videos.size() / (grid.x * grid.y));
        UpdateHelpFrameVideos(slider, grid);
    }
    else if (parent.name == "knightLevelsFrame" || parent.name == "archerLevelsFrame" || parent.name == "builderLevelsFrame")
    {
        Vec2f grid = default_grid_levels;
        slider._customData = Maths::Clamp(slider._customData, 0, slider.children.size() / (grid.x * grid.y));
        UpdateLevels(slider, grid);
    }

}

// TODO: needs a huge rework (this dogshit is unreadable)
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
