#include "stdint.h"
#define ALERT 0
#define BITMAP 1
#define NOTIF 2

typedef void (*MouseHandler)();
void win_redraw();
extern uint16_t win_width;
extern uint16_t win_height;
extern uint16_t mouse_abs_x;
extern uint16_t mouse_abs_y;

extern uint16_t mouse;
extern MouseHandler mouse_left_handler; // ptr


// Positioned absolute from window corner, areas that a user can click for an action
// Actions:
//  0x0: Inactive
//  0x1: Window Destroy
//  0x2: Call "func"
struct win_context {
    uint16_t btn_pos_x;
    uint16_t btn_pos_y;
    uint16_t btn_size_x;
    uint16_t btn_size_y;
    uint32_t func; // ptr
    uint8_t action;
} __attribute__ ((packed));

struct window_root {
    uint16_t win_pos_x;
    uint16_t win_pos_y;
    uint16_t win_size_x;
    uint16_t win_size_y;
    uint16_t win_id;
    bool selected;
    bool win_active;
    bool dragging;
    const char* title; // pointer
    const char* details; // re-usable text
    uint32_t bmp_ptr; // main ptr to window bitmap
    uint32_t type;
    uint8_t context_cnt;
    struct win_context *context_enum; // ptr to string with these things. LIMIT TO 16 FOR NOW
} __attribute__ ((packed));

window_root window_list[32];

uint16_t window_shadow_offset_x = 3;
uint16_t window_shadow_offset_y = 3;

uint16_t window_margin = 4;

uint16_t dragging_window = 0;
signed short drag_start_x;
signed short drag_start_y;

uint16_t box_size = 2;

uint16_t win_err_padding = 15; // 15px