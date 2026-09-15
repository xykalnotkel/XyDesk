package com.xystudio.xydesk.nativeclient

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
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
    private val _state = MutableStateFlow<AuthUiState>(AuthUiState.Loading)
    val state: StateFlow<AuthUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            val token = store.getString(SecureStore.TOKEN)
            val email = store.getString(SecureStore.EMAIL)
            val name = store.getString(SecureStore.NAME)
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
                    store.putString(SecureStore.TOKEN, session.token)
                    store.putString(SecureStore.EMAIL, session.user.email.ifBlank { email.trim() })
                    store.putString(SecureStore.NAME, session.user.name.ifBlank { name.trim() })
                    _state.value = AuthUiState.SignedIn(session.user)
                }
                .onFailure { error ->
                    _state.value = AuthUiState.Error(error.userMessage(), AuthUiState.OtpRequested(email, 0))
                }
        }
    }

    fun signOut() {
        clearSession()
        _state.value = AuthUiState.SignedOut
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
    }
}

private fun Throwable.userMessage(): String = when (this) {
    is AuthException -> message
    else -> "Tidak dapat menghubungi server. Periksa koneksi internet."
}
