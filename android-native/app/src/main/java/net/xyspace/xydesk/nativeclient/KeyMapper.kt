package net.xyspace.xydesk.nativeclient

/** Pemetaan label keyboard virtual ke Windows Virtual-Key code. */
object KeyMapper {
    private val special = mapOf(
        "Esc" to 0x1B,
        "Tab" to 0x09,
        "Caps" to 0x14,
        "Shift" to 0xA0,
        "Ctrl" to 0xA2,
        "Win" to 0x5B,
        "Alt" to 0xA4,
        "Enter" to 0x0D,
        "Del" to 0x2E,
        "Backspace" to 0x08,
        " " to 0x20,
        "↑" to 0x26,
        "↓" to 0x28,
        "←" to 0x25,
        "→" to 0x27,
        "`" to 0xC0,
        "-" to 0xBD,
        "=" to 0xBB,
        "[" to 0xDB,
        "]" to 0xDD,
        ";" to 0xBA,
        "," to 0xBC,
        "." to 0xBE,
        "/" to 0xBF,
    )

    fun vkForLabel(label: String): Int? {
        special[label]?.let { return it }
        if (label.length == 1) {
            val code = label[0].code
            if (code in '0'.code..'9'.code) return code
            if (code in 'A'.code..'Z'.code) return code
            if (code in 'a'.code..'z'.code) return code - 0x20
        }
        if (label.startsWith("F") && label.length <= 3) {
            val number = label.drop(1).toIntOrNull()
            if (number != null && number in 1..12) return 0x70 + number - 1
        }
        return null
    }
}
