package net.xyspace.xydesk.nativeclient

import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

/**
 * Pemilik process-level sesi WebRTC. ViewModel boleh dibuat ulang saat
 * Activity/configuration berubah tanpa memutus sesi yang sedang berjalan;
 * foreground service memegang runtime yang sama selama app berada di background.
 */
object NativeSessionRuntime {
    private const val MAX_RECONNECT_ATTEMPTS = 3
    private const val RECONNECT_DELAY_MS = 1_500L

    private val lock = Any()
    private var appContext: Context? = null
    private var session: NativeRtcSession? = null
    private var scope: CoroutineScope? = null
    private var observerJob: Job? = null
    private var reconnectJob: Job? = null
    private var reconnectAttempts = 0
    private var reconnectPlan: ReconnectPlan? = null

    fun session(context: Context): NativeRtcSession = synchronized(lock) {
        session ?: run {
            val application = context.applicationContext
            val runtimeScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
            val nativeSession = NativeRtcSession(application, runtimeScope)
            appContext = application
            scope = runtimeScope
            session = nativeSession
            observerJob = runtimeScope.launch(Dispatchers.Default) {
                observe(nativeSession)
            }
            nativeSession
        }
    }

    fun attach(context: Context) {
        session(context)
    }

    fun configureReconnect(hostId: String, password: String) {
        synchronized(lock) {
            reconnectJob?.cancel()
            reconnectJob = null
            reconnectAttempts = 0
            reconnectPlan = ReconnectPlan(hostId, password)
        }
    }

    fun clearReconnect() {
        synchronized(lock) {
            reconnectJob?.cancel()
            reconnectJob = null
            reconnectAttempts = 0
            reconnectPlan = null
        }
    }

    fun stop() {
        clearReconnect()
        synchronized(lock) { session }?.stop()
    }

    fun dispose() {
        synchronized(lock) {
            reconnectJob?.cancel()
            observerJob?.cancel()
            session?.dispose()
            session = null
            appContext = null
            scope?.coroutineContext?.cancel()
            scope = null
            reconnectJob = null
            observerJob = null
            reconnectPlan = null
            reconnectAttempts = 0
        }
    }

    private suspend fun observe(nativeSession: NativeRtcSession) {
        nativeSession.state.collect { state ->
            when (state.phase) {
                NativeSessionPhase.Connected -> synchronized(lock) {
                    reconnectAttempts = 0
                }
                NativeSessionPhase.Error,
                NativeSessionPhase.PeerOffline -> scheduleReconnect(nativeSession)
                NativeSessionPhase.Rejected,
                NativeSessionPhase.HostBusy -> {
                    synchronized(lock) { appContext }?.let { stopForegroundService(it) }
                }
                else -> Unit
            }
        }
    }

    private fun scheduleReconnect(nativeSession: NativeRtcSession) {
        val context = synchronized(lock) { appContext } ?: return
        val settings = NativeSettings(context)
        if (!settings.autoReconnect) {
            stopForegroundService(context)
            return
        }
        val attempt: Int
        val plan: ReconnectPlan
        val runtimeScope: CoroutineScope
        synchronized(lock) {
            plan = reconnectPlan ?: return
            if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS || reconnectJob?.isActive == true) {
                stopForegroundService(context)
                return
            }
            reconnectAttempts += 1
            attempt = reconnectAttempts
            runtimeScope = scope ?: return
            reconnectJob = runtimeScope.launch(Dispatchers.IO) {
                delay(RECONNECT_DELAY_MS * attempt)
                if (nativeSession.state.value.phase != NativeSessionPhase.Error &&
                    nativeSession.state.value.phase != NativeSessionPhase.PeerOffline
                ) return@launch
                runCatching {
                    val store = SecureStore(context)
                    val token = store.getString(SecureStore.TOKEN)
                        ?: throw AuthException("signed-out", "Login diperlukan untuk menyambung ulang.")
                    val deviceId = deviceId(store)
                    val signalToken = AuthApi().signalToken(token, deviceId)
                    nativeSession.setSignalingEndpoint(settings.signalingEndpoint)
                    nativeSession.setAudioForwardEnabled(settings.audioForwardDefault)
                    nativeSession.setMicrophoneEnabled(settings.microphoneDefault)
                    nativeSession.start(
                        hostId = plan.hostId,
                        password = plan.password,
                        deviceId = deviceId,
                        signalingToken = signalToken,
                    )
                }.onFailure { error ->
                    synchronized(lock) { reconnectJob = null }
                    nativeSession.reportError(error.message ?: "Sambung ulang gagal.")
                }.also {
                    synchronized(lock) {
                        if (reconnectJob?.isActive == true) reconnectJob = null
                    }
                }
            }
        }
    }

    private fun stopForegroundService(context: Context) {
        context.stopService(
            Intent(context, SessionForegroundService::class.java)
                .setAction(SessionForegroundService.ACTION_STOP),
        )
    }

    private fun deviceId(store: SecureStore): String {
        store.getString(SecureStore.DEVICE_ID)?.let { return it }
        return AuthApi.newDeviceId().also { store.putString(SecureStore.DEVICE_ID, it) }
    }

    private data class ReconnectPlan(val hostId: String, val password: String)
}
