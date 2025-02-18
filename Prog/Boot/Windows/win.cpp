// Main classifier for a window

// Function to render in a taskbar GUI
// How the window manager works:
// All windows never change index within the table, but there is a "draw-over" function
// When a window is selected to be drawn over, its Z-index is raised
// There can only be one Z-index per window.
// When re-drawing a window, all windows above it must also be drawn again. 

#include "win.h"

void win_renderTaskBar() {
    // Draw the background
    win_fillrect(0, win_height - 42, win_width, win_height, 0x1A);
    win_update();
    return;
}

// A window has a Z-index, and out of all of them the highest Z-index wins
void win_redraw(uint16_t win_id) {
    if (!window_list[win_id].win_active) {
        return;
    }
    // Draw a basic box for now (0x16)
    uint16_t win_size_x = window_list[win_id].win_size_x;
    uint16_t win_size_y = window_list[win_id].win_size_y;

    uint16_t win_pos_x = window_list[win_id].win_pos_x;
    uint16_t win_pos_y = window_list[win_id].win_pos_y;
    // Render shadows
    win_fillrect(
        win_pos_x + window_shadow_offset_x,
        win_pos_y + win_size_y,
        win_pos_x + win_size_x + window_shadow_offset_x,
        win_pos_y + win_size_y + window_shadow_offset_y,
        0x11
    );
    win_fillrect(
        win_pos_x + win_size_x,
        win_pos_y + window_shadow_offset_y,
        win_pos_x + win_size_x + window_shadow_offset_x,
        win_pos_y + win_size_y + window_shadow_offset_y,
        0x11
    );
    win_fillrect(win_pos_x, win_pos_y, win_pos_x + win_size_x, win_pos_y + win_size_y, 0x18);

    // Render topbar (margin: 4px)
    win_fillrect(
        win_pos_x + window_margin,
        win_pos_y + window_margin,
        win_pos_x + win_size_x - window_margin,
        win_pos_y + window_margin + (16 + 6), // each character in title is 16px tall + 3 margin
        0x1D
    );

    // Render window root
    win_fillrect(
        win_pos_x + window_margin,
        win_pos_y + 2*window_margin + (16 + 6) + 1,
        win_pos_x + win_size_x - window_margin,
        win_pos_y + win_size_y - window_margin, // each character in title is 16px tall + 3 margin
        0x1D
    );
    // Render window title
    uint16_t x = win_pos_x + window_margin + 3;
    uint16_t y = win_pos_y + window_margin + 3;
    while (1) {
        char ch = *window_list[win_id].title++;
        if (ch == '\0') {
            break;
        }
        win_putchar(x,y,0,ch);
        x += 8;
    }

    return;
}

// Re-cast into uint16
int win_create(uint16_t p_x, uint16_t p_y, uint16_t s_x, uint16_t s_y, const char* title) {
    // Search for an avalible window
    int win_index = 0;
    for (uint16_t i = 0; i < 32; i++) {
        if (!window_list[i].win_active) {
            // found one, proceed
            window_list[i].win_active = true;
            window_list[i].win_pos_x = p_x;
            window_list[i].win_pos_y = p_y;
            window_list[i].win_size_x = s_x;
            window_list[i].win_size_y = s_y;
            window_list[i].title = title;
            return win_index;
        }
        win_index++;
    }
    return -1;
}