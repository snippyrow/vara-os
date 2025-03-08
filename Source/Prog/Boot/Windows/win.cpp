// Main classifier for a window

// Function to render in a taskbar GUI
// How the window manager works:
// All windows never change index within the table, but there is a "draw-over" function
// When a window is selected to be drawn over, its Z-index is raised
// There can only be one Z-index per window.
// When re-drawing a window, all windows above it must also be drawn again. 

// Calculate topbar size as 16px char height + 3px top/down margin, with the window margin on all sides

#include "win.h"

void win_renderTaskBar() {
    // Draw the background
    win_fillrect(0, win_height - 42, win_width, win_height, 0x1A);
    win_update();
    return;
}

void _redraw_bitmap(uint16_t win_id) {
    uint16_t taskbar_height = 16 + (2 * 3) + (3 * window_margin); // compute taskbar height
    
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
        win_pos_y + win_size_y + taskbar_height,
        win_pos_x + win_size_x + window_shadow_offset_x + (2 * window_margin),
        win_pos_y + win_size_y + window_shadow_offset_y + taskbar_height,
        0x11
    );
    win_fillrect(
        win_pos_x + win_size_x + (2 * window_margin),
        win_pos_y + window_shadow_offset_y,
        win_pos_x + win_size_x + window_shadow_offset_x + (2 * window_margin),
        win_pos_y + win_size_y + window_shadow_offset_y + taskbar_height,
        0x11
    );
    // render core window bg
    win_fillrect(
        win_pos_x,
        win_pos_y,
        win_pos_x + win_size_x + (2 * window_margin),
        win_pos_y + win_size_y + taskbar_height,
        0x18
    );

    // Draw in bitmap as window root
    uint32_t ptr_offset = 0;
    uint8_t* buffer = (uint8_t*)window_list[win_id].bmp_ptr;
    for (uint16_t px = 0;px<win_size_x;px++) {
        for (uint16_t py = 0;py<win_size_y;py++) {
            uint8_t pc = buffer[ptr_offset];
            win_putpixel(win_pos_x + window_margin + 1 + px, win_pos_y + 2*window_margin + (16 + 6) + 1 + py, pc);
            ptr_offset++;
        }
    }

    // Render topbar (margin: 4px)
    win_fillrect(
        win_pos_x + window_margin,
        win_pos_y + window_margin,
        win_pos_x + win_size_x + window_margin,
        win_pos_y + window_margin + (16 + 6), // each character in title is 16px tall + 3 margin
        0x1D
    );

    // Render window title
    uint16_t x = win_pos_x + window_margin + 3;
    uint16_t y = win_pos_y + window_margin + 3;
    uint32_t index = 0;
    while (1) {
        char ch = window_list[win_id].title[index];
        if (ch == '\0') {
            break;
        }
        win_putchar(x,y,0,ch);
        x += 8;
        index++;
    }

    return;
}

void _redraw_alert(uint16_t win_id) {
    uint16_t taskbar_height = 16 + (2 * 3) + (3 * window_margin); // compute taskbar height
    
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
        win_pos_y + win_size_y + taskbar_height,
        win_pos_x + win_size_x + window_shadow_offset_x + (2 * window_margin),
        win_pos_y + win_size_y + window_shadow_offset_y + taskbar_height,
        0x11
    );
    win_fillrect(
        win_pos_x + win_size_x + (2 * window_margin),
        win_pos_y + window_shadow_offset_y,
        win_pos_x + win_size_x + window_shadow_offset_x + (2 * window_margin),
        win_pos_y + win_size_y + window_shadow_offset_y + taskbar_height,
        0x11
    );
    // render core window bg
    win_fillrect(
        win_pos_x,
        win_pos_y,
        win_pos_x + win_size_x + (2 * window_margin),
        win_pos_y + win_size_y + taskbar_height,
        0x18
    );

    // Render topbar (margin: 4px)
    win_fillrect(
        win_pos_x + window_margin,
        win_pos_y + window_margin,
        win_pos_x + win_size_x + window_margin,
        win_pos_y + window_margin + (16 + 6), // each character in title is 16px tall + 3 margin
        0x1D
    );

    // Render root area
    win_fillrect(
        win_pos_x + window_margin,
        win_pos_y + taskbar_height,
        win_pos_x + win_size_x + window_margin,
        win_pos_y + win_size_y + taskbar_height - window_margin, // each character in title is 16px tall + 3 margin
        0x1D
    );

    // Draw error text field
    uint32_t index = 0;
    uint16_t x_offset = win_pos_x + window_margin + win_err_padding;
    uint16_t y_offset = win_pos_y + taskbar_height + win_err_padding;
    while (1) {
        char ch = window_list[win_id].details[index];
        if (ch == '\0') {
            break;
        } else if (ch == '\n') {
            x_offset = win_pos_x + window_margin + win_err_padding;
            y_offset += 16;
        } else {
            win_putchar(x_offset,y_offset,0,ch);
            x_offset += 8;
        }
        index++;
    }


    // Render window title
    uint16_t x = win_pos_x + window_margin + 3;
    uint16_t y = win_pos_y + window_margin + 3;
    index = 0;
    while (1) {
        char ch = window_list[win_id].title[index];
        if (ch == '\0') {
            break;
        }
        win_putchar(x,y,0,ch);
        x += 8;
        index++;
    }

    // Render in "OK" button
    
    // Find when the prompt begins
    index = 0;
    while (window_list[win_id].details[index] != '\0') {
        index++; // loop until null
    }
    index++;
    if (window_list[win_id].details[index] == '\0') {
        return; // if no prompt, do not render a close button
    }

    // Loop again to find the length of the prompt
    // Save start index
    uint32_t index_p = index;
    uint32_t p_len = 0;
    while (window_list[win_id].details[index] != '\0') {
        index++; // loop until null
        p_len++;
    }

    uint16_t btn_width = (p_len * 8) + 10;
    uint16_t btn_height = 24;
    uint16_t button_y = 54;
    uint16_t accept_padding = (win_size_x / 2) - (btn_width / 2) + window_margin;
    uint16_t accept_padding_inner = 3;
    // Render button solid border
    win_fillrect(
        win_pos_x + accept_padding,
        win_pos_y + taskbar_height + win_size_y - 15 - btn_height,
        win_pos_x + accept_padding + btn_width,
        win_pos_y + taskbar_height + win_size_y - 15,
        0x18
    );

    win_fillrect(
        win_pos_x + accept_padding + accept_padding_inner,
        win_pos_y + taskbar_height + win_size_y - 15 - btn_height + accept_padding_inner,
        win_pos_x + accept_padding + btn_width - accept_padding_inner,
        win_pos_y + taskbar_height + win_size_y - 15 - accept_padding_inner,
        0x1D
    );

    // Draw text
    // Allign text to inner button
    x = win_pos_x + accept_padding + accept_padding_inner + 3;
    y = win_pos_y + taskbar_height + win_size_y - 15 - btn_height + accept_padding_inner + 1;
    while (1) {
        char ch = window_list[win_id].details[index_p];
        if (ch == '\0') {
            break;
        }
        win_putchar(x,y,0,ch);
        x += 8;
        index_p++;
    }

    return;
}

