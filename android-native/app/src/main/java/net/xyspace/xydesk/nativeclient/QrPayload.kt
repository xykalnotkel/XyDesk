package net.xyspace.xydesk.nativeclient

import android.net.Uri

/** Parser QR host XyDesk: ID polos atau xydesk://connect?id=123456789. */
object QrPayload {
    fun parseHostId(raw: String): String? {
        val uri = runCatching { Uri.parse(raw) }.getOrNull()
        val candidate = if (uri?.scheme.equals("xydesk", ignoreCase = true)) {
            uri?.getQueryParameter("id").orEmpty()
        } else {
            raw
        }
        val digits = candidate.filter(Char::isDigit)
        return digits.takeIf { it.length == 9 }
    }
}
