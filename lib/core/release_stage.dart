/// Tahap rilis XyDesk — satu sumber kebenaran untuk seluruh aplikasi.
///
/// ## Kenapa berkas ini ada
///
/// XyDesk sudah punya tag `v6.1.0`, halaman unduh, dan tombol Download yang
/// menunjuk ke GitHub Release — padahal produknya **belum pernah masuk beta
/// test**. Artinya siapa pun yang menemukan situsnya bisa memasang build yang
/// jalur audio, multi-monitor, dan HUD-nya belum diverifikasi di perangkat
/// nyata. Itu bukan cuma pengalaman buruk; itu janji yang tidak bisa ditepati.
///
/// Selama [stage] belum `beta` atau `stable`, seluruh jalur distribusi publik
/// dimatikan dari SATU tempat ini — bukan dengan menghapus tombol satu per
/// satu di lima berkas, yang pasti terlewat salah satunya.
library;

/// Tahap peredaran build.
enum Stage {
  /// Dibangun dari `main`, belum diuji di lab. Tidak boleh diedarkan.
  praBeta,

  /// Diuji terbatas oleh penguji undangan.
  beta,

  /// Rilis publik.
  stabil,
}

class ReleaseStage {
  ReleaseStage._();

  /// Tahap saat ini. Naikkan HANYA setelah gerbang di `docs/VERSIONING.md`
  /// terpenuhi — bukan karena fiturnya "sudah ditulis".
  static const Stage stage = Stage.praBeta;

  /// Label pendek untuk UI, mis. "Pra-beta".
  static String get label => switch (stage) {
    Stage.praBeta => 'Pra-beta',
    Stage.beta => 'Beta',
    Stage.stabil => 'Stabil',
  };

  /// Benar bila build ini boleh diunduh publik.
  static bool get publicDownloadEnabled => stage != Stage.praBeta;

  /// Penjelasan yang ditampilkan saat unduhan dimatikan.
  static const String downloadDisabledReason =
      'XyDesk masih pra-beta. Jalur audio, multi-monitor, dan kontrol HUD '
      'belum diverifikasi di perangkat nyata, jadi paket publik sengaja '
      'ditahan sampai uji lab selesai.';
}
