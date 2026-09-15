package net.xyspace.xydesk.nativeclient

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.SupervisorJob

/**
 * Pemilik process-level sesi WebRTC. ViewModel boleh dibuat ulang saat
 * Activity/configuration berubah tanpa memutus sesi yang sedang berjalan;
 * foreground service memegang runtime yang sama selama app berada di background.
 */
object NativeSessionRuntime {
    private val lock = Any()
    private var session: NativeRtcSession? = null
    private var scope: CoroutineScope? = null

    fun session(context: Context): NativeRtcSession = synchronized(lock) {
        session ?: run {
            val runtimeScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
            scope = runtimeScope
            NativeRtcSession(context.applicationContext, runtimeScope).also { session = it }
        }
    }

    fun attach(context: Context) {
        session(context)
    }

    fun stop() {
        synchronized(lock) { session }?.stop()
    }

    fun dispose() {
        synchronized(lock) {
            session?.dispose()
            session = null
            scope?.coroutineContext?.cancel()
            scope = null
        }
    }
}
