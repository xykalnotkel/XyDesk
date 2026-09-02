// Encoder protokol input biner — HARUS identik dengan host/src/input.rs.
//
// Format: little-endian, 8 byte tetap (TEXT variabel):
//   0x01 MOUSE_MOVE_REL  dx:i16 dy:i16
//   0x02 MOUSE_MOVE_ABS  x:u16  y:u16   (0..65535 ternormalisasi)
//   0x03 MOUSE_BUTTON    btn:u8 down:u8 (0 kiri, 1 kanan, 2 tengah, 3 x1, 4 x2)
//   0x04 SCROLL          dx:i16 dy:i16  (WHEEL_DELTA = 120)
//   0x05 KEY             vk:u16 down:u8 (Windows Virtual-Key code)
//   0x06 TEXT            utf8 (sisa pesan)
//   0x07 DISPLAY_SELECT  index:u8
//   0x08 CLIPBOARD_SET   utf8 (sisa pesan) — isi papan klip, dua arah
//   0x09 CLIPBOARD_REQ   (tanpa payload)   — minta lawan membalas 0x08
//
// Kenapa biner, bukan JSON? Mouse move bisa >100 event/detik; 8 byte vs
// ~50 byte JSON + tanpa parse JSON di host = input path lebih hemat.

import 'dart:convert';
import 'dart:typed_data';

/// Tombol mouse sesuai protokol.
class MouseButton {
  static const int left = 0;
  static const int right = 1;
  static const int middle = 2;
  static const int x1 = 3;
  static const int x2 = 4;
}

class InputCodec {
  InputCodec._();

  static Uint8List _msg8(int tag) {
    final b = Uint8List(8);
    b[0] = tag;
    return b;
  }

  /// 0x07 DISPLAY_SELECT — minta host memindahkan capture ke monitor lain
  /// (indeks dari daftar yang dikirim host via pesan meta).
  static Uint8List displaySelect(int index) {
    final b = _msg8(0x07);
    b[1] = index.clamp(0, 255).toInt();
    return b;
  }

  /// Gerak mouse relatif (mode trackpad / FPS). dx, dy dalam piksel host.
  static Uint8List mouseMoveRel(int dx, int dy) {
    final b = _msg8(0x01);
    ByteData.view(b.buffer)
      ..setInt16(1, dx.clamp(-32768, 32767), Endian.little)
      ..setInt16(3, dy.clamp(-32768, 32767), Endian.little);
    return b;
  }

  /// Posisi absolut ternormalisasi 0..=65535 pada layar host.
  /// Beri (fraksi 0..1) dari lebar/tinggi video, bukan piksel.
  static Uint8List mouseMoveAbs(double fx, double fy) {
    final b = _msg8(0x02);
    ByteData.view(b.buffer)
      ..setUint16(1, (fx.clamp(0.0, 1.0) * 65535).round(), Endian.little)
      ..setUint16(3, (fy.clamp(0.0, 1.0) * 65535).round(), Endian.little);
    return b;
  }

  /// Tombol mouse (lihat [MouseButton]).
  static Uint8List mouseButton(int button, {required bool down}) {
    final b = _msg8(0x03);
    b[1] = button;
    b[2] = down ? 1 : 0;
    return b;
  }

  /// Scroll; 120 = satu klik roda (WHEEL_DELTA). dy positif = menjauh dari
  /// pengguna (scroll ke atas), konvensi Windows.
  static Uint8List scroll(int dx, int dy) {
    final b = _msg8(0x04);
    ByteData.view(b.buffer)
      ..setInt16(1, dx.clamp(-32768, 32767), Endian.little)
      ..setInt16(3, dy.clamp(-32768, 32767), Endian.little);
    return b;
  }

