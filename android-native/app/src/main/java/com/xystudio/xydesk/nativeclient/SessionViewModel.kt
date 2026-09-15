package com.xystudio.xydesk.nativeclient

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.webrtc.SurfaceViewRenderer

class SessionViewModel(application: Application) : AndroidViewModel(application) {
    private val store = SecureStore(application)
    private val api = AuthApi()
    private val session = NativeRtcSession(application, viewModelScope)
    private val _state = MutableStateFlow(NativeSessionState())
    val state: StateFlow<NativeSessionState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            session.state.collect { _state.value = it }
        }
    }

    fun connect(hostId: String, password: String) {
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
        _state.value = _state.value.copy(phase = NativeSessionPhase.Pairing, message = "Meminta izin signaling…")
        viewModelScope.launch {
            runCatching {
                val deviceId = deviceId()
                val signalToken = api.signalToken(token, deviceId)
                session.start(
                    hostId = normalizedId,
                    password = password,
                    deviceId = deviceId,
                    signalingToken = signalToken,
                )
            }.onFailure { error ->
                sessionError(error.userMessage())
            }
        }
    }

    fun attachRenderer(renderer: SurfaceViewRenderer) = session.attachVideoRenderer(renderer)
    fun detachRenderer(renderer: SurfaceViewRenderer) = session.detachVideoRenderer(renderer)
    fun sendInput(packet: ByteArray) = session.sendInput(packet)
    fun selectDisplay(index: Int) = session.selectDisplay(index)
    fun sendClipboard(value: String) = session.sendClipboard(value)
    fun requestClipboard() = session.requestClipboard()
    fun sendText(value: String) = session.sendText(value)
    fun disconnect() = session.stop()

    private fun sessionError(message: String) {
        _state.value = _state.value.copy(phase = NativeSessionPhase.Error, message = message)
    }

    private fun deviceId(): String {
        store.getString(SecureStore.DEVICE_ID)?.let { return it }
        return AuthApi.newDeviceId().also { store.putString(SecureStore.DEVICE_ID, it) }
    }

    override fun onCleared() {
        session.stop()
        super.onCleared()
    }
}

private fun Throwable.userMessage(): String = when (this) {
    is AuthException -> message
    else -> "Tidak dapat menghubungi server signaling."
}
