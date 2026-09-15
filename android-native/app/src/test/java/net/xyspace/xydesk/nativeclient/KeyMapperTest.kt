package net.xyspace.xydesk.nativeclient

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class KeyMapperTest {
    @Test
    fun mapsLettersDigitsAndFunctionKeys() {
        assertEquals(0x41, KeyMapper.vkForLabel("a"))
        assertEquals(0x39, KeyMapper.vkForLabel("9"))
        assertEquals(0x70, KeyMapper.vkForLabel("F1"))
        assertEquals(0x7B, KeyMapper.vkForLabel("F12"))
    }

    @Test
    fun mapsControlsAndRejectsUnknown() {
        assertEquals(0x0D, KeyMapper.vkForLabel("Enter"))
        assertEquals(0x27, KeyMapper.vkForLabel("→"))
        assertNull(KeyMapper.vkForLabel("Fn"))
    }
}
