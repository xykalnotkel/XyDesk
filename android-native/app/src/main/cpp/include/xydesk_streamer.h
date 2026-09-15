#pragma once

#ifdef __cplusplus
extern "C" {
#endif

const char* xydesk_streamer_backend_name(void);
const char* xydesk_streamer_state_name(void);
void xydesk_streamer_set_state(int state);

#ifdef __cplusplus
}
#endif