  /// Tombol keyboard — [vk] adalah Windows Virtual-Key code
  /// (mis. 0x41 'A', 0x20 Space, 0x1B Esc).
  static Uint8List key(int vk, {required bool down}) {
    final b = _msg8(0x05);
    ByteData.view(b.buffer).setUint16(1, vk, Endian.little);
    b[3] = down ? 1 : 0;
    return b;
  }

  /// Teks bebas dari keyboard virtual — host mengetik sebagai unicode,
  /// tidak tergantung layout keyboard host.
  static Uint8List text(String s) {
    final utf8Bytes = utf8.encode(s);
    final b = Uint8List(1 + utf8Bytes.length);
    b[0] = 0x06;
    b.setRange(1, b.length, utf8Bytes);
    return b;
  }

  /// 0x08 CLIPBOARD_SET — isi papan klip, UTF-8 mulai byte 1, panjang
  /// variabel. Dipakai dua arah: HP mengirim isi papan klipnya ke PC, dan
  /// PC membalas 0x09 dengan pesan ini.
  ///
  /// Dipisah dari 0x06 TEXT dengan sengaja: TEXT berarti "ketikkan ini",
  /// CLIPBOARD_SET berarti "jadikan ini isi papan klipmu". Mencampurnya
  /// berarti setiap teks yang diketik pengguna akan menimpa papan klip PC
  /// — dan sebaliknya.
  ///
  /// Teks yang lebih panjang dari [_clipboardMaxBytes] dipotong: papan klip
  /// yang tersinkronisasi tidak boleh membanjiri data channel sampai
  /// menggeser paket input mouse dan keyboard.
  static Uint8List clipboardSet(String s) {
    final utf8Bytes = utf8.encode(s);
    var end = utf8Bytes.length <= clipboardMaxBytes ? utf8Bytes.length : clipboardMaxBytes;
    // Potongan bisa jatuh di tengah karakter multi-byte (aksara non-Latin
    // memakai sampai 4 byte). Buang ekor yang tidak lengkap supaya yang
    // terkirim selalu UTF-8 sah — kalau tidak, penerima menolak seluruh
    // pesan hanya gara-gara satu karakter kepotong di ujung.
    while (end > 0 && (utf8Bytes[end - 1] & 0xC0) == 0x80) {
      end--;
    }
    final b = Uint8List(1 + end);
    b[0] = 0x08;
    b.setRange(1, b.length, utf8Bytes.sublist(0, end));
    return b;
  }

  /// 0x09 CLIPBOARD_REQ — minta lawan mengirim isi papan klipnya. Ia
  /// membalas dengan 0x08.
  ///
  /// Kenapa model tarik (pull), bukan pantau terus-menerus: host tidak punya
  /// pengamat papan klip Windows yang bisa berjalan tanpa jendela pesan,
  /// jadi menjanjikan "PC → HP otomatis" akan berujung pada janji palsu.
  /// Diminta eksplisit, hasilnya pasti.
  static Uint8List clipboardRequest() => _msg8(0x09);

  /// Mengurai pesan 0x08 yang datang dari lawan.
  ///
  /// Mengembalikan `null` bila pesannya bukan CLIPBOARD_SET atau isinya
  /// bukan UTF-8 yang sah — jangan pernah menuliskan byte rusak ke papan
  /// klip perangkat hanya karena paketnya berhasil lewat.
  /// Papan klip kosong dinyatakan sebagai string kosong (bukan null).
  static String? decodeClipboardSet(Uint8List b) {
    if (b.isEmpty || b[0] != 0x08) return null;
    if (b.length - 1 > clipboardMaxBytes) return null;
    if (b.length == 1) return '';
    try {
      return const Utf8Decoder().convert(b.sublist(1));
    } catch (_) {
      return null;
    }
  }

  /// Batas ukuran teks papan klip yang dikirim (64 KiB).
  ///
  /// Sengaja publik: uji perlu merujuk angka yang sama, dan kalau batasnya
  /// berubah, uji ikut berubah — bukan diam-diam meleset.
  static const int clipboardMaxBytes = 64 * 1024;
}