// A window has a Z-index, and out of all of them the highest Z-index wins
void win_redraw(uint16_t win_id) {
    if (window_list[win_id].type == BITMAP) {
        _redraw_bitmap(win_id);
    } else if (window_list[win_id].type == ALERT) {
        _redraw_alert(win_id);
    }
    return;
}

// Re-cast into uint16
// Type is uint32 for allignment
int win_create(uint16_t p_x, uint16_t p_y, uint16_t s_x, uint16_t s_y, uint32_t type, const char* title, const char* text = 0) {
    // Search for an avalible window
    int win_index = 0;
    uint16_t taskbar_height = 16 + (2 * 3) + (3 * window_margin); // compute taskbar height
    for (uint16_t i = 0; i < 32; i++) {
        if (!window_list[i].win_active) {

            // found one, proceed
            window_list[i].win_active = true;
            window_list[i].win_pos_x = p_x;
            window_list[i].win_pos_y = p_y;
            window_list[i].win_size_x = s_x;
            window_list[i].win_size_y = s_y;
            window_list[i].title = title;
            window_list[i].type = type;
            window_list[i].details = text;

            // Modify size if an alert window
            if (type == ALERT) {
                uint16_t len = 0;
                uint16_t box_width = 0;
                uint16_t max_box_width = 0;
                while (window_list[i].details[len] != '\0') {
                    box_width++;
                    if (window_list[i].details[len] == '\n') {
                        box_width = 0;
                    }
                    if (max_box_width < box_width) {
                        max_box_width++;
                    }
                    len++;
                }
                window_list[i].win_size_x = (max_box_width * 8) + (2 * win_err_padding);
                window_list[i].win_size_y = 30 + (2 * win_err_padding);
                len = 0;
                while (window_list[i].details[len] != '\0') {
                    if (window_list[i].details[len] == '\n') {
                        window_list[i].win_size_y += 16;
                    }
                    len++;
                }
                window_list[i].win_size_y += 16;


                // Create a context button based on length of the prompt
                len++;
                if (len > 0 && window_list[i].details[len] == '\0') {
                    return win_index; // if no prompt, do not render a close button
                }
                // Define a button width
                uint16_t btn_width = 10;
                while (window_list[i].details[len] != '\0') {
                    btn_width += 8;
                    len++;
                }
                // Compute position
                uint16_t btn_height = 24;
                uint16_t btn_x = (window_list[i].win_size_x / 2) - (btn_width / 2) + window_margin;
                uint16_t btn_y = p_y + window_list[i].win_size_y + taskbar_height - 15 - btn_height;
                window_list[i].context_enum[0] = {btn_x,btn_y,btn_width,btn_height,0,0x1}; // add a single button context
            } else {
                // Otherwise create a null button
                window_list[i].context_enum[0] = {0,0,0,0,0,0x0};
                // Assign a bitmap
                // Allocate space for the window bitmap
                uint32_t ptr = malloc(s_x * s_y);
                if (!ptr) { // failed
                    return -2;
                }
                window_list[i].bmp_ptr = ptr;
            }
            return win_index;
        }
        win_index++;
    }
    return -1;
}