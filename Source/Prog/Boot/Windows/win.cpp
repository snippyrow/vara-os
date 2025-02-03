// Main classifier for a window

// Function to render in a taskbar GUI
void win_renderTaskBar() {
    // Draw the background
    win_fillrect(0, win_height - 42, win_width, win_height, 0x80);
    win_redraw();
    return;
}