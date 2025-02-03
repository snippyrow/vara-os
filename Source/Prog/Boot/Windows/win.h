#include "stdint.h"

typedef void (*MouseHandler)();
extern "C" void win_redraw();
extern uint16_t win_width;
extern uint16_t win_height;
extern uint16_t mouse_abs_x;
extern uint16_t mouse_abs_y;

extern uint16_t mouse;
extern MouseHandler mouse_left_handler; // ptr