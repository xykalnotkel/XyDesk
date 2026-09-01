// Kontrak kawat (wire contract) encoder input.
//
// Setiap angka di bawah ini HARUS cocok dengan `host/src/input.rs`
// (modul `tag` + fungsi `decode`). Kalau kedua sisi pernah melenceng,
// gejalanya tidak pernah berupa error — melainkan kursor yang melompat,
// tombol yang nyangkut, atau ketikan yang hilang di mesin pengguna.
// Karena itu layout byte-nya dikunci oleh test, bukan oleh komentar.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:xydesk/webrtc/input_codec.dart';
import 'package:xydesk/webrtc/vk_codes.dart';

/// Baca u16 little-endian dari [bytes] pada offset [offset].
int _u16(Uint8List bytes, int offset) =>
    ByteData.view(bytes.buffer).getUint16(offset, Endian.little);

/// Baca i16 little-endian dari [bytes] pada offset [offset].
int _i16(Uint8List bytes, int offset) =>
    ByteData.view(bytes.buffer).getInt16(offset, Endian.little);

void main() {
  group('tag pesan', () {
    test('setiap jenis pesan memakai tag yang diharapkan host', () {
      // Urutan tag ini identik dengan konstanta di host/src/input.rs.
      expect(InputCodec.mouseMoveRel(0, 0)[0], 0x01);
      expect(InputCodec.mouseMoveAbs(0, 0)[0], 0x02);
      expect(InputCodec.mouseButton(0, down: true)[0], 0x03);
      expect(InputCodec.scroll(0, 0)[0], 0x04);
      expect(InputCodec.key(0, down: true)[0], 0x05);
      expect(InputCodec.text('a')[0], 0x06);
      expect(InputCodec.displaySelect(0)[0], 0x07);
    });
  });

  group('mouse', () {
    test('gerak relatif: dx di byte 1..2, dy di byte 3..4, little-endian', () {
      final msg = InputCodec.mouseMoveRel(-2, 300);

      expect(msg.length, 8);
      expect(_i16(msg, 1), -2);
      expect(_i16(msg, 3), 300);
      // Byte sisa tidak boleh berisi sampah.
      expect(msg.sublist(5), [0, 0, 0]);
    });

    test('gerak relatif menjepit nilai di luar jangkauan i16', () {
      final msg = InputCodec.mouseMoveRel(-99999, 99999);

      expect(_i16(msg, 1), -32768);
      expect(_i16(msg, 3), 32767);
    });

    test('gerak absolut: fraksi 0..1 dinormalisasi ke 0..65535', () {
      expect(_u16(InputCodec.mouseMoveAbs(0.0, 0.0), 1), 0);
      expect(_u16(InputCodec.mouseMoveAbs(0.0, 0.0), 3), 0);
      expect(_u16(InputCodec.mouseMoveAbs(1.0, 1.0), 1), 65535);
      expect(
        _u16(InputCodec.mouseMoveAbs(0.5, 0.25), 1),
        32768, // 32767.5 dibulatkan
        reason: 'setengah lebar = tengah layar',
      );
      expect(_u16(InputCodec.mouseMoveAbs(0.5, 0.25), 3), 16384);
    });

    test('gerak absolut menjepit fraksi di luar 0..1', () {
      final msg = InputCodec.mouseMoveAbs(-1.5, 4.0);

      expect(_u16(msg, 1), 0, reason: 'lebih kiri dari 0 tetap 0');
      expect(_u16(msg, 3), 65535, reason: 'lebih kanan dari 1 tetap 65535');
    });

    test('tombol: kode tombol di byte 1, status tekan di byte 2', () {
      final down = InputCodec.mouseButton(MouseButton.right, down: true);
      final up = InputCodec.mouseButton(MouseButton.right, down: false);

      expect(down[1], MouseButton.right);
      expect(down[2], 1);
      expect(up[2], 0);
      expect(up.sublist(3), [0, 0, 0, 0, 0]);
    });

    test('kode tombol sesuai urutan protokol host', () {
      expect(MouseButton.left, 0);
      expect(MouseButton.right, 1);
      expect(MouseButton.middle, 2);
      expect(MouseButton.x1, 3);
      expect(MouseButton.x2, 4);
    });

    test('scroll memakai lebar i16 dan mempertahankan tanda', () {
      final msg = InputCodec.scroll(0, -120);

      expect(msg.length, 8);
      expect(_i16(msg, 3), -120, reason: 'scroll ke bawah = negatif');
      expect(_i16(msg, 1), 0);
    });
  });

  group('keyboard', () {
    test('tombol: vk di byte 1..2, status tekan di byte 3', () {
      final msg = InputCodec.key(0x41, down: true); // 'A'

      expect(msg.length, 8);
      expect(_u16(msg, 1), 0x41);
      expect(msg[3], 1);
      expect(InputCodec.key(0x41, down: false)[3], 0);
    });

    test('vk code dari label tombol virtual', () {
      expect(vkForLabel('A'), 0x41);
      expect(vkForLabel('a'), 0x41, reason: 'huruf kecil diseragamkan');
      expect(vkForLabel('7'), 0x37);
      expect(vkForLabel('Esc'), 0x1B);
      expect(vkForLabel('Enter'), 0x0D);
      expect(vkForLabel(' '), 0x20);
      expect(vkForLabel('⌫'), 0x08);
      expect(vkForLabel('↑'), 0x26);
      expect(vkForLabel('F1'), 0x70);
      expect(vkForLabel('F12'), 0x7B);
    });

    test('label tanpa padanan VK tidak dikirim (null)', () {
      expect(vkForLabel('Fn'), isNull);
      expect(vkForLabel('F13'), isNull);
      expect(vkForLabel('F0'), isNull);
      expect(vkForLabel('😀'), isNull);
    });

    test('teks: tag 0x06 lalu UTF-8, tanpa terminator', () {
      final msg = InputCodec.text('Halo Bang');

      expect(msg[0], 0x06);
      expect(utf8.decode(msg.sublist(1)), 'Halo Bang');
      expect(msg.length, 1 + utf8.encode('Halo Bang').length);
    });

    test('teks multi-byte Utuh (aksen dan emoji tidak boleh patah)', () {
      final msg = InputCodec.text('café 🚀');

      expect(utf8.decode(msg.sublist(1)), 'café 🚀');
      // UTF-8 untuk string ini lebih panjang dari jumlah karakter.
      expect(msg.length, greaterThan('café 🚀'.length + 1));
    });

    test('teks kosong hanya berisi tag', () {
      final msg = InputCodec.text('');

      expect(msg, [0x06]);
    });
  });

  group('pilih monitor', () {
    test('indeks monitor di byte 1', () {
      expect(InputCodec.displaySelect(2)[1], 2);
      expect(InputCodec.displaySelect(0)[1], 0);
    });

    test('indeks di luar 0..255 dijepit, tidak meluap ke byte lain', () {
      final msg = InputCodec.displaySelect(999);

      expect(msg[1], 255);
      expect(msg.length, 8);
      expect(InputCodec.displaySelect(-5)[1], 0);
    });
  });

  group('panjang pesan', () {
    test('semua pesan non-teks panjangnya tetap 8 byte', () {
      // Host membaca panjang tetap untuk pesan 0x01..0x05 dan 0x07.
      // Kalau salah satu tiba-tiba lebih pendek, host membuang pesannya.
      expect(InputCodec.mouseMoveRel(1, 1).length, 8);
      expect(InputCodec.mouseMoveAbs(1, 1).length, 8);
      expect(InputCodec.mouseButton(1, down: true).length, 8);
      expect(InputCodec.scroll(1, 1).length, 8);
      expect(InputCodec.key(1, down: true).length, 8);
      expect(InputCodec.displaySelect(1).length, 8);
    });
  });
}
