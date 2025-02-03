#include "win.h"
#include "stdint.h"
#include "stdio.h"

#include "win.cpp"

void testmouse() {
    return;
}

// Set-up a taskbar and render that
extern "C" void win_init() {
    win_fillrect(50,50,100,100,0xD);
    //mouse_left_handler = testmouse;
    uint32_t a = malloc(50000);
    free(a, 50000);
    win_renderTaskBar();
    win_redraw();
    return;
}