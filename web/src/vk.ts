// Pemetaan KeyboardEvent.code (browser) -> Windows Virtual-Key code.
// Kontrak sisi host: host/src/input.rs. Cermin dari lib/webrtc/vk_codes.dart.

const MAP: Record<string, number> = {
  Escape: 0x1b,
  Tab: 0x09,
  CapsLock: 0x14,
  ShiftLeft: 0xa0,
  ShiftRight: 0xa1,
  ControlLeft: 0xa2,
  ControlRight: 0xa3,
  AltLeft: 0xa4,
  AltRight: 0xa5,
  MetaLeft: 0x5b,
  MetaRight: 0x5c,
  Enter: 0x0d,
  Backspace: 0x08,
  Delete: 0x2e,
  Insert: 0x2d,
  Home: 0x24,
  End: 0x23,
  PageUp: 0x21,
  PageDown: 0x22,
  Space: 0x20,
  ArrowUp: 0x26,
  ArrowDown: 0x28,
  ArrowLeft: 0x25,
  ArrowRight: 0x27,
  Backquote: 0xc0,
  Minus: 0xbd,
  Equal: 0xbb,
  BracketLeft: 0xdb,
  BracketRight: 0xdd,
  Backslash: 0xdc,
  Semicolon: 0xba,
  Quote: 0xde,
  Comma: 0xbc,
  Period: 0xbe,
  Slash: 0xbf,
};

/// VK code untuk KeyboardEvent.code, atau null bila tak ada padanan.
export function vkFromCode(code: string): number | null {
  const direct = MAP[code];
  if (direct !== undefined) return direct;
  if (/^Key[A-Z]$/.test(code)) return code.charCodeAt(3); // KeyA..KeyZ
  if (/^Digit[0-9]$/.test(code)) return code.charCodeAt(5); // Digit0..9
  if (/^F([1-9]|1[0-2])$/.test(code)) {
    return 0x70 + parseInt(code.slice(1), 10) - 1; // F1..F12
  }
  if (/^Numpad[0-9]$/.test(code)) return 0x60 + Number(code.slice(6));
  return null;
}

/// Baris tombol keyboard virtual layar sentuh (label -> VK).
export const TOUCH_ROWS: [string, number][][] = [
  [
    ['Esc', 0x1b],
    ['Tab', 0x09],
    ['Win', 0x5b],
    ['Alt', 0xa4],
    ['Ctrl', 0xa2],
    ['Del', 0x2e],
  ],
  [
    ['F1', 0x70],
    ['F2', 0x71],
    ['F4', 0x73],
    ['F5', 0x74],
    ['F11', 0x7a],
    ['\u232b', 0x08],
  ],
  [
    ['\u2190', 0x25],
    ['\u2191', 0x26],
    ['\u2193', 0x28],
    ['\u2192', 0x27],
    ['Spasi', 0x20],
    ['Enter', 0x0d],
  ],
];
