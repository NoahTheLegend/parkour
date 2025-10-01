
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
    }

    void cachePaths()
    {
        // store all absolute paths to frames to optimize future access
        for (uint i = 0; i < 512; i++)
        {
            string formatted = ("000" + i).substr((("000" + i).length() - 3), 3);
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
    }

    void render(Vec2f screen_position) // 1 tick = 30 units
    {
        if (is_playing && is_rendering)
        {
            // render_time is adding up to 1.0f to trigger a frame change with any fpslimit set
            f32 tick = f32(30.0f / speed) / 30.0f;

	        #ifdef STAGING
	        tick = Maths::Max(1, f32(v_fpslimit / speed) / 30.0f);
	        #endif

            render_time += 1.0f / tick;
            if (render_time >= 1)
            {
                current_frame += int(render_time);
                render_time = 0;
            }

            if (current_frame >= total_frames)
            {
                current_frame = 0;
            }
        }
        else current_frame = 0;

        if (!is_rendering) return;

        // draw decoration bg pane
        Vec2f extra_size = Vec2f(2, 2);
        GUI::DrawPane(screen_position - extra_size, screen_position + size * Vec2f(scaleX, scaleY) + extra_size, SColor(255, 155, 55, 25));
        GUI::DrawIcon(_paths_to_frames[current_frame], 0, size, screen_position, scaleX, scaleY);
    }

    void stop()
    {
        is_playing = false;
        current_frame = 0;
        render_time = 0;
    }

    void hide()
    {
        is_rendering = false;
        stop();
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
}

void RenderShownVideos(VideoPlayer@[] &in help_videos, Vec2f[] &in positions)
{
    // run this in your onRender(CRules@) hook
    for (uint i = 0; i < help_videos.size(); i++)
    {
        if (i >= help_videos.size()) break;
        if (i >= positions.size()) break;
        
        help_videos[i].render(positions[i]);
    }
}