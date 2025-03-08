
extern "C" void mouse_move() {
    if (!window_list[dragging_window].dragging) {
        return;
    }
    uint16_t taskbar_height = 16 + (2 * 3) + (3 * window_margin); // compute taskbar height

    uint16_t win_pos_x = window_list[dragging_window].win_pos_x;
    uint16_t win_pos_y = window_list[dragging_window].win_pos_y;

    uint16_t win_s_x = window_list[dragging_window].win_size_x;
    uint16_t win_s_y = window_list[dragging_window].win_size_y;
    // render a preview
    // Just do it over the frame buffer without needing the work buffer
    // Left rectangle
    win_rawfillrect(
        mouse_abs_x,
        mouse_abs_y,
        mouse_abs_x + box_size,
        mouse_abs_y + win_s_y + taskbar_height,
        0x0
    );
    win_rawfillrect(
        mouse_abs_x,
        mouse_abs_y + win_s_y + taskbar_height,
        mouse_abs_x + win_s_x,
        mouse_abs_y + win_s_y + box_size + taskbar_height,
        0x0
    );
    win_rawfillrect(
        mouse_abs_x + win_s_x,
        mouse_abs_y + box_size,
        mouse_abs_x + win_s_x + box_size,
        mouse_abs_y + win_s_y + taskbar_height,
        0x0
    );
    win_rawfillrect(
        mouse_abs_x + box_size,
        mouse_abs_y,
        mouse_abs_x + win_s_x + box_size,
        mouse_abs_y + box_size,
        0x0
    );

    return;
}

void win_select(uint16_t winid) {
    for (uint16_t i=0;i<32;i++) {
        if (i == winid) {
            window_list[i].selected = true;
        } else {
            window_list[i].selected = false;
        }
    }
}

extern "C" void mouse_left_up() {
    // Check if there is a window to drag
    if (!window_list[dragging_window].dragging) {
        return;
    }
    uint16_t taskbar_height = 16 + (2 * 3) + (3 * window_margin); // compute taskbar height
    // Black out the old window location
    win_fillrect(
        window_list[dragging_window].win_pos_x,
        window_list[dragging_window].win_pos_y,
        window_list[dragging_window].win_pos_x + window_list[dragging_window].win_size_x + window_shadow_offset_x * 4,
        window_list[dragging_window].win_pos_y + window_list[dragging_window].win_size_y + window_shadow_offset_y + taskbar_height,
        0xAF
    );
    // Calculate new coordinates
    window_list[dragging_window].win_pos_x = mouse_abs_x;
    window_list[dragging_window].win_pos_y = mouse_abs_y;
    window_list[dragging_window].dragging = false;
    win_redraw(dragging_window);
    win_update();
    return;
}

extern "C" void mouse_left_down() {
    // Check for an intersection of all window topbars
    // Window topbar is the width of the window - the size of the close button, and is the window margin + 22px tall
    for (uint16_t win_id = 0;win_id<32;win_id++) {
        // Rectangular collision
        uint16_t win_size_x = window_list[win_id].win_size_x;
        uint16_t win_size_y = window_list[win_id].win_size_y;

        uint16_t win_pos_x = window_list[win_id].win_pos_x;
        uint16_t win_pos_y = window_list[win_id].win_pos_y;

        // First, check if the user clicked a button on a window
        if ((mouse_abs_x > win_pos_x) && (mouse_abs_x < (win_pos_x + win_size_x))) {
            if ((mouse_abs_y > win_pos_y) && (mouse_abs_y < (win_pos_y + window_margin + 22))) {
                // Mouse has collided, select window and begin to drag
                win_select(win_id);
                window_list[win_id].dragging = true;
                dragging_window = win_id;
                drag_start_x = mouse_abs_x;
                drag_start_y = mouse_abs_y;
                break;
            }
        }
    }

    win_update();
    return;
}