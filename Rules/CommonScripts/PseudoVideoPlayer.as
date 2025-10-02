
class VideoPlayer
{
    bool is_rendering;
    bool is_playing;
    f32 speed;

    Vec2f size;
    f32 scaleX;
    f32 scaleY;

    int current_frame;
    string video_path;

    string[] _paths_to_frames;
    int total_frames;
    f32 render_time;

    Vec2f screen_size;
    f32 fade_in;

    string label;

    VideoPlayer(string path, Vec2f _size, f32 _scale = 1.0f, f32 _speed = 1.0f)
    {
        video_path = path;
        size = _size;
        scaleX = _scale;
        scaleY = _scale;
        speed = _speed;
        
        is_rendering = false;
        is_playing = false;
        current_frame = 0;
        total_frames = 0;
        render_time = 0.0f;

        _paths_to_frames.clear();
        cachePaths();

        screen_size = getDriver().getScreenDimensions();
        fade_in = 1.0f;

        string[] spl = path.split("/");
        string[] label_spl = spl[spl.length() - 1].split("_");
        for (uint i = 0; i < label_spl.length(); i++)
        {
            if (i > 0) label += " ";
            label += label_spl[i];
        }
    }

    void cachePaths()
    {
        // store all absolute paths to frames to optimize future access
        for (uint i = 0; i < 5120; i++)
        {
            string formatted = ("0000" + i).substr((("0000" + i).length() - 4), 4);
            string raw_path = video_path + "/Files/" + formatted + ".png";

            CFileMatcher fm(raw_path);
            string frame_path = fm.getFirst();

            if (frame_path == "")
            {
                break;
            }
            else
            {
                _paths_to_frames.push_back(frame_path);
                total_frames++;

                //print("Cached frame: " + frame_path + " raw: " + raw_path);
            }
        }
    }

    void show()
    {
        is_rendering = true;
    }

    void begin()
    {
        is_playing = true;
        current_frame = 0;
        render_time = 0;

        fade_in = 0.0f;
        screen_size = getDriver().getScreenDimensions();
    }

    void render(Vec2f screen_position, bool menu_open) // 1 tick = 30 units
    {
        if (!menu_open)
        {
            return;
        }

        if (is_playing && is_rendering)
        {
            fade_in = Maths::Lerp(Maths::Max(0.5f, fade_in), 1.0f, 0.25f);

            // render_time is adding up to 1.0f to trigger a frame change with any fpslimit set
            f32 tick = f32(30.0f) / 30.0f;

	        #ifdef STAGING
	        tick = Maths::Max(1, f32(v_fpslimit) / 30.0f);
	        #endif

            render_time += 1.0f / tick * speed;
            if (render_time >= 1.0f)
            {
                current_frame += int(render_time);
                render_time = 0;
            }

            if (current_frame >= total_frames)
            {
                current_frame = 0;
            }
        }

        if (!is_rendering) return;

        // draw decoration bg pane
        Vec2f extra_size = Vec2f(4, 4);
        Vec2f scaled_size = Vec2f(size.x * scaleX, size.y * scaleY) * 2;

        GUI::DrawPane(screen_position - extra_size, screen_position + scaled_size + extra_size, SColor(255, 155, 55, 25));

        // if playing, draw on the middle of the screen in original size
        f32 currentSX = scaleX;
        f32 currentSY = scaleY;

        Vec2f current_position = screen_position;
        bool show_label = false;

        if (is_playing)
        {
            currentSX = 0.5f;
            currentSY = 0.5f;
            extra_size = Vec2f(8, 8);

            // draw image exactly in the center of screen
            current_position = screen_size / 2 - Vec2f(size.x * currentSX, size.y * currentSY);
            GUI::DrawPane(current_position - extra_size, current_position + Vec2f(size.x * currentSX * 2, size.y * currentSY * 2) + extra_size, SColor(255 * fade_in, 155, 85, 25));

            GUI::SetFont("Terminus_18");
            show_label = true;
        }
        
        GUI::DrawIcon(_paths_to_frames[current_frame], 0, size, current_position, currentSX, currentSY, SColor(255 * fade_in, 255, 255, 255));

        if (show_label)
        {
            GUI::DrawTextCentered(label, current_position + Vec2f(size.x * currentSX, 10), SColor(255 * fade_in, 255, 255, 255));
        }
    }

    void stop()
    {
        is_playing = false;
        current_frame = 0;
        render_time = 0;
        fade_in = 1.0f;
    }

    void hide()
    {
        is_rendering = false;
    }

    bool isPlaying()
    {
        return is_playing;
    }

    void rescale(Vec2f new_size)
    {
        scaleX = new_size.x / size.x;
        scaleY = new_size.y / size.y;
    }
    
    Vec2f rescaleSize(Vec2f new_size)
    {
        scaleX = new_size.x / size.x;
        scaleY = new_size.y / size.y;

        return Vec2f(size.x * scaleX, size.y * scaleY);
    }
}

void RenderShownVideos(VideoPlayer@[] &in help_videos, Vec2f[] &in positions, bool menu_open)
{
    CControls@ controls = getControls();
    if (controls is null) return;

    Vec2f mpos = controls.getInterpMouseScreenPos();
    for (uint i = 0; i < active_help_videos.size(); i++)
    {
        if (i >= active_help_videos.size()) break;
        if (i >= active_help_video_positions.size()) break;

        Vec2f pos = active_help_video_positions[i];
        Vec2f extra = Vec2f(active_help_videos[i].scaleX, active_help_videos[i].scaleY);

        Vec2f size = Vec2f(active_help_videos[i].size.x * extra.x * 2, active_help_videos[i].size.y * extra.y * 2);
        if (mpos.x >= pos.x && mpos.x <= pos.x + size.x &&
            mpos.y >= pos.y && mpos.y <= pos.y + size.y)
        {
            if (!active_help_videos[i].isPlaying())
            {
                active_help_videos[i].begin();
            }
        }
        else if (active_help_videos[i].isPlaying())
        {
            active_help_videos[i].stop();
        }
    }

    // run this in your onRender(CRules@) hook
    for (uint i = 0; i < help_videos.size(); i++)
    {
        if (i >= help_videos.size()) break;
        if (i >= positions.size()) break;
        
        help_videos[i].render(positions[i], menu_open);
    }
}