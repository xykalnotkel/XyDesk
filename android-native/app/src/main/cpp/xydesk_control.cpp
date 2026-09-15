#include "xydesk_control.h"

namespace {
int state = 0;
}

extern "C" const char* xydesk_control_protocol_version(void) {
    return "xydesk-control/1";
}

extern "C" const char* xydesk_control_state_name(void) {
    switch (state) {
        case 1: return "pairing";
        case 2: return "connected";
        case 3: return "streaming";
        case 4: return "stopped";
        default: return "idle";
    }
}

extern "C" void xydesk_control_set_state(int next_state) {
    state = next_state;
}
