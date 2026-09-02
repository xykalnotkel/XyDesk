//! Klien News XyDesk — API publik di Worker terpisah (D1).
//!
//! `https://news.xystudio.my.id` — sama dengan yang dipakai web & desktop.
//! Berita publik tanpa akun; like idempoten per sidik jari perangkat,
//! komentar dibatasi lajunya di server.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/devlog.dart';
import '../../core/store.dart';

const newsBase = 'https://news.xystudio.my.id';
const newsShareBase = 'https://news.xystudio.my.id/n';

class NewsPost {
  const NewsPost({
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.cover,
    required this.category,
    required this.author,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
  });

  final String slug;
  final String title;
  final String excerpt;
  final String content;
  final String cover;
  final String category;
  final String author;
  final String createdAt;
  final int likeCount;
  final int commentCount;

  factory NewsPost.fromJson(Map<String, dynamic> j) => NewsPost(
    slug: j['slug'] as String? ?? '',
    title: j['title'] as String? ?? '',
    excerpt: j['excerpt'] as String? ?? '',
    content: j['content'] as String? ?? '',
    cover: j['cover'] as String? ?? '',
    category: j['category'] as String? ?? 'umum',
    author: j['author'] as String? ?? 'Tim XyDesk',
    createdAt: j['createdAt'] as String? ?? '',
    likeCount: j['likeCount'] as int? ?? 0,
    commentCount: j['commentCount'] as int? ?? 0,
  );
}

class NewsComment {
  const NewsComment({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.official = false,
  });

  final int id;
  final String author;
  final String content;
  final String createdAt;

  /// ID komentar induk — non-null berarti ini balasan.
  final int? parentId;

  /// Badge resmi tim XyDesk. Ditetapkan SERVER dari ADMIN_TOKEN; klien tidak
  /// bisa memintanya lewat body. Nama tim juga dikunci di worker, jadi tidak
  /// ada komentar publik yang bisa tampil sebagai "Haekal Saputra".
  final bool official;

  factory NewsComment.fromJson(Map<String, dynamic> j) => NewsComment(
    id: j['id'] as int? ?? 0,
    author: j['author'] as String? ?? '',
    content: j['content'] as String? ?? '',
    createdAt: j['createdAt'] as String? ?? '',
    parentId: j['parentId'] as int?,
    official: j['official'] as bool? ?? false,
  );
}

/// Kategori berita yang dipakai filter UI.
const newsCategories = ['semua', 'rilis', 'teknik', 'umum'];

/// Daftar nama manusia untuk komentator — salinan `web/src/news.ts`
/// (NAME_FIRST / NAME_LAST) supaya aturan pembangkitan identik lintas
/// platform: perangkat yang sama selalu dapat nama yang sama, dan kolom
/// komentar terasa hidup (bukan "tamu-xxxx").
const _nameFirst = [
  'Raka',
  'Sinta',
  'Bima',
  'Dewi',
  'Aldi',
  'Nadia',
  'Fajar',
  'Laras',
  'Galih',
  'Ayu',
  'Reza',
  'Putri',
  'Dimas',
  'Ratna',
  'Yoga',
  'Salsa',
  'Ilham',
  'Maya',
  'Rio',
  'Tania',
  'Bagus',
  'Intan',
  'Eka',
  'Wulan',
  'Arif',
  'Citra',
  'Damar',
  'Nirmala',
  'Panji',
  'Kirana',
  'Satria',
  'Anggi',
];

const _nameLast = [
  'Saputra',
  'Pratama',
  'Lestari',
  'Wijaya',
  'Ramadhan',
  'Maharani',
  'Nugroho',
  'Anggraini',
  'Santoso',
  'Utami',
  'Firmansyah',
  'Puspita',
  'Hidayat',
  'Safitri',
  'Kurniawan',
  'Melati',
  'Gunawan',
  'Andini',
  'Prasetyo',
  'Rahayu',
  'Mahendra',
  'Paramita',
  'Wibowo',
  'Larasati',
];

