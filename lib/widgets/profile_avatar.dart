import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/store.dart';
import '../core/tokens.dart';

/// Foto profil yang bisa diubah pengguna.
///
/// Disimpan lokal (`shared_preferences`) sebagai sebuah nilai teks, jadi
/// tidak butuh akun/backend dan tidak menambahkan dependensi. Nilainya:
///   - `preset:<seed>`  → avatar DiceBear dari seed preset (gratis, tanpa
///     kunci API, tanpa backend) — wajah konsisten untuk seed yang sama.
///   - `url:<encoded>`  → URL gambar sendiri (PNG/JPEG/SVG).
///   - kosong           → fallback ke inisial nama (perilaku lama).
///
/// Kolom penuh "upload foto lalu simpan ke Cloudinary" butuh `image_picker`
/// + pembaruan `docs/THIRD-PARTY-LICENSES.md` (Dependensi Baru → CI). Itu
/// dicatat sebagai pekerjaan lintas role di `HANDOFF.md`, sehingga sesi ini
/// memakai jalur preset/URL yang sudah bekerja penuh.

const _avatarKey = 'profile_avatar';

/// Seed DiceBear untuk pilah avatar preset. Nama-nama ini cuma dipakai
/// sebagai benih gambar — bukan identitas pengguna.
const profileAvatarSeeds = <String>[
  'Biru',
  'Kirana',
  'Tania',
  'Raka',
  'Intan',
  'Damar',
];

String? loadAvatar(Store store) => store.getStr(_avatarKey);
Future<void> saveAvatar(Store store, String value) =>
    store.setStr(_avatarKey, value);

/// URL gambar DiceBear `adventurer` (SVG) untuk sebuah seed.
String presetAvatarUrl(String seed) {
  final s = Uri.encodeComponent(seed);
  return 'https://api.dicebear.com/9.x/adventurer/svg'
      '?seed=$s&backgroundColor=ede9fe,fde68a,bbf7d0,bae6fd';
}

/// Baca nilai avatar → (jenis, payload).
({bool isPreset, String payload}) parseAvatar(String? value) {
  if (value == null) return (isPreset: false, payload: '');
  if (value.startsWith('preset:')) {
    return (isPreset: true, payload: value.substring(7));
  }
  if (value.startsWith('url:')) {
    return (isPreset: false, payload: value.substring(4));
  }
  return (isPreset: false, payload: '');
}

/// Avatar profil yang dipakai di header Akun dan tombol di topbar.
///
/// Menampilkan (berurutan):
///   1. preset DiceBear (SVG)
///   2. URL gambar sendiri (SVG/PNG/JPEG)
///   3. inisial nama di atas gradient brand (perilaku lama)
/// Tidak pernah membuat layar gagal: kalau gambar tidak termuat, kembali
/// ke inisial.
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.initial,
    this.size = 52,
    this.bordered = false,
  });

  /// Nama tampilan (dipakai untuk fallback & seed bila nilai bukan preset).
  final String name;
  final String initial;
  final double size;

  /// Menampilkan cincin aksen tipis (untuk tombol topbar).
  final bool bordered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final store = ref.watch(storeProvider);
    final value = loadAvatar(store);
    final parsed = parseAvatar(value);

    final fallback = Text(
      initial,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.36,
        fontWeight: FontWeight.w700,
      ),
    );

    Widget inner;
    if (parsed.isPreset) {
      inner = SvgPicture.network(
        presetAvatarUrl(parsed.payload),
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => fallback,
      );
    } else if (parsed.payload.isNotEmpty) {
      inner = Image.network(
        parsed.payload,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback;
        },
      );
    } else {
      inner = fallback;
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent, const Color(0xFF8A5CF6)],
        ),
        border: bordered
            ? Border.all(color: c.accent.withValues(alpha: 0.55), width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: c.accent.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: inner,
    );
  }
}

/// Widget tombol avatar di topbar — menampilkan [ProfileAvatar] kecil
/// (atau inisial) dan membuka edit avatar saat diketuk.
class TopbarAvatarButton extends ConsumerWidget {
  const TopbarAvatarButton({
    super.key,
    required this.name,
    required this.initial,
    required this.onTap,
  });

  final String name;
  final String initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Foto profil',
      onPressed: onTap,
      padding: EdgeInsets.zero,
      icon: ProfileAvatar(
        name: name,
        initial: initial,
        size: 30,
        bordered: true,
      ),
      iconSize: 30,
    );
  }
}

/// Ikon fallback saat gambar avatar gagal (untuk dialog preset/URL).
IconData avatarFallbackIcon() => LucideIcons.user;
