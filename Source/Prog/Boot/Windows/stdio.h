#include "stdint.h"

extern "C" void win_fillrect(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint8_t color);
extern "C" uint32_t malloc(uint32_t nbytes);
extern "C" void free(uint32_t ptr, uint32_t nbytes);
extern "C" void _fread_raw(uint32_t cluster, uint32_t buffer, uint32_t maxcluster);

struct fat_object {
    char o_name[12];
    char o_ext[3];
    uint8_t attributes;
    uint32_t cluster;
    uint32_t modified;
    uint32_t created;
    uint32_t o_size;
} __attribute__ ((packed));