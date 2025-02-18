
extern "C" void mouse_move() {
    //win_fillrect(50,50,100,100,0xc);
    //win_update();
    return;
}

extern "C" void mouse_left() {
    win_fillrect(50,50,100,100,0xc);
    win_update();
    return;
}