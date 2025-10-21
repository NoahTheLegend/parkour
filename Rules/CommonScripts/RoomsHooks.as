
// called after creating a room for player assistance
void onRoomCreated(CRules@ this, u8 level_type, uint level_id, u16 pid)
{
    if (pid == 0) return; // server

    CPlayer@ p = getPlayerByNetworkId(pid);
    if (p is null) return;

    CBlob@ player_blob = p.getBlob();
    string new_blob_name = level_type == RoomType::builder ? "builder" : level_type == RoomType::archer ? "archer" : "knight";

    CBlob@[] bs;
    getBlobsByTag("owner_tag_" + pid, @bs);

    CBlob@ target = bs.length > 0 ? bs[0] : null;
    Vec2f pos = target !is null ? target.getPosition() : player_blob !is null ? player_blob.getPosition() : Vec2f(0, 0);

    // skip if player has correct class already
    if (player_blob !is null && player_blob.getName() == new_blob_name) return;
    CBlob@ new_blob = server_CreateBlob(new_blob_name, p.getTeamNum(), pos);

    if (new_blob !is null) new_blob.server_SetPlayer(p);
    if (player_blob !is null) player_blob.server_Die();
}

// temporary mesh fix for staging, todo: remove after fix
void SetMesh()
{
    CMap@ map = getMap();
    if (map is null) return;

    // temp fix - make 2x2 areas
    Vec2f top_left = Vec2f_zero;
    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 0; iy < 2; iy++)
        {
            Vec2f p = top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            map.server_SetTile(p, filler_tile);
        }
    }

    Vec2f bottom_left = Vec2f(0, map.tilemapheight - 2) * map.tilesize;
    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 0; iy < 2; iy++)
        {
            Vec2f p = bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            map.server_SetTile(p, filler_tile);
        }
    }
}

void FixMesh()
{
    CMap@ map = getMap();
    if (map is null) return;

    // break placed corners
    Vec2f top_left = Vec2f_zero;
    Vec2f bottom_left = Vec2f(0, map.tilemapheight - 2) * map.tilesize;

    Vec2f copy_top_left = Vec2f(3, 0) * map.tilesize;
    Vec2f copy_bottom_left = Vec2f(3, map.tilemapheight - 2) * map.tilesize;

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 0; iy < 2; iy++)
        {
            Vec2f src = copy_top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Vec2f dst = top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Tile t = map.getTile(src);
            map.server_SetTile(dst, t.type);
        }
    }

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 0; iy < 2; iy++)
        {
            Vec2f src = copy_bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Vec2f dst = bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Tile t = map.getTile(src);
            map.server_SetTile(dst, t.type);
        }
    }

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 1; iy < 2; iy++)
        {
            Vec2f p = top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            map.server_SetTile(p, filler_tile);
        }
    }

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 1; iy < 2; iy++)
        {
            Vec2f p = bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            map.server_SetTile(p, filler_tile);
        }
    }

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 1; iy < 2; iy++)
        {
            Vec2f src = copy_top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Vec2f dst = top_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Tile t = map.getTile(src);
            map.server_SetTile(dst, t.type);
        }
    }

    for (int ix = 0; ix < 2; ix++)
    {
        for (int iy = 1; iy < 2; iy++)
        {
            Vec2f src = copy_bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Vec2f dst = bottom_left + Vec2f(ix * map.tilesize, iy * map.tilesize);
            Tile t = map.getTile(src);
            map.server_SetTile(dst, t.type);
        }
    }
}