class NewsApiException implements Exception {
  NewsApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NewsApi {
  NewsApi(this._store);

  final Store _store;

  /// Sidik jari perangkat (tanpa akun) — dibuat sekali dan disimpan.
  /// Cukup untuk idempotensi like dan batas laju komentar.
  String get fingerprint {
    final existing = _store.getStr('news_fp');
    if (existing != null && existing.isNotEmpty) return existing;
    final rng = Random.secure();
    final fp = List.generate(
      32,
      (_) => rng.nextInt(16).toRadixString(16),
    ).join();
    _store.setStr('news_fp', fp);
    return fp;
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{'content-type': 'application/json'};
    late final http.Response res;
    try {
      if (method == 'POST') {
        res = await http
            .post(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 12));
      } else {
        res = await http.get(uri).timeout(const Duration(seconds: 12));
      }
    } catch (e) {
      DevLog.w('news', 'jaringan gagal', '$e');
      throw NewsApiException('Tidak dapat menghubungi layanan berita.');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw NewsApiException(
        (data['error'] as String?) ?? 'HTTP ${res.statusCode}',
      );
    }
    return data;
  }

  Future<List<NewsPost>> list({String? category}) async {
    final q = <String, String>{'limit': '30'};
    if (category != null && category != 'semua') q['category'] = category;
    final uri = Uri.parse('$newsBase/api/news').replace(queryParameters: q);
    final data = await _getJson(uri);
    return [
      for (final p in data['posts'] as List? ?? [])
        NewsPost.fromJson(p as Map<String, dynamic>),
    ];
  }

  /// Detail artikel. Sidik jari ikut dikirim supaya server bisa memberi tahu
  /// apakah perangkat ini sudah menyukai artikelnya.
  Future<(NewsPost, List<NewsComment>, bool)> detail(String slug) async {
    final uri = Uri.parse(
      '$newsBase/api/news/$slug',
    ).replace(queryParameters: {'fp': fingerprint});
    final data = await _getJson(uri);
    final post = NewsPost.fromJson(data['post'] as Map<String, dynamic>);
    final comments = [
      for (final c in data['comments'] as List? ?? [])
        NewsComment.fromJson(c as Map<String, dynamic>),
    ];
    return (post, comments, data['liked'] as bool? ?? false);
  }

  /// Toggle like; kembalikan (liked, likeCount) terbaru.
  Future<(bool, int)> toggleLike(String slug) async {
    final data = await _getJson(
      Uri.parse('$newsBase/api/news/$slug/like'),
      method: 'POST',
      body: {'fp': fingerprint},
    );
    return (data['liked'] as bool? ?? false, data['likeCount'] as int? ?? 0);
  }

  Future<NewsComment> addComment(
    String slug,
    String author,
    String content, {
    int? parentId,
  }) async {
    final data = await _getJson(
      Uri.parse('$newsBase/api/news/$slug/comments'),
      method: 'POST',
      body: {
        'fp': fingerprint,
        'author': author,
        'content': content,
        if (parentId != null) 'parentId': parentId,
      },
    );
    return NewsComment.fromJson(data['comment'] as Map<String, dynamic>);
  }

  /// Nama tampilan acak per perangkat — tidak ada kolom nama manual.
  /// Stabil antar sesi, dan identik caranya dengan web (`web/src/news.ts`):
  /// turunan deterministik dari sidik jari perangkat memilih satu nama dari
  /// daftar nama manusia. Orang yang sama selalu muncul dengan nama sama.
  ///
  /// Pengguna lama yang masih tersimpan `tamu-xxxx` ikut dibangkitkan ulang
  /// (sama seperti web) supaya kolom komentar tidak lagi menampilkan label
  /// teknis setelah pembaruan ini.
  String get displayName {
    final existing = _store.getStr('news_display_name');
    if (existing != null &&
        existing.isNotEmpty &&
        !existing.startsWith('tamu-')) {
      return existing;
    }
    // Hash sama dengan web: h = (h*31 + charCode) >>> 0, lalu h % jumlah
    // nama depan untuk nama depan, dan (h / jumlahNamaDepan) % jumlah nama
    // belakang untuk nama belakang.
    final fp = fingerprint;
    var h = 0;
    for (var i = 0; i < fp.length; i++) {
      h = (h * 31 + fp.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    final first = _nameFirst[h % _nameFirst.length];
    final last = _nameLast[(h ~/ _nameFirst.length) % _nameLast.length];
    final name = '$first $last';
    _store.setStr('news_display_name', name);
    return name;
  }

  /// Daftarkan email untuk langganan berita (kirim via Resend saat artikel
  /// baru terbit).
  Future<(bool, String)> subscribe(String email) async {
    final data = await _getJson(
      Uri.parse('$newsBase/api/subscribe'),
      method: 'POST',
      body: {'email': email},
    );
    return (data['ok'] as bool? ?? false, 'ok');
  }

  String shareUrl(String slug) => '$newsShareBase/$slug';
}

final newsApiProvider = Provider<NewsApi>((ref) {
  final store = ref.read(storeProvider);
  return NewsApi(store);
});
