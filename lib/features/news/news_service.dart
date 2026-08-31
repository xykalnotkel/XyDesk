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
  });

  final int id;
  final String author;
  final String content;
  final String createdAt;

  factory NewsComment.fromJson(Map<String, dynamic> j) => NewsComment(
    id: j['id'] as int? ?? 0,
    author: j['author'] as String? ?? '',
    content: j['content'] as String? ?? '',
    createdAt: j['createdAt'] as String? ?? '',
  );
}

/// Kategori berita yang dipakai filter UI.
const newsCategories = ['semua', 'rilis', 'teknik', 'umum'];

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

  Future<(NewsPost, List<NewsComment>)> detail(String slug) async {
    final data = await _getJson(Uri.parse('$newsBase/api/news/$slug'));
    final post = NewsPost.fromJson(data['post'] as Map<String, dynamic>);
    final comments = [
      for (final c in data['comments'] as List? ?? [])
        NewsComment.fromJson(c as Map<String, dynamic>),
    ];
    return (post, comments);
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
    String content,
  ) async {
    final data = await _getJson(
      Uri.parse('$newsBase/api/news/$slug/comments'),
      method: 'POST',
      body: {'fp': fingerprint, 'author': author, 'content': content},
    );
    return NewsComment.fromJson(data['comment'] as Map<String, dynamic>);
  }

  String shareUrl(String slug) => '$newsShareBase/$slug';
}

final newsApiProvider = Provider<NewsApi>((ref) {
  final store = ref.read(storeProvider);
  return NewsApi(store);
});
