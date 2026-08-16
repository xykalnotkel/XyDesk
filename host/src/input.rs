//! Injeksi input (mouse/keyboard) — jalur balik yang latency-nya sama
//! pentingnya dengan video.
//!
//! ## Protokol biner (data channel "input")
//!
//! Untuk gaming, JSON terlalu boros (parse + alokasi per event; mouse move
//! bisa ratusan event/detik). Event dikirim **biner little-endian, 8 byte
//! tetap** (kecuali TEXT yang variabel):
//!
//! ```text
//! byte 0  : tipe event
//! byte 1-7: payload (padding nol bila tak terpakai)
//!
//! 0x01 MOUSE_MOVE_REL  dx:i16  dy:i16          (relatif, untuk mode FPS)
//! 0x02 MOUSE_MOVE_ABS  x:u16   y:u16           (0..65535 ternormalisasi —
//!                                               cocok langsung dgn
//!                                               MOUSEEVENTF_ABSOLUTE)
//! 0x03 MOUSE_BUTTON    btn:u8  down:u8         (0=kiri 1=kanan 2=tengah
//!                                               3=x1 4=x2)
//! 0x04 SCROLL          dx:i16  dy:i16          (satuan WHEEL_DELTA=120)
//! 0x05 KEY             vk:u16  down:u8         (Windows Virtual-Key code)
//! 0x06 TEXT            utf8 bytes (sisa pesan) (dari keyboard virtual;
//!                                               diinject sbg KEYEVENTF_UNICODE)
//! ```
//!
//! Parser lintas platform (bisa diuji di CI Linux); injeksi nyata hanya di
//! Windows via `SendInput` — API user-mode resmi, **tanpa driver**. Latensi
//! inject < 1 ms; total budget input path < 5 ms (lihat ARCHITECTURE.md).

/// Event input hasil dekode dari data channel.
#[derive(Clone, Debug, PartialEq)]
pub enum InputEvent {
    /// Gerak relatif (dx, dy) piksel — mode trackpad/FPS.
    MouseMoveRel { dx: i16, dy: i16 },
    /// Posisi absolut ternormalisasi 0..=65535 pada layar primer.
    MouseMoveAbs { x: u16, y: u16 },
    /// Tombol mouse. `button`: 0 kiri, 1 kanan, 2 tengah, 3 x1, 4 x2.
    MouseButton { button: u8, down: bool },
    /// Scroll dalam satuan WHEEL_DELTA (120 = satu "klik" roda).
    Scroll { dx: i16, dy: i16 },
    /// Tombol keyboard, Windows Virtual-Key code.
    Key { vk: u16, down: bool },
    /// Teks bebas (keyboard virtual) — diinject sebagai unicode.
    Text(String),
}

/// Tipe pesan (byte pertama).
mod tag {
    pub const MOUSE_MOVE_REL: u8 = 0x01;
    pub const MOUSE_MOVE_ABS: u8 = 0x02;
    pub const MOUSE_BUTTON: u8 = 0x03;
    pub const SCROLL: u8 = 0x04;
    pub const KEY: u8 = 0x05;
    pub const TEXT: u8 = 0x06;
}

/// Dekode satu pesan biner. `None` bila tidak valid (pesan dibuang diam-diam
/// — input rusak tidak boleh mematikan sesi).
pub fn decode(data: &[u8]) -> Option<InputEvent> {
    let le16 = |a: &[u8], i: usize| u16::from_le_bytes([a[i], a[i + 1]]);
    match (data.first()?, data.len()) {
        (&tag::MOUSE_MOVE_REL, n) if n >= 5 => Some(InputEvent::MouseMoveRel {
            dx: le16(data, 1) as i16,
            dy: le16(data, 3) as i16,
        }),
        (&tag::MOUSE_MOVE_ABS, n) if n >= 5 => Some(InputEvent::MouseMoveAbs {
            x: le16(data, 1),
            y: le16(data, 3),
        }),
        (&tag::MOUSE_BUTTON, n) if n >= 3 => Some(InputEvent::MouseButton {
            button: data[1],
            down: data[2] != 0,
        }),
        (&tag::SCROLL, n) if n >= 5 => Some(InputEvent::Scroll {
            dx: le16(data, 1) as i16,
            dy: le16(data, 3) as i16,
        }),
        (&tag::KEY, n) if n >= 4 => Some(InputEvent::Key {
            vk: le16(data, 1),
            down: data[3] != 0,
        }),
        (&tag::TEXT, n) if n >= 2 => std::str::from_utf8(&data[1..])
            .ok()
            .map(|s| InputEvent::Text(s.to_string())),
        _ => None,
    }
}

