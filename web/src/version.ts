// Sumber tunggal versi & tahap rilis untuk aplikasi web.
//
// ## Kenapa berkas ini ada
//
// Footer situs sempat menampilkan "XyDesk versi lama yang beku" saat aplikasi yang berjalan
// sudah 6.1.0 — angka itu diketik tangan di JSX dan tidak pernah ikut naik
// saat rilis. Nomor versi yang salah bukan cuma jelek dipandang: ia membuat
// laporan bug tidak bisa dipercaya, karena pelapor menyebut versi yang tidak
// pernah ada.
//
// Sekarang `__APP_VERSION__` disuntik saat build oleh `vite.config.ts` yang
// MEMBACA `pubspec.yaml` — sumber yang sama dengan APK dan installer. Tidak
// ada lagi tempat kedua untuk lupa.

declare const __APP_VERSION__: string;

/// Contoh: "6.2.0".
export const APP_VERSION: string =
  typeof __APP_VERSION__ === 'string' ? __APP_VERSION__ : '0.0.0';

/// Tahap peredaran build. Cerminan `lib/core/release_stage.dart`.
export type Stage = 'pra-beta' | 'beta' | 'stabil';

export const RELEASE_STAGE: Stage = 'pra-beta';

export const STAGE_LABEL: Record<Stage, string> = {
  'pra-beta': 'Pra-beta',
  beta: 'Beta',
  stabil: 'Stabil',
};

/// Unduhan publik hanya dibuka mulai tahap beta.
///
/// Selama ini situs memajang tombol Download yang menunjuk ke GitHub Release,
/// padahal produknya belum pernah masuk beta test: audio, multi-monitor, dan
/// HUD belum diverifikasi di perangkat nyata. Menahan tombolnya jauh lebih
/// murah daripada menarik kembali kepercayaan orang yang memasang build yang
/// belum siap.
export const DOWNLOAD_ENABLED: boolean = RELEASE_STAGE !== 'pra-beta';

export const DOWNLOAD_DISABLED_REASON =
  'XyDesk belum masuk masa uji coba. Suara, multi-monitor, dan kontrol dari ' +
  'HP belum pernah kami coba di komputer sungguhan, jadi file-nya sengaja ' +
  'kami tahan dulu. Lebih baik menunggu daripada kamu memasang sesuatu yang ' +
  'belum tentu jalan.';

/// Slug artikel changelog rilis saat ini di XyDesk News.
///
/// Setiap rilis WAJIB punya artikelnya. Tautan versi di seluruh situs
/// menunjuk ke sini — bukan ke GitHub Releases, yang menampilkan catatan
/// mentah untuk pengembang, bukan penjelasan untuk pengguna.
export const CHANGELOG_SLUG = `changelog-v${APP_VERSION.replace(/\./g, '-')}`;
