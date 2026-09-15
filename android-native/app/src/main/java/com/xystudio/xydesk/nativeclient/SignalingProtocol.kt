package com.xystudio.xydesk.nativeclient

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * Pesan signaling XyDesk. Field dan nama JSON sengaja mengikuti
 * lib/webrtc/signaling_client.dart dan signaling/protocol.go.
 */
data class SignalMessage(
    val type: String,
    val to: String? = null,
    val from: String? = null,
    val pin: String? = null,
    val accepted: Boolean? = null,
    val sdp: JsonObject? = null,
    val candidate: JsonObject? = null,
    val error: String? = null,
    val reason: String? = null,
    val retryIn: Int? = null,
    val devices: List<JsonObject> = emptyList(),
    val name: String? = null,
    val platform: String? = null,
) {
    fun toJson(): String = buildJsonObject {
        put("type", type)
        to?.let { put("to", it) }
        from?.let { put("from", it) }
        pin?.let { put("pin", it) }
        accepted?.let { put("accepted", it) }
        sdp?.let { put("sdp", it) }
        candidate?.let { put("candidate", it) }
        reason?.let { put("reason", it) }
        name?.let { put("name", it) }
        platform?.let { put("platform", it) }
    }.toString()

    companion object {
        private val parser = Json { ignoreUnknownKeys = true }

        fun fromJson(value: String): SignalMessage {
            val objectValue = parser.parseToJsonElement(value) as? JsonObject
                ?: return SignalMessage(type = "")
            val primitive = { key: String -> objectValue[key]?.jsonPrimitive }
            return SignalMessage(
                type = primitive("type")?.contentOrNull.orEmpty(),
                to = primitive("to")?.contentOrNull,
                from = primitive("from")?.contentOrNull,
                pin = primitive("pin")?.contentOrNull,
                accepted = primitive("accepted")?.booleanOrNull,
                sdp = objectValue["sdp"] as? JsonObject,
                candidate = objectValue["candidate"] as? JsonObject,
                error = primitive("error")?.contentOrNull,
                reason = primitive("reason")?.contentOrNull,
                retryIn = primitive("retry_in")?.intOrNull,
                name = primitive("name")?.contentOrNull,
                platform = primitive("platform")?.contentOrNull,
            )
        }
    }
}

enum class SignalingState {
    Disconnected,
    Connecting,
    Connected,
    Failed,
}

class SignalingException(message: String, cause: Throwable? = null) : Exception(message, cause)

fun normalizeHostId(value: String): String = value.filterNot { it == ' ' || it == '-' }