/// Injector input — state ringan (tidak ada); satu fungsi murni per event.
pub struct Injector;

impl Injector {
    pub fn new() -> Self {
        Self
    }

    /// Eksekusi event pada OS. Di non-Windows hanya no-op (dipakai saat uji
    /// jalur di Linux). Return `false` bila OS menolak injeksi.
    pub fn inject(&self, ev: &InputEvent) -> bool {
        #[cfg(target_os = "windows")]
        {
            windows_inject::inject(ev)
        }
        #[cfg(not(target_os = "windows"))]
        {
            let _ = ev;
            true
        }
    }
}

impl Default for Injector {
    fn default() -> Self {
        Self::new()
    }
}

// ── Implementasi Windows: SendInput (user-mode, tanpa driver) ─────────────
#[cfg(target_os = "windows")]
mod windows_inject {
    use super::InputEvent;
    use windows::Win32::UI::Input::KeyboardAndMouse::{
        SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, INPUT_MOUSE, KEYBDINPUT, KEYBD_EVENT_FLAGS,
        KEYEVENTF_KEYUP, KEYEVENTF_SCANCODE, KEYEVENTF_UNICODE, MOUSEEVENTF_ABSOLUTE,
        MOUSEEVENTF_HWHEEL, MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, MOUSEEVENTF_MIDDLEDOWN,
        MOUSEEVENTF_MIDDLEUP, MOUSEEVENTF_MOVE, MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP,
        MOUSEEVENTF_WHEEL, MOUSEEVENTF_XDOWN, MOUSEEVENTF_XUP, MOUSEINPUT, MOUSE_EVENT_FLAGS,
        MAPVK_VK_TO_VSC, MapVirtualKeyW, VIRTUAL_KEY, XBUTTON1, XBUTTON2,
    };

    fn send(inputs: &[INPUT]) -> bool {
        // SAFETY: struct INPUT diisi lengkap; SendInput menyalin, tidak
        // menyimpan pointer.
        unsafe { SendInput(inputs, std::mem::size_of::<INPUT>() as i32) as usize == inputs.len() }
    }

