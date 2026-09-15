package net.xyspace.xydesk.nativeclient

import android.content.Context

/** Preferensi non-rahasia native client; token tetap berada di SecureStore. */
class NativeSettings(context: Context) {
    private val preferences = context.applicationContext
        .getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)

    var audioForwardDefault: Boolean
        get() = preferences.getBoolean(KEY_AUDIO_FORWARD, true)
        set(value) = preferences.edit().putBoolean(KEY_AUDIO_FORWARD, value).apply()

    var microphoneDefault: Boolean
        get() = preferences.getBoolean(KEY_MICROPHONE, true)
        set(value) = preferences.edit().putBoolean(KEY_MICROPHONE, value).apply()

    var preferredDisplay: Int
        get() = preferences.getInt(KEY_DISPLAY, 0)
        set(value) = preferences.edit().putInt(KEY_DISPLAY, value.coerceIn(0, 255)).apply()

    var pipEnabled: Boolean
        get() = preferences.getBoolean(KEY_PIP, true)
        set(value) = preferences.edit().putBoolean(KEY_PIP, value).apply()

    var notificationsEnabled: Boolean
        get() = preferences.getBoolean(KEY_NOTIFICATIONS, true)
        set(value) = preferences.edit().putBoolean(KEY_NOTIFICATIONS, value).apply()

    var keepScreenOn: Boolean
        get() = preferences.getBoolean(KEY_KEEP_SCREEN_ON, true)
        set(value) = preferences.edit().putBoolean(KEY_KEEP_SCREEN_ON, value).apply()

    var hapticsEnabled: Boolean
        get() = preferences.getBoolean(KEY_HAPTICS, true)
        set(value) = preferences.edit().putBoolean(KEY_HAPTICS, value).apply()

    var autoReconnect: Boolean
        get() = preferences.getBoolean(KEY_AUTO_RECONNECT, true)
        set(value) = preferences.edit().putBoolean(KEY_AUTO_RECONNECT, value).apply()

    var signalingEndpoint: String
        get() = preferences.getString(KEY_SIGNALING, NativeRtcSession.DEFAULT_SIGNALING_URL)
            .orEmpty()
            .ifBlank { NativeRtcSession.DEFAULT_SIGNALING_URL }
        set(value) = preferences.edit().putString(KEY_SIGNALING, value.trim()).apply()

    companion object {
        private const val FILE_NAME = "xydesk_native_settings"
        private const val KEY_AUDIO_FORWARD = "audio_forward_default"
        private const val KEY_MICROPHONE = "microphone_default"
        private const val KEY_DISPLAY = "preferred_display"
        private const val KEY_PIP = "pip_enabled"
        private const val KEY_NOTIFICATIONS = "notifications_enabled"
        private const val KEY_KEEP_SCREEN_ON = "keep_screen_on"
        private const val KEY_HAPTICS = "haptics_enabled"
        private const val KEY_AUTO_RECONNECT = "auto_reconnect"
        private const val KEY_SIGNALING = "signaling_endpoint"
    }
}
