
// sets a client message for generic purposes
void SetClientMessage(u16 pid, string msg)
{
    if (!isServer()) return;
    if (pid == 0) return;

    CRules@ rules = getRules();
    if (rules is null) return;

    CPlayer@ p = getPlayerByNetworkId(pid);
    if (p is null) return;

    CBitStream params;
    params.write_u16(pid);
    params.write_string(msg);
    rules.SendCommand(rules.getCommandID("set_client_message"), params, p);
}

// wraps text to fit within max_width using the specified font
string wrapText(const string &in msg, f32 max_width, const string &in font = "Terminus_14")
{
    GUI::SetFont(font);

    // word wrap: insert newlines so no line exceeds max_width
    string wrapped = "";
    string line = "";
    array<string> words = msg.split(" ");

    for (uint i = 0; i < words.length(); ++i)
    {
        string word = words[i];
        string test_line = line + (line == "" ? "" : " ") + word;

        Vec2f dim;
        GUI::GetTextDimensions(test_line, dim);

        if (dim.x > max_width && line != "")
        {
            wrapped += line + "\n";
            line = word;

            // check if the word itself is too long for a single line
            Vec2f word_dim;
            GUI::GetTextDimensions(word, word_dim);

            while (word_dim.x > max_width)
            {
                // Find the max substring that fits
                int split_pos = word.length();
                for (int j = 1; j < word.length(); ++j)
                {
                    string sub = word.substr(0, j);

                    Vec2f sub_dim;
                    GUI::GetTextDimensions(sub + "-", sub_dim);

                    if (sub_dim.x > max_width)
                    {
                        split_pos = j - 1;
                        break;
                    }
                }

                if (split_pos <= 0) break;
                string part = word.substr(0, split_pos) + "-";

                wrapped += part + "\n";
                word = word.substr(split_pos);

                GUI::GetTextDimensions(word, word_dim);
            }

            line = word;
        }
        else
        {
            // If the word itself is too long for a single line (first word in line)
            Vec2f word_dim;
            GUI::GetTextDimensions(word, word_dim);

            if (word_dim.x > max_width)
            {
                while (word_dim.x > max_width)
                {
                    int split_pos = word.length();
                    for (int j = 1; j < word.length(); ++j)
                    {
                        string sub = word.substr(0, j);
                        Vec2f sub_dim;
                        GUI::GetTextDimensions(sub + "-", sub_dim);
                        if (sub_dim.x > max_width)
                        {
                            split_pos = j - 1;
                            break;
                        }
                    }

                    if (split_pos <= 0) break;
                    string part = word.substr(0, split_pos) + "-";

                    if (line != "")
                    {
                        wrapped += line + "\n";
                        line = "";
                    }

                    wrapped += part + "\n";
                    word = word.substr(split_pos);

                    GUI::GetTextDimensions(word, word_dim);
                }

                line = word;
            }
            else
            {
                line = test_line;
            }
        }
    }

    wrapped += line;
    return wrapped;
}

// encodes a single coordinate (-MAX_POS..+MAX_POS) to u16 (0..65535)
u16 EncodeCoord(f32 value)
{
    if (value < -MAX_POS) value = -MAX_POS;
    if (value >  MAX_POS) value =  MAX_POS;
    f32 norm = (value + MAX_POS) / (2.0f * MAX_POS);
    return u16(Maths::Round(norm * 65535.0f));
}

// decodes a u16 (0..65535) back to coordinate (-MAX_POS..+MAX_POS)
f32 DecodeCoord(u16 encoded)
{
    f32 norm = f32(encoded) / 65535.0f;
    return norm * (2.0f * MAX_POS) - MAX_POS;
}

// packs a Vec2f into u32 (16 bits x, 16 bits y)
u32 PackVec2f(const Vec2f &in pos)
{
    u16 ex = EncodeCoord(pos.x);
    u16 ey = EncodeCoord(pos.y);
    return (u32(ex) << 16) | u32(ey);
}

// unpacks a u32 back to Vec2f
Vec2f UnpackVec2f(u32 packed)
{
    u16 ex = u16((packed >> 16) & 0xFFFF);
    u16 ey = u16(packed & 0xFFFF);
    return Vec2f(DecodeCoord(ex), DecodeCoord(ey));
}

bool hasSupport(Vec2f pos)
{
    CMap@ map = getMap();
    if (map is null) return false;

    Vec2f[] directions;
    directions.push_back(Vec2f(-map.tilesize, 0));
    directions.push_back(Vec2f(map.tilesize, 0));
    directions.push_back(Vec2f(0, -map.tilesize));
    directions.push_back(Vec2f(0, map.tilesize));

    for (uint d = 0; d < directions.length; ++d)
    {
        Vec2f adj = pos + directions[d];
        Tile adjTile = map.getTile(adj);

        for (uint s = 0; s < support_tiles.length; ++s)
        {
            if (adjTile.type == support_tiles[s])
                return true;
        }
    }

    return false;
}

// returns the sum of all elements in the array
float sum(array<float>@ arr)
{
    float s = 0.0f;
    for (uint i = 0; i < arr.size(); i++) s += arr[i];
    return s;
}