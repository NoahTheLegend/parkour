
void onTick(CBlob@ this)
{
    if (this.exists("_support") && this.getTickSinceCreated() >= 1)
    {
        if (!this.getShape().isStatic())
        {
            return;
        }

        int support = this.get_s32("_support");
        this.getShape().getConsts().support = support;
        this.getCurrentScript().runFlags |= Script::remove_after_this;
    }
}