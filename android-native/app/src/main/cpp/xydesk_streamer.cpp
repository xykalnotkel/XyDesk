#include "xydesk_streamer.h"

namespace {
int state = 0;
}

extern "C" const char* xydesk_streamer_backend_name(void) {
    return "libwebrtc-native";
}

extern "C" const char* xydesk_streamer_state_name(void) {
    switch (state) {
        case 1: return "preparing";
        case 2: return "connected";
        case 3: return "streaming";
        case 4: return "stopped";
        default: return "idle";
    }
}

extern "C" void xydesk_streamer_set_state(int next_state) {
    state = next_state;
}
