package com.xystudio.xydesk.nativeclient

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class InputCodecTest {
    @Test
    fun mouseMoveRelUsesLittleEndianAndFixedFrame() {
        val packet = InputCodec.mouseMoveRel(0x1234, -2)
        assertEquals(8, packet.size)
        assertEquals(0x01, packet[0].toInt())
        assertEquals(0x34, packet[1].toInt() and 0xff)
        assertEquals(0x12, packet[2].toInt() and 0xff)
        assertEquals(0xfe, packet[3].toInt() and 0xff)
        assertEquals(0xff, packet[4].toInt() and 0xff)
    }

    @Test
    fun textChunkedDoesNotSplitSurrogatePair() {
        val value = "a".repeat(InputCodec.TEXT_MAX_CHARS - 1) + "😀" + "b"
        val chunks = InputCodec.textChunked(value)
        assertEquals(2, chunks.size)
        assertEquals(value, chunks.joinToString("") { String(it, 1, it.size - 1, Charsets.UTF_8) })
        assertTrue(chunks.first().toString(Charsets.UTF_8).endsWith("a"))
    }

    @Test
    fun clipboardRoundTripKeepsUtf8() {
        val value = "Halo — XyDesk 😀"
        assertEquals(value, InputCodec.decodeClipboardSet(InputCodec.clipboardSet(value)))
    }
}
