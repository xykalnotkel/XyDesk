#pragma once

#ifdef __cplusplus
extern "C" {
#endif

const char* xydesk_control_protocol_version(void);
const char* xydesk_control_state_name(void);
void xydesk_control_set_state(int state);

#ifdef __cplusplus
}
#endif
