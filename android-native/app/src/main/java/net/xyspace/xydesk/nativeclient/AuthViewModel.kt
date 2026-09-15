package net.xyspace.xydesk.nativeclient

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface AuthUiState {
    data object Loading : AuthUiState
    data object SignedOut : AuthUiState
    data class OtpRequested(val email: String, val resendIn: Int) : AuthUiState
    data class SignedIn(val user: AuthUser) : AuthUiState
    data class Working(val label: String) : AuthUiState
    data class Error(val message: String, val previous: AuthUiState) : AuthUiState
}

class AuthViewModel(application: Application) : AndroidViewModel(application) {
    private val store = SecureStore(application)
    private val api = AuthApi()
    private var resendJob: Job? = null
    private val _state = MutableStateFlow<AuthUiState>(AuthUiState.Loading)
    val state: StateFlow<AuthUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            val token = store.getString(SecureStore.TOKEN)
            val email = store.getString(SecureStore.EMAIL)
            val name = store.getString(SecureStore.NAME)
            if (store.getString(SecureStore.GUEST) == "true") {
                _state.value = AuthUiState.SignedIn(AuthUser("", name.orEmpty().ifBlank { "Tamu XyDesk" }))
                return@launch
            }
            if (token.isNullOrBlank() || email.isNullOrBlank()) {
                _state.value = AuthUiState.SignedOut
                return@launch
            }
            _state.value = AuthUiState.Working("Memulihkan sesi…")
            runCatching { api.me(token) }
                .onSuccess { user ->
                    store.putString(SecureStore.EMAIL, user.email)
                    store.putString(SecureStore.NAME, user.name.ifBlank { name.orEmpty() })
                    _state.value = AuthUiState.SignedIn(user)
                }
                .onFailure {
                    clearSession()
                    _state.value = AuthUiState.SignedOut
                }
        }
    }

    fun requestOtp(email: String, name: String) {
        val normalized = email.trim()
        if (!normalized.contains("@") || name.trim().length < 2) {
            _state.value = AuthUiState.Error(
                "Masukkan nama dan email yang valid.",
                _state.value,
            )
            return
        }
        _state.value = AuthUiState.Working("Mengirim kode…")
        viewModelScope.launch {
            runCatching { api.requestOtp(normalized, name.trim()) }
                .onSuccess { result ->
                    _state.value = AuthUiState.OtpRequested(normalized, result.resendIn)
                    startResendCountdown(normalized, result.resendIn)
                }
                .onFailure { error ->
                    _state.value = AuthUiState.Error(error.userMessage(), AuthUiState.SignedOut)
                }
        }
    }

    fun verifyOtp(email: String, otp: String, name: String) {
        if (otp.trim().length < 4) {
            _state.value = AuthUiState.Error("Kode OTP belum lengkap.", _state.value)
            return
        }
        _state.value = AuthUiState.Working("Memverifikasi…")
        viewModelScope.launch {
            runCatching { api.verifyOtp(email.trim(), otp.trim()) }
                .onSuccess { session ->
                    resendJob?.cancel()
                    resendJob = null
                    store.putString(SecureStore.TOKEN, session.token)
                    store.putString(SecureStore.EMAIL, session.user.email.ifBlank { email.trim() })
                    store.putString(SecureStore.NAME, session.user.name.ifBlank { name.trim() })
                    store.putString(SecureStore.GUEST, "false")
                    _state.value = AuthUiState.SignedIn(session.user)
                }
                .onFailure { error ->
                    _state.value = AuthUiState.Error(error.userMessage(), AuthUiState.OtpRequested(email, 0))
                }
        }
    }

    fun signInGoogle(idToken: String) {
        if (idToken.isBlank()) {
            _state.value = AuthUiState.Error("Google tidak memberikan token identitas.", AuthUiState.SignedOut)
            return
        }
        _state.value = AuthUiState.Working("Memverifikasi Google…")
        viewModelScope.launch {
            runCatching { api.signInWithGoogle(idToken) }
                .onSuccess { session ->
                    store.putString(SecureStore.TOKEN, session.token)
                    store.putString(SecureStore.EMAIL, session.user.email)
                    store.putString(SecureStore.NAME, session.user.name)
                    store.putString(SecureStore.GUEST, "false")
                    _state.value = AuthUiState.SignedIn(session.user)
                }
                .onFailure { error ->
                    _state.value = AuthUiState.Error(error.userMessage(), AuthUiState.SignedOut)
                }
        }
    }

    fun signInGuest() {
        resendJob?.cancel()
        store.remove(SecureStore.TOKEN)
        store.remove(SecureStore.EMAIL)
        val guestName = store.getString(SecureStore.NAME).orEmpty().ifBlank { "Tamu XyDesk" }
        store.putString(SecureStore.NAME, guestName)
        store.putString(SecureStore.GUEST, "true")
        _state.value = AuthUiState.SignedIn(AuthUser("", guestName))
    }

    fun signOut() {
        resendJob?.cancel()
        resendJob = null
        clearSession()
        _state.value = AuthUiState.SignedOut
    }

    private fun startResendCountdown(email: String, seconds: Int) {
        resendJob?.cancel()
        if (seconds <= 0) return
        resendJob = viewModelScope.launch {
            var remaining = seconds
            while (remaining >= 0) {
                val current = _state.value as? AuthUiState.OtpRequested
                if (current == null || current.email != email) return@launch
                _state.value = current.copy(resendIn = remaining)
                if (remaining == 0) break
                delay(1_000)
                remaining -= 1
            }
        }
    }

    fun token(): String? = store.getString(SecureStore.TOKEN)
    fun deviceId(): String {
        store.getString(SecureStore.DEVICE_ID)?.let { return it }
        return AuthApi.newDeviceId().also { store.putString(SecureStore.DEVICE_ID, it) }
    }

    private fun clearSession() {
        store.remove(SecureStore.TOKEN)
        store.remove(SecureStore.EMAIL)
        store.remove(SecureStore.NAME)
        store.remove(SecureStore.GUEST)
    }
}

private fun Throwable.userMessage(): String = when (this) {
    is AuthException -> message
    else -> "Tidak dapat menghubungi server. Periksa koneksi internet."
}
