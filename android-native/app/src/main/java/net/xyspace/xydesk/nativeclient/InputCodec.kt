package net.xyspace.xydesk.nativeclient

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.roundToInt

/** Wire codec yang harus identik dengan host/src/input.rs dan codec Flutter. */
object InputCodec {
    const val TEXT_MAX_CHARS = 2_000
    const val CLIPBOARD_MAX_BYTES = 64 * 1024

    fun displaySelect(index: Int): ByteArray = fixed(0x07).also {
        it[1] = index.coerceIn(0, 255).toByte()
    }

    fun mouseMoveRel(dx: Int, dy: Int): ByteArray = fixed(0x01).also {
        putShort(it, 1, dx.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()))
        putShort(it, 3, dy.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()))
    }

    fun mouseMoveAbs(fx: Double, fy: Double): ByteArray = fixed(0x02).also {
        putUShort(it, 1, (fx.coerceIn(0.0, 1.0) * 65_535).roundToInt())
        putUShort(it, 3, (fy.coerceIn(0.0, 1.0) * 65_535).roundToInt())
    }

    fun mouseButton(button: Int, down: Boolean): ByteArray = fixed(0x03).also {
        it[1] = button.coerceIn(0, 255).toByte()
        it[2] = if (down) 1 else 0
    }

    fun scroll(dx: Int, dy: Int): ByteArray = fixed(0x04).also {
        putShort(it, 1, dx.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()))
        putShort(it, 3, dy.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()))
    }

    fun key(vk: Int, down: Boolean): ByteArray = fixed(0x05).also {
        putUShort(it, 1, vk.coerceIn(0, 65_535))
        it[3] = if (down) 1 else 0
    }

    fun text(value: String): ByteArray = byteArrayOf(0x06) + value.toByteArray(Charsets.UTF_8)

    fun textChunked(value: String): List<ByteArray> {
        if (value.isEmpty()) return listOf(text(value))
        val chunks = mutableListOf<ByteArray>()
        var start = 0
        while (start < value.length) {
            var end = (start + TEXT_MAX_CHARS).coerceAtMost(value.length)
            if (end < value.length && Character.isHighSurrogate(value[end - 1]) && Character.isLowSurrogate(value[end])) {
                end -= 1
            }
            chunks += text(value.substring(start, end))
            start = end
        }
        return chunks
    }

    fun clipboardSet(value: String): ByteArray {
        val bytes = value.toByteArray(Charsets.UTF_8)
        var end = bytes.size.coerceAtMost(CLIPBOARD_MAX_BYTES)
        while (end > 0 && end < bytes.size && (bytes[end].toInt() and 0xC0) == 0x80) end -= 1
        return byteArrayOf(0x08) + bytes.copyOf(end)
    }

    fun clipboardRequest(): ByteArray = fixed(0x09)

    fun decodeClipboardSet(packet: ByteArray): String? {
        if (packet.isEmpty() || packet[0].toInt() and 0xFF != 0x08) return null
        if (packet.size - 1 > CLIPBOARD_MAX_BYTES) return null
        return packet.copyOfRange(1, packet.size).toString(Charsets.UTF_8)
            .takeIf { it.toByteArray(Charsets.UTF_8).contentEquals(packet.copyOfRange(1, packet.size)) }
    }

    private fun fixed(tag: Int): ByteArray = ByteArray(8).also { it[0] = tag.toByte() }

    private fun putShort(target: ByteArray, offset: Int, value: Int) {
        ByteBuffer.wrap(target).order(ByteOrder.LITTLE_ENDIAN).putShort(offset, value.toShort())
    }

    private fun putUShort(target: ByteArray, offset: Int, value: Int) {
        ByteBuffer.wrap(target).order(ByteOrder.LITTLE_ENDIAN).putShort(offset, value.toShort())
    }
}
