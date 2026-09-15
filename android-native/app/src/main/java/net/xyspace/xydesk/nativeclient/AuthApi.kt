package net.xyspace.xydesk.nativeclient

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.TimeUnit

class AuthApi(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build(),
    private val baseUrl: String = DEFAULT_BASE_URL,
) {
    private val jsonType = "application/json; charset=utf-8".toMediaType()

    suspend fun requestOtp(email: String, name: String): OtpResult = withContext(Dispatchers.IO) {
        val body = post("/auth/request-otp", JSONObject().apply {
            put("email", email)
            put("name", name)
        })
        OtpResult(
            expiresIn = body.optInt("expires_in", 600),
            resendIn = body.optInt("resend_in", 60),
        )
    }

    suspend fun verifyOtp(email: String, otp: String): AuthSession = withContext(Dispatchers.IO) {
        val body = post("/auth/verify-otp", JSONObject().apply {
            put("email", email)
            put("otp", otp)
        })
        AuthSession.fromJson(body)
    }

    suspend fun me(token: String): AuthUser = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("$baseUrl/auth/me")
            .header("Authorization", "Bearer $token")
            .get()
            .build()
        execute(request).optJSONObject("user")?.let(AuthUser::fromJson)
            ?: throw AuthException("invalid-response", "Profil sesi tidak valid.")
    }

    suspend fun signalToken(token: String, deviceId: String): String = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("$baseUrl/signal-token?id=$deviceId")
            .header("Authorization", "Bearer $token")
            .get()
            .build()
        val response = executeRaw(request)
        if (response.isEmpty()) throw AuthException("invalid-response", "Token signaling kosong.")
        response
    }

    private fun post(path: String, payload: JSONObject): JSONObject {
        val body = payload.toString().toRequestBody(jsonType)
        val request = Request.Builder()
            .url("$baseUrl$path")
            .header("Content-Type", "application/json")
            .post(body)
            .build()
        return execute(request)
    }

    private fun execute(request: Request): JSONObject {
        val response = client.newCall(request).execute()
        val text = response.body?.string().orEmpty()
        if (!response.isSuccessful) {
            val message = runCatching { JSONObject(text).optString("message") }
                .getOrNull()
                ?.takeIf { it.isNotBlank() }
                ?: "Server mengembalikan HTTP ${response.code}."
            throw AuthException("http-${response.code}", message, response.code)
        }
        return runCatching { JSONObject(text) }
            .getOrElse { throw AuthException("invalid-response", "Respons server tidak valid.") }
    }

    private fun executeRaw(request: Request): String {
        val response = client.newCall(request).execute()
        val text = response.body?.string().orEmpty()
        if (!response.isSuccessful) {
            throw AuthException("http-${response.code}", "Gagal mendapat izin signaling.", response.code)
        }
        return text.trim()
    }

    companion object {
        const val DEFAULT_BASE_URL = "https://signal.xydesk.my.id"

        fun newDeviceId(): String = "app-${UUID.randomUUID()}"
    }
}

data class OtpResult(val expiresIn: Int, val resendIn: Int)

data class AuthUser(val email: String, val name: String) {
    companion object {
        fun fromJson(json: JSONObject): AuthUser = AuthUser(
            email = json.optString("email"),
            name = json.optString("name").ifBlank { json.optString("email") },
        )
    }
}

data class AuthSession(val token: String, val user: AuthUser) {
    companion object {
        fun fromJson(json: JSONObject): AuthSession {
            val token = json.optString("token")
            val user = json.optJSONObject("user")
            if (token.isBlank() || user == null) {
                throw AuthException("invalid-response", "Respons sesi dari server tidak valid.")
            }
            return AuthSession(token, AuthUser.fromJson(user))
        }
    }
}

class AuthException(
    val code: String,
    override val message: String,
    val statusCode: Int? = null,
) : Exception(message)
