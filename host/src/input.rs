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
//!                                               diinject sbg KEYEVENTF_UNICODE,
//!                                               per 32 karakter — lihat
//!                                               [`text_batches`] — dan dibuang
//!                                               di atas 4.096 unit UTF-16)
//! 0x07 DISPLAY_SELECT  index:u8                (pilih monitor; bukan injeksi)
//! 0x08 CLIPBOARD_SET   utf8 bytes (sisa pesan) (isi papan klip, dua arah)
//! 0x09 CLIPBOARD_REQ   (tanpa payload)         (minta lawan membalas 0x08)
//! ```
//!
//! Parser lintas platform; injeksi nyata hanya di Windows via `SendInput` —
//! API user-mode resmi, **tanpa driver**. Latensi inject < 1 ms; total budget
//! input path < 5 ms (lihat ARCHITECTURE.md).

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
    /// Pilih monitor host untuk capture (0 = primer). Bukan injeksi —
    /// ditangani loop utama sesi (lihat `main.rs`).
    DisplaySelect(usize),
    /// Isi papan klip — tulis teks ini ke papan klip sistem host.
    /// BUKAN injeksi keyboard: kalau dikirim sebagai tombol, teks dengan
    /// karakter non-ASCII akan rusak bergantung layout keyboard host.
    ClipboardSet(String),
    /// Minta host mengirim isi papan klipnya sebagai `ClipboardSet`.
    ClipboardRequest,
}

/// Tipe pesan (byte pertama).
mod tag {
    pub const MOUSE_MOVE_REL: u8 = 0x01;
    pub const MOUSE_MOVE_ABS: u8 = 0x02;
    pub const MOUSE_BUTTON: u8 = 0x03;
    pub const SCROLL: u8 = 0x04;
    pub const KEY: u8 = 0x05;
    pub const TEXT: u8 = 0x06;
    pub const DISPLAY_SELECT: u8 = 0x07;
    pub const CLIPBOARD_SET: u8 = 0x08;
    pub const CLIPBOARD_REQ: u8 = 0x09;
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
        (&tag::DISPLAY_SELECT, n) if n >= 2 => Some(InputEvent::DisplaySelect(data[1] as usize)),
        (&tag::CLIPBOARD_SET, n) if n >= 1 => std::str::from_utf8(&data[1..])
            .ok()
            .map(|s| InputEvent::ClipboardSet(s.to_string())),
        (&tag::CLIPBOARD_REQ, n) if n >= 1 => Some(InputEvent::ClipboardRequest),
        _ => None,
    }
}

/// Batas jumlah unit UTF-16 yang diketik dari SATU pesan `0x06 TEXT`.
///
/// Papan ketik sistem di client mengirim satu pesan per rentetan ketikan, jadi
/// menempel paragraf panjang berarti satu pesan berisi ribuan karakter. Host
/// yang harus **SELALU AKTIF** tidak boleh kehabisan napas karena satu pesan:
/// yang lewat batas ini dibuang, ketikan berikutnya tetap dilayani. Nilainya
/// jauh di atas panjang tempel biasa.
pub const MAX_TEXT_UNITS: usize = 4_096;

/// Unit UTF-16 per panggilan `SendInput`. Satu unit = dua event (turun + naik),
/// jadi 32 unit hanya 64 `INPUT` — di bawah `MAXINPUTS` (100) pada winuser.h.
const TEXT_BATCH_UNITS: usize = 32;

/// Rencana ketik untuk [`InputEvent::Text`]: unit UTF-16 yang diinject, dipecah
/// per [`TEXT_BATCH_UNITS`].
///
/// Sengaja fungsi murni (tanpa Win32) supaya bisa diuji lintas platform. Yang
/// diuji di sini bukan "ada panggilan SendInput", melainkan apa yang benar-
/// benar sampai ke jendela target: teks utuh dan berurutan, pasangan surrogate
/// tidak terbelah antar batch, dan pemotongan yang jatuh di batas karakter.
pub fn text_batches(s: &str) -> Vec<Vec<u16>> {
    let mut units: Vec<u16> = Vec::with_capacity(s.len());
    for ch in s.chars() {
        let mut buf = [0u16; 2];
        let enc = ch.encode_utf16(&mut buf);
        // Karakter yang tidak muat dibuang SELURUHNYA. Memotong di tengah
        // pasangan surrogate meninggalkan high surrogate menggantung, dan yang
        // muncul di jendela target bukan huruf berikutnya, melainkan karakter
        // rusak — gejalanya persis seperti "teks jadi aneh setelah spasi".
        if units.len() + enc.len() > MAX_TEXT_UNITS {
            break;
        }
        units.extend_from_slice(enc);
    }

    let mut out: Vec<Vec<u16>> = Vec::new();
    let mut i = 0;
    while i < units.len() {
        let mut end = (i + TEXT_BATCH_UNITS).min(units.len());
        if end < units.len() && is_high_surrogate(units[end - 1]) {
            // High surrogate di ujung batch: tarik pasangan di bawahnya ke
            // batch yang sama (lihat komentar di atas).
            end += 1;
        }
        out.push(units[i..end].to_vec());
        i = end;
    }
    out
}

