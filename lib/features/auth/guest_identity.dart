/// Generator nama acak untuk sesi tamu.
///
/// Menghasilkan nama manusia Indonesia yang terdengar natural, bukan
/// "tamu-xxxx" yang kaku. Nama ini deterministik per sesi (dihasilakn
/// sekali saat guest login) dan konsisten selama sesi berlangsung.
library;

import 'dart:math';

/// Daftar nama depan Indonesia yang umum.
const _firstNames = [
  'Aditya',
  'Budi',
  'Citra',
  'Dewi',
  'Eko',
  'Fajar',
  'Gilang',
  'Hana',
  'Indra',
  'Joko',
  'Kirana',
  'Lukman',
  'Maya',
  'Nanda',
  'Oki',
  'Putri',
  'Raka',
  'Sari',
  'Taufik',
  'Umar',
  'Vina',
  'Wawan',
  'Yanti',
  'Zaki',
  'Arif',
  'Bella',
  'Cahya',
  'Dimas',
  'Elsa',
  'Farhan',
  'Gita',
  'Hendra',
  'Ika',
  'Jihan',
  'Kurnia',
  'Lestari',
  'Maulana',
  'Nisa',
  'Omar',
  'Putra',
  'Rizky',
  'Sinta',
  'Teguh',
  'Umi',
  'Vero',
  'Wulan',
  'Yusuf',
  'Zahra',
  'Bagas',
  'Cindy',
  'Dani',
  'Eva',
  'Faisal',
  'Galih',
  'Hesti',
  'Irwan',
  'Julia',
  'Kenji',
  'Lia',
  'Mirza',
  'Novi',
  'Okta',
  'Prima',
  'Rina',
];

/// Daftar nama belakang Indonesia yang umum.
const _lastNames = [
  'Pratama',
  'Saputra',
  'Wibowo',
  'Hidayat',
  'Nugroho',
  'Setiawan',
  'Kurniawan',
  'Santoso',
  'Wijaya',
  'Permadi',
  'Utama',
  'Surya',
  'Laksana',
  'Pranata',
  'Maulana',
  'Hakim',
  'Firmansyah',
  'Ramadhan',
  'Putra',
  'Dewanto',
  'Kusuma',
  'Ananda',
  'Sari',
  'Lestari',
  'Purnama',
  'Handayani',
  'Wulandari',
  'Kartika',
  'Anggraini',
  'Prasetyo',
  'Susanto',
  'Hartono',
  'Sutanto',
  'Tjandra',
  'Gunawan',
];

/// Hasilkan nama acak untuk tamu.
///
/// Format: "NamaDepan NamaBelakang" (contoh: "Aditya Pratama").
/// Menghasilkan nama yang terdengar seperti nama manusia Indonesia asli,
/// bukan "tamu-xxxx" yang terlihat artificial.
String generateGuestName() {
  final random = Random();
  final first = _firstNames[random.nextInt(_firstNames.length)];
  final last = _lastNames[random.nextInt(_lastNames.length)];
  return '$first $last';
}

/// Seed untuk avatar DiceBear tamu.
///
/// Dipakai agar avatar konsisten untuk seed yang sama — tamu dengan
/// nama "Budi Santoso" akan selalu mendapat avatar yang sama.
String generateGuestAvatarSeed(String name) {
  // Pakai nama sebagai seed, jadi avatar konsisten
  return name.replaceAll(' ', '_');
}
