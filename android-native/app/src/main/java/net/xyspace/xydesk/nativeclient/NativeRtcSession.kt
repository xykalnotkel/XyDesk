package net.xyspace.xydesk.nativeclient

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.OkHttpClient
import okhttp3.Request
import org.webrtc.AudioSource
import org.webrtc.AudioTrack
import org.webrtc.DataChannel
import org.webrtc.DefaultVideoDecoderFactory
import org.webrtc.DefaultVideoEncoderFactory
import org.webrtc.EglBase
import org.webrtc.IceCandidate
import org.webrtc.MediaConstraints
import org.webrtc.MediaStreamTrack
import org.webrtc.PeerConnection
import org.webrtc.PeerConnectionFactory
import org.webrtc.RtpReceiver
import org.webrtc.RtpTransceiver
import org.webrtc.SessionDescription
import org.webrtc.SurfaceViewRenderer
import org.webrtc.VideoTrack
import org.webrtc.audio.JavaAudioDeviceModule
import org.json.JSONArray
import org.json.JSONObject
import java.nio.ByteBuffer
import java.util.concurrent.TimeUnit

/** Fase yang ditampilkan UI native tanpa menyamarkan kegagalan koneksi. */
enum class NativeSessionPhase {
    Idle,
    Pairing,
    Negotiating,
    Connected,
    Rejected,
    PeerOffline,
    HostBusy,
    Ended,
    Error,
}

data class NativeSessionState(
    val phase: NativeSessionPhase = NativeSessionPhase.Idle,
    val message: String? = null,
    val videoReady: Boolean = false,
    val audioReady: Boolean = false,
    val audioForwardEnabled: Boolean = true,
    val microphoneEnabled: Boolean = false,
    val clipboard: String? = null,
    val hostMeta: HostMeta? = null,
)

data class HostDisplay(
    val index: Int,
    val name: String,
    val width: Int,
    val height: Int,
    val refreshRate: Int? = null,
    val isPrimary: Boolean = false,
)

data class HostMeta(
    val displays: List<HostDisplay> = emptyList(),
    val wantedDisplay: Int = 0,
    val audioAvailable: Boolean = false,
    val audioPipeline: String = "",
)

/**
 * Native WebRTC client. Ini adalah jalur pengganti RtcService Flutter:
 * signaling, SDP/ICE, video receive, audio send/receive, dan input DataChannel.
 */
