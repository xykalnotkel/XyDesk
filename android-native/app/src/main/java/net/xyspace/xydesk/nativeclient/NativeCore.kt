package net.xyspace.xydesk.nativeclient

/** JNI facade untuk library native milik XyDesk. */
object NativeCore {
    private var loaded = false

    init {
        loaded = runCatching {
            System.loadLibrary("xydesk_control")
            System.loadLibrary("xydesk_audio")
            System.loadLibrary("xydesk_streamer")
            System.loadLibrary("xydesk_bridge")
        }.isSuccess
    }

    fun isLoaded(): Boolean = loaded

    fun snapshot(): String {
        if (!loaded) return "native library tidak tersedia"
        return runCatching { nativeSnapshot() }
            .getOrElse { "native bridge gagal: ${it.message ?: "galat tidak diketahui"}" }
    }

    fun setSessionState(state: Int) {
        if (loaded) runCatching { nativeSetSessionState(state) }
    }

    private external fun nativeSnapshot(): String
    private external fun nativeSetSessionState(state: Int)
}