    fn mouse(flags: MOUSE_EVENT_FLAGS, dx: i32, dy: i32, data: i32) -> INPUT {
        INPUT {
            r#type: INPUT_MOUSE,
            Anonymous: INPUT_0 {
                mi: MOUSEINPUT {
                    dx,
                    dy,
                    mouseData: data as u32,
                    dwFlags: flags,
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        }
    }

    fn key(vk: u16, scan: u16, flags: KEYBD_EVENT_FLAGS) -> INPUT {
        INPUT {
            r#type: INPUT_KEYBOARD,
            Anonymous: INPUT_0 {
                ki: KEYBDINPUT {
                    wVk: VIRTUAL_KEY(vk),
                    wScan: scan,
                    dwFlags: flags,
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        }
    }

    pub fn inject(ev: &InputEvent) -> bool {
        match *ev {
            InputEvent::MouseMoveRel { dx, dy } => {
                send(&[mouse(MOUSEEVENTF_MOVE, dx as i32, dy as i32, 0)])
            }
            InputEvent::MouseMoveAbs { x, y } => send(&[mouse(
                MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE,
                x as i32,
                y as i32,
                0,
            )]),
            InputEvent::MouseButton { button, down } => {
                let (flags, data) = match (button, down) {
                    (0, true) => (MOUSEEVENTF_LEFTDOWN, 0),
                    (0, false) => (MOUSEEVENTF_LEFTUP, 0),
                    (1, true) => (MOUSEEVENTF_RIGHTDOWN, 0),
                    (1, false) => (MOUSEEVENTF_RIGHTUP, 0),
                    (2, true) => (MOUSEEVENTF_MIDDLEDOWN, 0),
                    (2, false) => (MOUSEEVENTF_MIDDLEUP, 0),
                    (3, true) => (MOUSEEVENTF_XDOWN, XBUTTON1.0 as i32),
                    (3, false) => (MOUSEEVENTF_XUP, XBUTTON1.0 as i32),
                    (4, true) => (MOUSEEVENTF_XDOWN, XBUTTON2.0 as i32),
                    (4, false) => (MOUSEEVENTF_XUP, XBUTTON2.0 as i32),
                    _ => return false,
                };
                send(&[mouse(flags, 0, 0, data)])
            }
            InputEvent::Scroll { dx, dy } => {
                let mut inputs = Vec::with_capacity(2);
                if dy != 0 {
                    inputs.push(mouse(MOUSEEVENTF_WHEEL, 0, 0, dy as i32));
                }
                if dx != 0 {
                    inputs.push(mouse(MOUSEEVENTF_HWHEEL, 0, 0, dx as i32));
                }
                inputs.is_empty() || send(&inputs)
            }
            InputEvent::Key { vk, down } => {
                // Sertakan scancode — banyak game membaca scancode (raw
                // input), bukan virtual key.
                let scan = unsafe { MapVirtualKeyW(vk as u32, MAPVK_VK_TO_VSC) } as u16;
                let mut flags = KEYEVENTF_SCANCODE;
                if !down {
                    flags |= KEYEVENTF_KEYUP;
                }
                send(&[key(vk, scan, flags)])
            }
            InputEvent::Text(ref s) => {
                // KEYEVENTF_UNICODE: ketik karakter apa pun tanpa peduli
                // layout keyboard host. Surrogate pair utk emoji dll.
                let mut inputs = Vec::new();
                for unit in s.encode_utf16() {
                    inputs.push(key(0, unit, KEYEVENTF_UNICODE));
                    inputs.push(key(0, unit, KEYEVENTF_UNICODE | KEYEVENTF_KEYUP));
                }
                inputs.is_empty() || send(&inputs)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decode_mouse_move_rel_negatif() {
        // dx=-10, dy=3 (little-endian two's complement)
        let dx = (-10i16).to_le_bytes();
        let dy = 3i16.to_le_bytes();
        let msg = [0x01, dx[0], dx[1], dy[0], dy[1], 0, 0, 0];
        assert_eq!(
            decode(&msg),
            Some(InputEvent::MouseMoveRel { dx: -10, dy: 3 })
        );
    }

    #[test]
    fn decode_mouse_move_abs() {
        let x = 32768u16.to_le_bytes();
        let y = 65535u16.to_le_bytes();
        let msg = [0x02, x[0], x[1], y[0], y[1], 0, 0, 0];
        assert_eq!(
            decode(&msg),
            Some(InputEvent::MouseMoveAbs { x: 32768, y: 65535 })
        );
    }

    #[test]
    fn decode_button_dan_key() {
        assert_eq!(
            decode(&[0x03, 1, 1, 0, 0, 0, 0, 0]),
            Some(InputEvent::MouseButton {
                button: 1,
                down: true
            })
        );
        // VK_SPACE = 0x20, keyup
        assert_eq!(
            decode(&[0x05, 0x20, 0x00, 0, 0, 0, 0, 0]),
            Some(InputEvent::Key {
                vk: 0x20,
                down: false
            })
        );
    }

    #[test]
    fn decode_scroll() {
        let dy = 120i16.to_le_bytes();
        let msg = [0x04, 0, 0, dy[0], dy[1], 0, 0, 0];
        assert_eq!(decode(&msg), Some(InputEvent::Scroll { dx: 0, dy: 120 }));
    }

    #[test]
    fn decode_text_utf8() {
        let mut msg = vec![0x06];
        msg.extend_from_slice("halo 世界".as_bytes());
        assert_eq!(decode(&msg), Some(InputEvent::Text("halo 世界".into())));
    }

    #[test]
    fn decode_rusak_tidak_panik() {
        assert_eq!(decode(&[]), None);
        assert_eq!(decode(&[0x01, 1]), None); // terlalu pendek
        assert_eq!(decode(&[0xFF, 0, 0, 0, 0, 0, 0, 0]), None); // tag tak dikenal
        assert_eq!(decode(&[0x06, 0xFF, 0xFE]), None); // utf8 invalid
    }

    #[test]
    fn injector_non_windows_noop() {
        let inj = Injector::new();
        assert!(inj.inject(&InputEvent::MouseMoveRel { dx: 1, dy: 1 }));
    }
}