fn is_high_surrogate(u: u16) -> bool {
    (0xD800..=0xDBFF).contains(&u)
}

/// Injector input — state ringan (tidak ada); satu fungsi murni per event.
pub struct Injector;

impl Injector {
    pub fn new() -> Self {
        Self
    }

    /// Eksekusi event pada OS. Di non-Windows hanya no-op untuk menjaga
    /// kompatibilitas kompilasi lintas platform. Return `false` bila OS
    /// menolak injeksi.
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
        MapVirtualKeyW, SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, INPUT_MOUSE, KEYBDINPUT,
        KEYBD_EVENT_FLAGS, KEYEVENTF_KEYUP, KEYEVENTF_SCANCODE, KEYEVENTF_UNICODE, MAPVK_VK_TO_VSC,
        MOUSEEVENTF_ABSOLUTE, MOUSEEVENTF_HWHEEL, MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP,
        MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP, MOUSEEVENTF_MOVE, MOUSEEVENTF_RIGHTDOWN,
        MOUSEEVENTF_RIGHTUP, MOUSEEVENTF_WHEEL, MOUSEEVENTF_XDOWN, MOUSEEVENTF_XUP, MOUSEINPUT,
        MOUSE_EVENT_FLAGS, VIRTUAL_KEY,
    };

    // Nilai resmi Win32 untuk field mouseData pada event tombol X.
    const XBUTTON1_DATA: i32 = 0x0001;
    const XBUTTON2_DATA: i32 = 0x0002;

    fn send(inputs: &[INPUT]) -> bool {
        // SAFETY: struct INPUT diisi lengkap; SendInput menyalin, tidak
        // menyimpan pointer.
        unsafe { SendInput(inputs, std::mem::size_of::<INPUT>() as i32) as usize == inputs.len() }
    }

    /// Sisipkan seluruh batch, melanjutkan sisa yang belum masuk.
    ///
    /// `SendInput` mengembalikan JUMLAH event yang benar-benar disisipkan —
    /// bukan sukses/gagal semuanya. Dokumentasi Win32 menyatakan batas
    /// berapa banyak yang bisa diproses sekali panggilan berbeda-beda antar
    /// versi Windows dan pemanggil wajib mengandalkan nilai kembali itu.
    /// Memakai `send()` untuk batch besar berarti paragraf panjang hilang
    /// sebagian TANPA jejak: fungsi menganggapnya berhasil hanya kalau semua
    /// masuk, dan sisanya tidak pernah dikirim ulang.
    fn send_all(inputs: &[INPUT]) -> bool {
        let size = std::mem::size_of::<INPUT>() as i32;
        let mut done = 0usize;
        // Percobaan terbatas: antrean input bisa macet bila ada jendela yang
        // berhenti mengambil pesannya. Thread injeksi tidak boleh menggantung
        // di situ — ia bertetangga dengan video dan koneksi sesi.
        for _ in 0..8 {
            let left = &inputs[done..];
            if left.is_empty() {
                return true;
            }
            // SAFETY: struct INPUT diisi lengkap; SendInput menyalin, tidak
            // menyimpan pointer.
            let sent = unsafe { SendInput(left, size) } as usize;
            if sent == 0 {
                // Nol = ditolak (UIPI, layar terkunci, secure desktop). Bukan
                // keadaan yang bisa dipaksa; callers sudah mencatat kegagalannya.
                return false;
            }
            done += sent;
        }
        false
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
                    (3, true) => (MOUSEEVENTF_XDOWN, XBUTTON1_DATA),
                    (3, false) => (MOUSEEVENTF_XUP, XBUTTON1_DATA),
                    (4, true) => (MOUSEEVENTF_XDOWN, XBUTTON2_DATA),
                    (4, false) => (MOUSEEVENTF_XUP, XBUTTON2_DATA),
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
                // layout keyboard host. Batch dipecah + sisa yang tidak masuk
                // dikirim ulang — lihat `text_batches` dan `send_all`.
                for batch in super::text_batches(s) {
                    let mut inputs = Vec::with_capacity(batch.len() * 2);
                    for unit in batch {
                        inputs.push(key(0, unit, KEYEVENTF_UNICODE));
                        inputs.push(key(0, unit, KEYEVENTF_UNICODE | KEYEVENTF_KEYUP));
                    }
                    if !send_all(&inputs) {
                        return false;
                    }
                }
                true
            }
            // Bukan injeksi — ditangani loop utama sesi (pindah monitor).
            InputEvent::DisplaySelect(_) => true,
            // Bukan injeksi juga. Papan klip butuh akses ke data channel
            // untuk membalas permintaan, dan thread injeksi ini tidak
            // memilikinya — keduanya ditangani di loop utama sesi. Nilai
            // `true` = bukan kegagalan, jangan dicatat sebagai inject gagal.
            InputEvent::ClipboardSet(_) | InputEvent::ClipboardRequest => true,
        }
    }
}

