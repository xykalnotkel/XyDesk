#include "xydesk_audio.h"

extern "C" const char* xydesk_audio_backend_name(void) {
    return "android-audiotrack-webrtc";
}

extern "C" int xydesk_audio_sample_rate(void) {
    return 48000;
}

extern "C" int xydesk_audio_channel_count(void) {
    return 2;
}

extern "C" int xydesk_audio_frame_samples(void) {
    return 960;
}
