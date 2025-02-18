#include "stdint.h"
#include "stdio.h"
#include "input.cpp"

#include "win.cpp"

void testmouse() {
    return;
}

// Set-up a taskbar and render that
extern "C" void win_init() {
    //win_fillrect(50,50,100,100,0xD);
    //mouse_left_handler = testmouse;
    uint32_t a = malloc(50000);
    free(a, 50000);
    win_renderTaskBar();
    win_redraw(win_create(40,60,300,200,"Testing!"));
    win_redraw(win_create(140,160,300,200,"Woah!1!"));
    win_update();
    return;
}