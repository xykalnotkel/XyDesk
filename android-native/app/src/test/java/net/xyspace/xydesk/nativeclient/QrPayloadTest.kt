package net.xyspace.xydesk.nativeclient

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class QrPayloadTest {
    @Test
    fun parsesPlainNineDigitId() {
        assertEquals("123456789", QrPayload.parseHostId("123 456 789"))
    }

    @Test
    fun parsesXyDeskUri() {
        assertEquals("123456789", QrPayload.parseHostId("xydesk://connect?id=123456789"))
    }

    @Test
    fun rejectsWrongLength() {
        assertNull(QrPayload.parseHostId("12345678"))
    }
}
