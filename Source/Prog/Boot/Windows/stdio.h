#include "stdint.h"

extern "C" void win_fillrect(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint8_t color);
extern "C" void win_rawfillrect(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint8_t color);
extern "C" void win_putchar(uint16_t x0, uint16_t y0, uint8_t color, char ch);
extern "C" uint32_t malloc(uint32_t nbytes);
extern "C" void free(uint32_t ptr, uint32_t nbytes);
extern "C" void _fread_raw(uint32_t cluster, uint32_t buffer, uint32_t maxcluster);
extern "C" void win_putpixel(uint16_t x, uint16_t y, uint8_t color);
extern "C" void pit_reg(void (*fptr)());
extern "C" void win_update();
extern "C" void Yield();
extern "C" uint32_t proc_reg(void (*fptr)()); // returns PID

extern "C" void mouse_left_down();
extern "C" void mouse_left_up();
extern "C" void mouse_move();

extern "C" uint16_t mouse_abs_x;
extern "C" uint16_t mouse_abs_y;

struct fat_object {
    char o_name[12];
    char o_ext[3];
    uint8_t attributes;
    uint32_t cluster;
    uint32_t modified;
    uint32_t created;
    uint32_t o_size;
} __attribute__ ((packed));