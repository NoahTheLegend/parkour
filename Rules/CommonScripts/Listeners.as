void menuSwitchListener(int x, int y, int button, IGUIItem@ sender)
{
    if (sender is null) return;
    
    showMenu = !showMenu;
}

void infoHoverListener(bool hover, IGUIItem@ item)
{
	if (item is null) return;

    Button@ button = cast<Button@>(item);
    if (button is null) return;

    button.setToolTip(hover ? "todo" : "", 1, SColor(255, 255, 255, 255));
}