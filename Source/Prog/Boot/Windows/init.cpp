#include "stdint.h"
#include "stdio.h"
#include "win.cpp"
#include "input.cpp"

void testmouse() {
    return;
}

void update_win() {
    return;
}

void testProcess() {
    uint16_t winb = win_create(140,160,200,200,BITMAP,"Rainbow");

    // Fill a window as a test
    uint32_t ptr_offset = 0;
    uint8_t* buffer = (uint8_t*)window_list[winb].bmp_ptr;
    for (uint16_t px = 0;px<200;px++) {
        for (uint16_t py = 0;py<200;py++) {
            buffer[ptr_offset] = px;
            ptr_offset++;
        }
    }
    win_redraw(winb);
    win_update();
    while (1) {
        Yield();
    }
}

uint16_t win_meme_x = 50;
uint16_t win_meme_y = 50;
uint32_t max_ind = 0;
void pushError() {
    if (max_ind % 32 == 0) {
        //win_fillrect(50+win_meme_x, 50+win_meme_y,100+win_meme_x,100+win_meme_y,0xc);
        char alertmsg[] = "Fatal error occoured.\nPlease re-start immediatly.\0Accept"; // terminate warning, then the prompt
        win_redraw(win_create(win_meme_x,win_meme_y,200,150,ALERT,"Fatal Sys Err.",alertmsg));
        win_update();
        win_meme_x += 100;
        win_meme_y += 50;
    }
    max_ind++;
    return;
}

// Set-up a taskbar and render that
extern "C" void win_init() {
    //win_fillrect(50,50,100,100,0xD);
    //mouse_left_handler = testmouse;
    uint32_t a = malloc(50000);
    free(a, 50000);
    win_renderTaskBar();
    win_redraw(win_create(40,60,300,200,BITMAP,"Testing!"));

    char alertmsg[] = "There was an illegal error found on this pc.\nPlease restart immediatly.\0Accept"; // terminate warning, then the prompt
    win_redraw(win_create(100,100,200,150,ALERT,"Warning!",alertmsg));

    win_update();
    pit_reg(*pushError);
    proc_reg(*testProcess);
    //proc_reg(*pushError);
    while (1) {
        Yield();
    }
    return;
}