/// Encode isi papan klip untuk dikirim ke lawan (0x08 CLIPBOARD_SET).
///
/// Sengaja hidup bersebelahan dengan `decode`: format kawat harus punya satu
/// rumah. Kalau encoder dan decoder terpisah, salah satunya bisa berubah
/// tanpa yang lain — dan gejalanya baru terasa di tangan pengguna, bukan di
/// layar kompilator.
///
/// Batas 64 KiB dipotong di batas karakter, sama seperti klien, supaya ekor
/// UTF-8 yang tak lengkap tidak membuat seluruh pesan ditolak penerima.
pub fn encode_clipboard_set(text: &str) -> Vec<u8> {
    const MAX: usize = 64 * 1024;
    let bytes = text.as_bytes();
    let mut end = bytes.len();
    // Pembersihan ekor HANYA bila teksnya benar-benar dipotong. Byte
    // terakhir teks yang sah pun bisa berupa kelanjutan UTF-8, jadi
    // membersihkannya tanpa memotong berarti menghapus karakter terakhir
    // dan menyisakan byte lead yang menggantung — penerima lalu menolak
    // SELURUH pesan.
    if end > MAX {
        end = MAX;
        while end > 0 && (bytes[end] & 0xC0) == 0x80 {
            end -= 1;
        }
    }
    let mut out = Vec::with_capacity(1 + end);
    out.push(tag::CLIPBOARD_SET);
    out.extend_from_slice(&bytes[..end]);
    out
}

