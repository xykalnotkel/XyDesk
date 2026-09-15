#include <jni.h>
#include <string>

#include "xydesk_audio.h"
#include "xydesk_control.h"
#include "xydesk_streamer.h"

extern "C" JNIEXPORT jstring JNICALL
Java_com_xystudio_xydesk_nativeclient_NativeCore_nativeSnapshot(JNIEnv* env, jclass) {
    std::string value = "control=";
    value += xydesk_control_protocol_version();
    value += "; state=";
    value += xydesk_control_state_name();
    value += "; media=";
    value += xydesk_streamer_backend_name();
    value += "; mediaState=";
    value += xydesk_streamer_state_name();
    value += "; audio=";
    value += xydesk_audio_backend_name();
    value += "; pcm=";
    value += std::to_string(xydesk_audio_sample_rate());
    value += "Hz/";
    value += std::to_string(xydesk_audio_channel_count());
    value += "ch/";
    value += std::to_string(xydesk_audio_frame_samples());
    value += "samples";
    return env->NewStringUTF(value.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_com_xystudio_xydesk_nativeclient_NativeCore_nativeSetSessionState(
    JNIEnv*, jclass, jint state) {
    xydesk_control_set_state(state);
    xydesk_streamer_set_state(state);
}
