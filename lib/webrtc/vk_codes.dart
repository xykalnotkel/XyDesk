/// Pemetaan label tombol keyboard virtual -> Windows Virtual-Key code.
///
/// Sisi host (`host/src/input.rs`) menginjeksi input memakai VK code Windows,
/// jadi client wajib bicara dalam kosakata yang sama. Label yang tidak ada di
/// peta ini (mis. 'Fn') memang tidak dikirim — tidak ada padanan VK-nya.
library;

const Map<String, int> _special = {
  'Esc': 0x1B,
  'Tab': 0x09,
  'Caps': 0x14,
  'Shift': 0xA0,
  'Ctrl': 0xA2,
  'Win': 0x5B,
  'Alt': 0xA4,
  'Enter': 0x0D,
  'Del': 0x2E,
  '\u232B': 0x08, // Backspace (label ⌫)
  ' ': 0x20,
  '\u2191': 0x26, // panah atas
  '\u2193': 0x28, // panah bawah
  '\u2190': 0x25, // panah kiri
  '\u2192': 0x27, // panah kanan
  '`': 0xC0,
  '-': 0xBD,
  '=': 0xBB,
  '[': 0xDB,
  ']': 0xDD,
  ';': 0xBA,
  ',': 0xBC,
  '.': 0xBE,
  '/': 0xBF,
};

/// VK code untuk [label], atau null bila tidak ada padanan.
int? vkForLabel(String label) {
  final special = _special[label];
  if (special != null) return special;

  if (label.length == 1) {
    final c = label.codeUnitAt(0);
    // '0'..'9' dan 'A'..'Z' identik dengan VK code-nya.
    if (c >= 0x30 && c <= 0x39) return c;
    if (c >= 0x41 && c <= 0x5A) return c;
    if (c >= 0x61 && c <= 0x7A) return c - 0x20;
  }

  if (label.startsWith('F') && label.length <= 3) {
    final n = int.tryParse(label.substring(1));
    if (n != null && n >= 1 && n <= 12) return 0x70 + (n - 1); // VK_F1..F12
  }

  return null;
}