/// Encode permintaan isi papan klip (0x09 CLIPBOARD_REQ).
pub fn encode_clipboard_request() -> Vec<u8> {
    vec![tag::CLIPBOARD_REQ; 8]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clipboard_set_membawa_utf8_seluruh_sisa_pesan() {
        let mut m = vec![tag::CLIPBOARD_SET];
        m.extend_from_slice("Halo \u{1f525}".as_bytes());

        assert_eq!(
            decode(&m),
            Some(InputEvent::ClipboardSet("Halo \u{1f525}".to_string()))
        );
    }

    #[test]
    fn clipboard_set_kosong_diterima_bukan_dibuang() {
        // Papan klip yang dikosongkan itu keadaan sah. Kalau pesan 1 byte
        // ini dibuang, pengguna tidak pernah bisa mengosongkan papan klip PC.
        assert_eq!(
            decode(&[tag::CLIPBOARD_SET]),
            Some(InputEvent::ClipboardSet(String::new()))
        );
    }

    #[test]
    fn clipboard_set_utf8_rusak_ditolak() {
        // Jangan pernah menulis byte rusak ke papan klip sistem hanya karena
        // paketnya berhasil lewat.
        assert_eq!(decode(&[tag::CLIPBOARD_SET, 0xC3, 0x28]), None);
    }

    #[test]
    fn clipboard_req_tanpa_payload() {
        assert_eq!(
            decode(&[tag::CLIPBOARD_REQ; 8]),
            Some(InputEvent::ClipboardRequest)
        );
    }

    #[test]
    fn encode_clipboard_set_dan_kembali_lagi() {
        let m = encode_clipboard_set("Halo");
        assert_eq!(m[0], tag::CLIPBOARD_SET);
        assert_eq!(
            decode(&m),
            Some(InputEvent::ClipboardSet("Halo".to_string()))
        );
    }

    #[test]
    fn encode_clipboard_set_menjaga_karakter_non_ascii() {
        // Pernah melenceng: pembersihan ekor UTF-8 dijalankan walau teks
        // tidak dipotong, sehingga karakter terakhir yang sah ikut terbuang
        // dan menyisakan byte lead yang menggantung. Gejalanya bukan satu
        // huruf hilang, melainkan SELURUH pesan ditolak penerima.
        let isi = "Gaskeun \u{1f525} — \"mantap\"";
        let m = encode_clipboard_set(isi);
        assert_eq!(decode(&m), Some(InputEvent::ClipboardSet(isi.to_string())));
    }

    #[test]
    fn encode_clipboard_set_kosong_tetap_terbaca() {
        // Papan klip yang dikosongkan itu keadaan sah.
        let m = encode_clipboard_set("");
        assert_eq!(m, vec![tag::CLIPBOARD_SET]);
        assert_eq!(decode(&m), Some(InputEvent::ClipboardSet(String::new())));
    }

    #[test]
    fn encode_clipboard_set_memotong_di_batas_karakter() {
        // 'é' = 2 byte. Memotong di tengahnya membuat seluruh pesan ditolak.
        let m = encode_clipboard_set(&"é".repeat(200 * 1024));
        assert_eq!(m[0], tag::CLIPBOARD_SET);
        match decode(&m) {
            Some(InputEvent::ClipboardSet(s)) => assert!(s.ends_with('é')),
            lain => panic!("seharusnya tetap terbaca, dapat {lain:?}"),
        }
    }

    #[test]
    fn encode_clipboard_request_delapan_byte() {
        let m = encode_clipboard_request();
        assert_eq!(m.len(), 8);
        assert_eq!(decode(&m), Some(InputEvent::ClipboardRequest));
    }

    #[test]
    fn teks_pendek_satu_batch_dan_utuh() {
        assert_eq!(
            text_batches("halo"),
            vec![vec![b'h' as u16, b'a' as u16, b'l' as u16, b'o' as u16]]
        );
        assert!(
            text_batches("").is_empty(),
            "ketikan kosong = tidak ada apa pun untuk diketik"
        );
    }

    #[test]
    fn teks_panjang_dipecah_tanpa_menghilangkan_apa_pun() {
        // 500 karakter campuran ('e' aksen = 1 unit, emoji = 2 unit) = 2000
        // unit: jauh di atas satu batch, masih di bawah batas buang.
        let isi = "a\u{00e9}\u{1f525}".repeat(500);
        let batch = text_batches(&isi);
        assert!(
            batch.len() > 1,
            "seharusnya dipecah, dapat {} batch",
            batch.len()
        );
        assert!(
            batch.iter().all(|b| b.len() <= TEXT_BATCH_UNITS + 1),
            "batch terlalu besar untuk satu panggilan SendInput: {:?}",
            batch.iter().map(|b| b.len()).collect::<Vec<_>>()
        );
        assert_eq!(
            String::from_utf16(&batch.concat()).expect("urutan utuh"),
            isi
        );
    }

    #[test]
    fn pasangan_surrogate_tidak_terbelah_antar_batch() {
        // Emoji sengaja dijatuhkan TEPAT di batas batch. Kalau high surrogate
        // menutup satu batch dan low surrogate membuka batch berikutnya,
        // banyak aplikasi tidak menggabungkannya lagi: yang tampil karakter
        // rusak, bukan emoji.
        let isi = "a".repeat(TEXT_BATCH_UNITS - 1) + "\u{1f600}" + "z";
        let batch = text_batches(&isi);
        assert_eq!(batch[0].len(), TEXT_BATCH_UNITS + 1);
        assert_eq!(batch[1], vec!['z' as u16]);
        assert_eq!(String::from_utf16(&batch.concat()).unwrap(), isi);
    }

    #[test]
    fn teks_melebihi_batas_dibuang_di_batas_karakter() {
        // Pas di batas: karakter terakhir boleh membawa dua unit.
        let pas = "a".repeat(MAX_TEXT_UNITS - 2) + "\u{1f600}";
        assert_eq!(text_batches(&pas).concat().len(), MAX_TEXT_UNITS);

        // Satu unit lebih: emoji itu hilang SELURUHNYA, tidak ditinggal
        // setengah (setengah pasangan = karakter rusak di jendela target).
        let lebih = "a".repeat(MAX_TEXT_UNITS - 1) + "\u{1f600}";
        assert_eq!(text_batches(&lebih).concat().len(), MAX_TEXT_UNITS - 1);
    }

    #[test]
    fn text_pesan_besar_tetap_terbaca_oleh_host() {
        // Batas panjang ada di jalur inject, BUKAN di parser: pesan TEXT besar
        // harus tetap didekode (lalu dipotong atau dibuang rapi), bukan membuat
        // seluruh pesan dianggap rusak.
        let isi = "x".repeat(9000);
        let mut m = vec![tag::TEXT];
        m.extend_from_slice(isi.as_bytes());
        assert_eq!(decode(&m), Some(InputEvent::Text(isi)));
    }

    #[test]
    fn clipboard_tidak_tertukar_dengan_text() {
        // 0x06 = ketikkan teks ini. 0x08 = jadikan ini isi papan klip.
        // Tertukar berarti setiap ketikan pengguna menimpa papan klip PC.
        let mut m = vec![tag::TEXT];
        m.extend_from_slice("a".as_bytes());

        assert_eq!(decode(&m), Some(InputEvent::Text("a".to_string())));
        assert_ne!(decode(&m), Some(InputEvent::ClipboardSet("a".to_string())));
    }
}
