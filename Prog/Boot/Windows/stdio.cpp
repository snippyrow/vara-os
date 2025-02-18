// Main functions to read a file using the kernel
// First, generate something called an FPTR (file pointer) which is really just the starting raw cluster of the file, found by using a normal string directory/file name.
// Afterwards, to read a file simply pass in the buffer destination, how many bytes you need and the FPTR

// For searching the RAW directory structure, share a large malloc at the fget function
#include "stdint.h"

// Search for a file with a string, find the file ptr (cluster start), then read

// _fread_raw(cluster, ptr destination, max clusters to read);

// Probably re-do later
uint32_t fget(const char *fname) {
    // Recursivly search each directory from root
    // The first item should not have a '/' at the start
    uint32_t index = fname;
    uint32_t cc = 0; // current cluster
    uint32_t dirarchive = malloc(32 * 64) // 64 files to scan per subdirectory
    while (1) {
        uint32_t splitpos = strsplit(fname + index, '/');
        if (!fname[splitpos + index]) { // if the end

        } else {
            // Search for the new file, if not found, error, otherwise update and resume
            _fread_raw(cc, dirarchive, 2) // read currect cluster, to the buffer, with 2048B (2 clusters)
            fat_object* dir_list = (fat_object*)dirarchive;
            // Loop through until two names match

        }
        index += splitpos;
    }
    return 0;
}

int strcmp(const char *a, const char *b) {
    while (1) {
        char ch1 = *a++;
        char ch2 = *b++;
        int diff = ch1 - ch2;
        if (ch1 == '\0' || diff != 0) {
            return diff;
        }
    }
}

// returns position of split
// return 0 if none found
uint32_t strsplit(const char *a, char splitter) {
    uint32_t n = 0;
    while(1) {
        char ch = *a++;
        if (ch == '\0' || ch == splitter) {
            return n;
        }
        n++;
    }
}