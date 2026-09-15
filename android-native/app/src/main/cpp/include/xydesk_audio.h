#pragma once

#ifdef __cplusplus
extern "C" {
#endif

const char* xydesk_audio_backend_name(void);
int xydesk_audio_sample_rate(void);
int xydesk_audio_channel_count(void);
int xydesk_audio_frame_samples(void);

#ifdef __cplusplus
}
#endif
