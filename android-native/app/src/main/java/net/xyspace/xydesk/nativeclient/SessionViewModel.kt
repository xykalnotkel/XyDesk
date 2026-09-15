package net.xyspace.xydesk.nativeclient

import android.app.Application
import android.content.Intent
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.webrtc.SurfaceViewRenderer

class SessionViewModel(application: Application) : AndroidViewModel(application) {
    private val store = SecureStore(application)
    private val settings = NativeSettings(application)
    private val api = AuthApi()
    private val session = NativeSessionRuntime.session(application)
    private var reconnectJob: Job? = null
    private var reconnectAttempts = 0
    private var lastHostId: String? = null
    private var lastPassword: String? = null
    private val _state = MutableStateFlow(NativeSessionState())
    val state: StateFlow<NativeSessionState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            session.state.collect {
                _state.value = it
                if (it.phase == NativeSessionPhase.Connected) {
                    reconnectAttempts = 0
                    val host = lastHostId
                    val password = lastPassword
                    if (!host.isNullOrBlank() && !password.isNullOrBlank()) {
                        pairedHosts().save(host, password)
                    }
                    if (settings.preferredDisplay > 0) {
                        viewModelScope.launch {
                            delay(500)
                            session.selectDisplay(settings.preferredDisplay)
                        }
                    }
                }
                if (it.phase == NativeSessionPhase.Error || it.phase == NativeSessionPhase.PeerOffline) {
                    scheduleReconnect()
                    if (!settings.autoReconnect || reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
                        stopForegroundService()
                    }
                }
                if (it.phase == NativeSessionPhase.Rejected ||
                    it.phase == NativeSessionPhase.HostBusy
                ) {
                    stopForegroundService()
                }
            }
        }
    }

    private fun pairedHosts(): PairedHostStore =
        PairedHostStore(store, store.getString(SecureStore.EMAIL).orEmpty())

    fun connect(hostId: String, password: String) {
        reconnectJob?.cancel()
        reconnectJob = null
        reconnectAttempts = 0
        connectInternal(hostId, password, remember = true)
    }

    private fun connectInternal(hostId: String, password: String, remember: Boolean) {
        val token = store.getString(SecureStore.TOKEN)
        if (token.isNullOrBlank()) {
            sessionError("Login diperlukan sebelum memulai sesi.")
            return
        }
        val normalizedId = normalizeHostId(hostId)
        if (normalizedId.length < 6 || password.isBlank()) {
            sessionError("ID host dan password wajib diisi.")
            return
        }
        if (remember) {
            lastHostId = normalizedId
            lastPassword = password
        }
        _state.value = _state.value.copy(phase = NativeSessionPhase.Pairing, message = "Meminta izin signaling…")
        viewModelScope.launch {
            runCatching {
                val deviceId = deviceId()
                val signalToken = api.signalToken(token, deviceId)
                session.setSignalingEndpoint(settings.signalingEndpoint)
                session.setAudioForwardEnabled(settings.audioForwardDefault)
                session.setMicrophoneEnabled(settings.microphoneDefault)
                val serviceIntent = Intent(getApplication(), SessionForegroundService::class.java)
                    .setAction(SessionForegroundService.ACTION_START)
                    .putExtra(SessionForegroundService.EXTRA_MESSAGE, "Menghubungkan ke host…")
                ContextCompat.startForegroundService(getApplication(), serviceIntent)
                session.start(
                    hostId = normalizedId,
                    password = password,
                    deviceId = deviceId,
                    signalingToken = signalToken,
                )
            }.onFailure { error ->
                getApplication<Application>().stopService(
                    Intent(getApplication(), SessionForegroundService::class.java)
                        .setAction(SessionForegroundService.ACTION_STOP),
                )
                sessionError(error.userMessage())
            }
        }
    }

    fun recentHosts(): List<PairedHost> = pairedHosts().list()
    fun removeHost(id: String) = pairedHosts().remove(id)

    fun attachRenderer(renderer: SurfaceViewRenderer) = session.attachVideoRenderer(renderer)
    fun detachRenderer(renderer: SurfaceViewRenderer) = session.detachVideoRenderer(renderer)
    fun mouseMoveRelative(dx: Int, dy: Int) = session.mouseMoveRelative(dx, dy)
    fun mouseMoveAbsolute(x: Double, y: Double) = session.mouseMoveAbsolute(x, y)
    fun mouseButton(button: Int, down: Boolean) = session.mouseButton(button, down)
    fun scroll(dx: Int, dy: Int) = session.scroll(dx, dy)
    fun key(vk: Int, down: Boolean) = session.key(vk, down)
    fun sendKeyLabel(label: String) {
        KeyMapper.vkForLabel(label)?.let { vk ->
            session.key(vk, true)
            session.key(vk, false)
        }
    }
    fun sendInput(packet: ByteArray) = session.sendInput(packet)
    fun selectDisplay(index: Int) = session.selectDisplay(index)
    fun setAudioForwardEnabled(enabled: Boolean) {
        settings.audioForwardDefault = enabled
        session.setAudioForwardEnabled(enabled)
    }
    fun setMicrophoneEnabled(enabled: Boolean) {
        settings.microphoneDefault = enabled
        session.setMicrophoneEnabled(enabled)
    }
    fun sendClipboard(value: String) = session.sendClipboard(value)
    fun requestClipboard() = session.requestClipboard()
    fun sendText(value: String) = session.sendText(value)
    fun disconnect() {
        reconnectJob?.cancel()
        reconnectJob = null
        reconnectAttempts = 0
        lastHostId = null
        lastPassword = null
        session.stop()
        getApplication<Application>().stopService(
            Intent(getApplication(), SessionForegroundService::class.java)
                .setAction(SessionForegroundService.ACTION_STOP),
        )
    }

    private fun stopForegroundService() {
        getApplication<Application>().stopService(
            Intent(getApplication(), SessionForegroundService::class.java)
                .setAction(SessionForegroundService.ACTION_STOP),
        )
    }

    private fun scheduleReconnect() {
        if (!settings.autoReconnect || reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) return
        val host = lastHostId ?: return
        val password = lastPassword ?: return
        if (reconnectJob?.isActive == true) return
        reconnectAttempts += 1
        val attempt = reconnectAttempts
        reconnectJob = viewModelScope.launch {
            delay(RECONNECT_DELAY_MS * attempt)
            if (_state.value.phase == NativeSessionPhase.Error || _state.value.phase == NativeSessionPhase.PeerOffline) {
                connectInternal(host, password, remember = false)
            }
        }
    }

    private fun sessionError(message: String) {
        _state.value = _state.value.copy(phase = NativeSessionPhase.Error, message = message)
    }

    private fun deviceId(): String {
        store.getString(SecureStore.DEVICE_ID)?.let { return it }
        return AuthApi.newDeviceId().also { store.putString(SecureStore.DEVICE_ID, it) }
    }

    override fun onCleared() {
        // NativeSessionRuntime dimiliki process/foreground service, bukan
        // ViewModel. Jangan memutus WebRTC hanya karena Activity dibuat ulang.
        reconnectJob?.cancel()
        super.onCleared()
    }

    companion object {
        private const val MAX_RECONNECT_ATTEMPTS = 3
        private const val RECONNECT_DELAY_MS = 1_500L
    }
}

private fun Throwable.userMessage(): String = when (this) {
    is AuthException -> message
    else -> "Tidak dapat menghubungi server signaling."
}
