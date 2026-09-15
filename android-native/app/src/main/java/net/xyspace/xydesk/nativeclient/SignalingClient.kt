package net.xyspace.xydesk.nativeclient

import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** WebSocket client role=client untuk server signaling XyDesk. */
class SignalingClient(
    private val deviceId: String,
    private val httpClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .pingInterval(20, TimeUnit.SECONDS)
        .build(),
) {
    private val _state = MutableStateFlow(SignalingState.Disconnected)
    val state = _state.asStateFlow()

    private val _messages = MutableSharedFlow<SignalMessage>(extraBufferCapacity = 32)
    val messages = _messages.asSharedFlow()

    private var socket: WebSocket? = null
    private var connectContinuation: CancellableContinuation<Unit>? = null

    suspend fun connect(signalingUrl: String, token: String) {
        close()
        _state.value = SignalingState.Connecting
        val requestUrl = signalingUrl.toHttpUrl().newBuilder()
            .addQueryParameter("id", deviceId)
            .addQueryParameter("role", "client")
            .addQueryParameter("token", token)
            .build()
        val request = Request.Builder().url(requestUrl).build()

        suspendCancellableCoroutine<Unit> { continuation ->
            connectContinuation = continuation
            continuation.invokeOnCancellation {
                socket?.cancel()
                socket = null
                connectContinuation = null
            }
            socket = httpClient.newWebSocket(request, object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    socket = webSocket
                    _state.value = SignalingState.Connected
                    connectContinuation?.let {
                        if (it.isActive) it.resume(Unit)
                    }
                    connectContinuation = null
                    send(SignalMessage(type = "hello", to = deviceId, reason = "client"))
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    _messages.tryEmit(SignalMessage.fromJson(text))
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    _state.value = SignalingState.Failed
                    connectContinuation?.let {
                        if (it.isActive) {
                            it.resumeWithException(
                                SignalingException(
                                    "Tidak dapat menghubungi server signaling.",
                                    t,
                                ),
                            )
                        }
                    }
                    connectContinuation = null
                }

                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    if (_state.value != SignalingState.Failed) {
                        _state.value = SignalingState.Disconnected
                    }
                }
            })
        }
    }

    fun sendPair(hostId: String, pin: String, name: String? = null) {
        send(
            SignalMessage(
                type = "pair",
                to = normalizeHostId(hostId),
                pin = pin,
                name = name,
                platform = "android",
            ),
        )
    }

    fun sendOffer(hostId: String, sdp: kotlinx.serialization.json.JsonObject) {
        send(SignalMessage(type = "offer", to = normalizeHostId(hostId), sdp = sdp))
    }

    fun sendAnswer(peerId: String, sdp: kotlinx.serialization.json.JsonObject) {
        send(SignalMessage(type = "answer", to = peerId, sdp = sdp))
    }

    fun sendIce(peerId: String, candidate: kotlinx.serialization.json.JsonObject) {
        send(SignalMessage(type = "ice", to = peerId, candidate = candidate))
    }

    fun sendBye(peerId: String) {
        send(SignalMessage(type = "bye", to = peerId))
    }

    private fun send(message: SignalMessage) {
        val active = socket ?: return
        if (_state.value == SignalingState.Connected) {
            active.send(message.toJson())
        }
    }

    fun close() {
        connectContinuation?.cancel()
        connectContinuation = null
        socket?.close(1000, "client close")
        socket = null
        _state.value = SignalingState.Disconnected
    }
}
