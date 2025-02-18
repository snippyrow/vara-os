#include "stdint.h"

typedef void (*MouseHandler)();
void win_redraw();
extern uint16_t win_width;
extern uint16_t win_height;
extern uint16_t mouse_abs_x;
extern uint16_t mouse_abs_y;

extern uint16_t mouse;
extern MouseHandler mouse_left_handler; // ptr

struct window_root {
    uint16_t win_pos_x;
    uint16_t win_pos_y;
    uint16_t win_size_x;
    uint16_t win_size_y;
    uint8_t z_index;
    uint16_t win_id;
    bool win_selected;
    bool win_active;
    const char* title; // pointer
    uint8_t win_menu;
} __attribute__ ((packed));

window_root window_list[32];

uint16_t window_shadow_offset_x = 3;
uint16_t window_shadow_offset_y = 3;

uint16_t window_margin = 4;