class NativeRtcSession(
    private val context: Context,
    private val scope: CoroutineScope,
    private val signalingUrl: String = DEFAULT_SIGNALING_URL,
    private val httpClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build(),
) {
    private val _state = MutableStateFlow(NativeSessionState())
    val state: StateFlow<NativeSessionState> = _state.asStateFlow()

    private val eglBase = EglBase.create()
    private var factory: PeerConnectionFactory? = null
    private var peerConnection: PeerConnection? = null
    private var signaling: SignalingClient? = null
    private var signalJob: Job? = null
    private var inputChannel: DataChannel? = null
    private var videoTrack: VideoTrack? = null
    private var remoteAudioTrack: AudioTrack? = null
    private var audioTransceiver: RtpTransceiver? = null
    private var microphoneTrack: AudioTrack? = null
    private var microphoneSource: AudioSource? = null
    private var deviceId: String = ""
    private var hostId: String = ""
    private var signalingToken: String = ""
    private var stopped = false

    fun eglContext(): EglBase.Context = eglBase.eglBaseContext

    fun attachVideoRenderer(renderer: SurfaceViewRenderer) {
        renderer.init(eglBase.eglBaseContext, null)
        renderer.setEnableHardwareScaler(true)
        renderer.setMirror(false)
        videoTrack?.addSink(renderer)
    }

    fun detachVideoRenderer(renderer: SurfaceViewRenderer) {
        videoTrack?.removeSink(renderer)
        renderer.release()
    }

    suspend fun start(
        hostId: String,
        password: String,
        deviceId: String,
        signalingToken: String,
    ) {
        stop()
        stopped = false
        this.hostId = normalizeHostId(hostId)
        this.deviceId = deviceId
        this.signalingToken = signalingToken
        update(NativeSessionPhase.Pairing, null)

        val signal = SignalingClient(deviceId)
        signaling = signal
        signalJob = scope.launch(Dispatchers.Default) {
            signal.messages.collect { handleSignal(it, password) }
        }
        try {
            signal.connect(signalingUrl, signalingToken)
            signal.sendPair(this@NativeRtcSession.hostId, password)
        } catch (error: SignalingException) {
            fail(error.message ?: "Tidak dapat menghubungi server signaling.")
        }
    }

    private suspend fun handleSignal(message: SignalMessage, password: String) {
        when (message.type) {
            "pair-response" -> {
                if (message.accepted != true) {
                    update(NativeSessionPhase.Rejected, "Password host ditolak. Periksa huruf besar/kecil.")
                } else {
                    update(NativeSessionPhase.Negotiating, null)
                    negotiate()
                }
            }
            "answer" -> {
                val sdp = message.sdp?.get("sdp")?.toString()?.trim('"')
                if (sdp != null) {
                    peerConnection?.setRemoteDescription(
                        SimpleSdpObserver,
                        SessionDescription(SessionDescription.Type.ANSWER, sdp),
                    )
                }
            }
            "ice" -> {
                val candidate = message.candidate ?: return
                val value = candidate.stringValue("candidate") ?: return
                peerConnection?.addIceCandidate(
                    IceCandidate(
                        candidate.stringValue("sdpMid"),
                        candidate.intValue("sdpMLineIndex") ?: 0,
                        value,
                    ),
                )
            }
            "bye" -> update(NativeSessionPhase.Ended, "Sesi ditutup host.")
            "error" -> when (message.error) {
                "peer-offline" -> update(NativeSessionPhase.PeerOffline, "Host tidak online.")
                "pair-terkunci", "host-sibuk" -> update(
                    NativeSessionPhase.HostBusy,
                    "Host sedang dipakai sesi lain. Coba lagi nanti.",
                )
                else -> fail(message.reason ?: message.error ?: "Server signaling mengirim error.")
            }
        }
    }

    private suspend fun negotiate() {
        val peerFactory = ensureFactory()
        val iceServers = mutableListOf(
            PeerConnection.IceServer.builder("stun:stun.cloudflare.com:3478").createIceServer(),
        )
        fetchTurnServers()?.forEach { iceServers += it }
        val config = PeerConnection.RTCConfiguration(iceServers)
        val pc = peerFactory.createPeerConnection(config, Observer())
            ?: return fail("PeerConnection tidak dapat dibuat.")
        peerConnection = pc

        pc.addTransceiver(
            MediaStreamTrack.MediaType.MEDIA_TYPE_VIDEO,
            RtpTransceiver.RtpTransceiverInit(RtpTransceiver.RtpTransceiverDirection.RECV_ONLY),
        )
        val audioTransceiver = pc.addTransceiver(
            MediaStreamTrack.MediaType.MEDIA_TYPE_AUDIO,
            RtpTransceiver.RtpTransceiverInit(RtpTransceiver.RtpTransceiverDirection.SEND_RECV),
        )
        this.audioTransceiver = audioTransceiver
        // Mic Android dikirim langsung lewat WebRTC AudioTrack. Ini tidak
        // membuat virtual microphone dan tidak membutuhkan VB-CABLE/reboot.
        microphoneSource = peerFactory.createAudioSource(MediaConstraints())
        microphoneTrack = peerFactory.createAudioTrack("xydesk-mic", microphoneSource)
        audioTransceiver?.sender?.setTrack(microphoneTrack, false)

        inputChannel = pc.createDataChannel("input", DataChannel.Init())
        inputChannel?.registerObserver(DataObserver())

        pc.createOffer(object : SdpObserverAdapter() {
            override fun onCreateSuccess(description: SessionDescription) {
                pc.setLocalDescription(SimpleSdpObserver, description)
                val sdp = buildJsonObject {
                    put("type", "offer")
                    put("sdp", description.description)
                }
                signaling?.sendOffer(hostId, sdp)
            }

            override fun onCreateFailure(error: String?) {
                fail("Offer WebRTC gagal dibuat: ${error ?: "unknown"}")
            }
        }, MediaConstraints())
    }

    private fun ensureFactory(): PeerConnectionFactory {
        factory?.let { return it }
        PeerConnectionFactory.initialize(
            PeerConnectionFactory.InitializationOptions.builder(context.applicationContext).createInitializationOptions(),
        )
        val audioModule = JavaAudioDeviceModule.builder(context.applicationContext)
            .setUseHardwareAcousticEchoCanceler(true)
            .setUseHardwareNoiseSuppressor(true)
            .createAudioDeviceModule()
        factory = PeerConnectionFactory.builder()
            .setAudioDeviceModule(audioModule)
            .setVideoEncoderFactory(DefaultVideoEncoderFactory(eglBase.eglBaseContext, true, true))
            .setVideoDecoderFactory(DefaultVideoDecoderFactory(eglBase.eglBaseContext))
            .createPeerConnectionFactory()
        return factory!!
    }

    private suspend fun fetchTurnServers(): List<PeerConnection.IceServer> = withContext(Dispatchers.IO) {
        // TURN bersifat opsional; STUN tetap membuat sesi LAN/NAT sederhana jalan.
        val base = signalingUrl
            .replaceFirst("wss://", "https://")
            .replaceFirst("ws://", "http://")
            .substringBefore("/ws")
        val request = Request.Builder()
            .url("$base/turn-ice?id=$deviceId&token=$signalingToken")
            .get()
            .build()
        runCatching {
            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@use emptyList<PeerConnection.IceServer>()
                val body = response.body?.string().orEmpty()
                val servers = JSONObject(body).optJSONArray("iceServers") ?: return@use emptyList()
                buildList {
                    for (index in 0 until servers.length()) {
                        val item = servers.optJSONObject(index) ?: continue
                        val urls = item.opt("urls")
                        val urlList = when (urls) {
                            is JSONArray -> buildList {
                                for (i in 0 until urls.length()) urls.optString(i).takeIf(String::isNotBlank)?.let(::add)
                            }
                            is String -> listOf(urls)
                            else -> emptyList()
                        }
                        if (urlList.isEmpty()) continue
                        val builder = PeerConnection.IceServer.builder(urlList)
                        item.optString("username").takeIf(String::isNotBlank)?.let(builder::setUsername)
                        item.optString("credential").takeIf(String::isNotBlank)?.let(builder::setPassword)
                        add(builder.createIceServer())
                    }
                }
            }
        }.getOrElse { emptyList() }
    }

    fun sendInput(packet: ByteArray) {
        val channel = inputChannel ?: return
        if (channel.state() != DataChannel.State.OPEN) return
        channel.send(DataChannel.Buffer(ByteBuffer.wrap(packet), true))
    }

    fun mouseMoveRelative(dx: Int, dy: Int) = sendInput(InputCodec.mouseMoveRel(dx, dy))
    fun mouseMoveAbsolute(x: Double, y: Double) = sendInput(InputCodec.mouseMoveAbs(x, y))
    fun mouseButton(button: Int, down: Boolean) = sendInput(InputCodec.mouseButton(button, down))
    fun scroll(dx: Int, dy: Int) = sendInput(InputCodec.scroll(dx, dy))
    fun key(vk: Int, down: Boolean) = sendInput(InputCodec.key(vk, down))
    fun selectDisplay(index: Int) = sendInput(InputCodec.displaySelect(index))
    fun sendClipboard(value: String) = sendInput(InputCodec.clipboardSet(value))
    fun requestClipboard() = sendInput(InputCodec.clipboardRequest())
    fun sendText(value: String) = InputCodec.textChunked(value).forEach(::sendInput)

    fun setAudioForwardEnabled(enabled: Boolean) {
        _state.value = _state.value.copy(audioForwardEnabled = enabled)
        audioTransceiver?.setDirection(
            if (enabled) {
                RtpTransceiver.RtpTransceiverDirection.SEND_RECV
            } else {
                // Tetap kirim mic; hanya suara host yang dimatikan.
                RtpTransceiver.RtpTransceiverDirection.SEND_ONLY
            },
        )
    }

    fun stop() {
        stopped = true
        signaling?.sendBye(hostId)
        signalJob?.cancel()
        signalJob = null
        inputChannel?.dispose()
        inputChannel = null
        peerConnection?.close()
        peerConnection?.dispose()
        peerConnection = null
        microphoneTrack?.dispose()
        microphoneTrack = null
        microphoneSource?.dispose()
        microphoneSource = null
        videoTrack = null
        remoteAudioTrack = null
        signaling?.close()
        signaling = null
        update(NativeSessionPhase.Ended, null)
    }

    private fun update(phase: NativeSessionPhase, message: String?) {
        _state.value = _state.value.copy(
            phase = phase,
            message = message,
            videoReady = phase == NativeSessionPhase.Connected && videoTrack != null,
            audioReady = phase == NativeSessionPhase.Connected && remoteAudioTrack != null,
            microphoneEnabled = microphoneTrack != null,
        )
    }

    private fun parseHostMeta(text: String): HostMeta? = runCatching {
        val root = JSONObject(text)
        if (root.optString("type") != "meta") return null
        val displayArray = root.optJSONArray("displays")
        val displays = buildList {
            if (displayArray != null) {
                for (index in 0 until displayArray.length()) {
                    val item = displayArray.optJSONObject(index) ?: continue
                    add(
                        HostDisplay(
                            index = item.optInt("index", index),
                            name = item.optString("name"),
                            width = item.optInt("width"),
                            height = item.optInt("height"),
                            refreshRate = item.optInt("refreshRate").takeIf { it > 0 },
                            isPrimary = item.optBoolean("isPrimary", false),
                        ),
                    )
                }
            }
        }
        val audio = root.optJSONObject("audio")
        HostMeta(
            displays = displays,
            wantedDisplay = root.optInt("wanted", 0),
            audioAvailable = audio?.optBoolean("available", false) ?: false,
            audioPipeline = audio?.optString("pipeline").orEmpty(),
        )
    }.getOrNull()

    private fun fail(message: String) {
        if (!stopped) update(NativeSessionPhase.Error, message)
    }

    private inner class DataObserver : DataChannel.Observer {
        override fun onBufferedAmountChange(previousAmount: Long) = Unit
        override fun onStateChange() = Unit
        override fun onMessage(buffer: DataChannel.Buffer) {
            val data = ByteArray(buffer.data.remaining()).also { buffer.data.get(it) }
            if (buffer.binary) {
                InputCodec.decodeClipboardSet(data)?.let { text ->
                    _state.value = _state.value.copy(clipboard = text)
                }
            } else {
                parseHostMeta(data.toString(Charsets.UTF_8))?.let { meta ->
                    _state.value = _state.value.copy(hostMeta = meta)
                }
            }
        }
    }

    private inner class Observer : PeerConnection.Observer {
        override fun onSignalingChange(state: PeerConnection.SignalingState?) = Unit
        override fun onIceConnectionChange(state: PeerConnection.IceConnectionState?) {
            when (state) {
                PeerConnection.IceConnectionState.CONNECTED,
                PeerConnection.IceConnectionState.COMPLETED -> update(NativeSessionPhase.Connected, null)
                PeerConnection.IceConnectionState.FAILED -> fail("Koneksi ICE gagal. Periksa jaringan atau TURN.")
                else -> Unit
            }
        }
        override fun onIceConnectionReceivingChange(receiving: Boolean) = Unit
        override fun onIceGatheringChange(state: PeerConnection.IceGatheringState?) = Unit
        override fun onIceCandidate(candidate: IceCandidate) {
            val json = buildJsonObject {
                put("candidate", candidate.sdp)
                put("sdpMid", candidate.sdpMid)
                put("sdpMLineIndex", candidate.sdpMLineIndex)
            }
            signaling?.sendIce(hostId, json)
        }
        override fun onIceCandidatesRemoved(candidates: Array<out IceCandidate>) = Unit
        override fun onAddStream(stream: org.webrtc.MediaStream?) = Unit
        override fun onRemoveStream(stream: org.webrtc.MediaStream?) = Unit
        override fun onDataChannel(channel: DataChannel) {
            if (inputChannel == null) {
                inputChannel = channel
                channel.registerObserver(DataObserver())
            }
        }
        override fun onRenegotiationNeeded() = Unit
        override fun onAddTrack(receiver: RtpReceiver?, mediaStreams: Array<out org.webrtc.MediaStream>?) {
            val track = receiver?.track()
            when (track) {
                is VideoTrack -> videoTrack = track
                is AudioTrack -> remoteAudioTrack = track
            }
            update(NativeSessionPhase.Connected, null)
        }
        override fun onTrack(transceiver: RtpTransceiver?) = Unit
        override fun onConnectionChange(newState: PeerConnection.PeerConnectionState?) {
            if (newState == PeerConnection.PeerConnectionState.FAILED) {
                fail("PeerConnection gagal.")
            }
        }
        override fun onSelectedCandidatePairChanged(event: PeerConnection.CandidatePairChangeEvent?) = Unit
    }

    private open class SdpObserverAdapter : org.webrtc.SdpObserver {
        override fun onCreateSuccess(description: SessionDescription) = Unit
        override fun onSetSuccess() = Unit
        override fun onCreateFailure(error: String?) = Unit
        override fun onSetFailure(error: String?) = Unit
    }

    private object SimpleSdpObserver : org.webrtc.SdpObserver {
        override fun onCreateSuccess(description: SessionDescription) = Unit
        override fun onSetSuccess() = Unit
        override fun onCreateFailure(error: String?) = Unit
        override fun onSetFailure(error: String?) = Unit
    }

    private fun JsonObject.stringValue(key: String): String? =
        this[key]?.toString()?.trim('"')

    private fun JsonObject.intValue(key: String): Int? =
        this[key]?.toString()?.toIntOrNull()

    companion object {
        const val DEFAULT_SIGNALING_URL = "wss://signal.xydesk.my.id/ws"

        fun normalizeHostId(value: String): String = value.filterNot { it == ' ' || it == '-' }
    }
}
