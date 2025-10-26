#define SERVER_ONLY

void onTick(CBlob@ this)
{
    if (!this.hasTag("room_loader_init"))
    {
        this.Tag("room_loader_init");
        f32 grav = this.getShape().getGravityScale();

        this.set_f32("_old_gravity", grav);
        this.getShape().SetGravityScale(0.0f);
    }

    if (this.exists("spawn_position") && !this.hasTag("room_loader_done"))
    {
        Vec2f spawn_pos = this.get_Vec2f("spawn_position");
        if (spawn_pos != Vec2f_zero && this.getPosition() != spawn_pos)
        {
            this.setPosition(spawn_pos);
        }
    }

    if (this.hasTag("room_loader_done"))
    {
        this.getShape().SetGravityScale(this.get_f32("_old_gravity"));
        this.getCurrentScript().runFlags |= Script::remove_after_this;
    }
}