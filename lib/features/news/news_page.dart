//! Tab Berita — feed publik dari news.xystudio.my.id (sama dengan web/desktop).
//!
//! Keadaan dimuat jujur: skeleton saat memuat, pesan galat + tombol coba lagi
//! saat jaringan gagal, dan empty state per kategori. Tidak ada konten dummy.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/tokens.dart';
import '../../core/devlog.dart';
import '../../widgets/seamless.dart';
import 'news_detail_page.dart';
import 'news_service.dart';

class NewsPage extends ConsumerStatefulWidget {
  const NewsPage({super.key});

  @override
  ConsumerState<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends ConsumerState<NewsPage> {
  String _category = 'semua';
  List<NewsPost>? _posts;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _posts = null;
    });
    try {
      final posts = await ref.read(newsApiProvider).list(category: _category);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
      DevLog.i(
        'news',
        'Dimuat',
        '${posts.length} post (${_category == 'semua' ? 'semua' : _category})',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _selectCategory(String c) {
    if (_category == c) return;
    setState(() => _category = c);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 44,
        bottom: 120,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('news_title'), style: t.headlineMedium),
              const SizedBox(height: 7),
              Text(
                context.tr('news_subtitle'),
                style: TextStyle(fontSize: 12.5, color: c.textMid, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
        // ── Kategori ──
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
            itemCount: newsCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = newsCategories[i];
              final on = _category == cat;
              return ChoiceChip(
                label: Text(cat == 'semua' ? context.tr('news_all') : cat),
                selected: on,
                onSelected: (_) => _selectCategory(cat),
                showCheckmark: false,
                side: BorderSide.none,
                backgroundColor: c.overlay,
                selectedColor: c.accentSoft,
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: on ? c.textHi : c.textMid,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              );
            },
          ),
        ),
        const SizedBox(height: Gap.lg),
        if (_loading) ..._skeletonList(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(Gap.xxl),
            child: Column(
              children: [
                Text(
                  context.tr('news_load_error'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: c.textMid),
                ),
                const SizedBox(height: Gap.md),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(LucideIcons.refreshCw, size: 15),
                  label: Text(context.tr('news_retry')),
                ),
              ],
            ),
          ),
        if (_posts != null && _posts!.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Gap.xxl),
            child: Text(
              context.tr('news_empty'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textMid),
            ),
          ),
        if (_posts != null && _posts!.isNotEmpty)
          for (final post in _posts!) _NewsCard(post: post),
      ],
    );
  }

  List<Widget> _skeletonList() {
    return [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.screen, 0, Gap.screen, Gap.lg),
          child: SurfaceCard(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 108, height: 64, radius: R.md),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 110, height: 12),
                      SizedBox(height: 10),
                      SkeletonBox(height: 11),
                      SizedBox(height: 6),
                      SkeletonBox(width: 180, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _NewsCard extends ConsumerWidget {
  const _NewsCard({required this.post});

  final NewsPost post;

  String _date(BuildContext context) {
    final raw = post.createdAt;
    final iso = raw.contains('T') ? raw : '${raw.replaceFirst(' ', 'T')}Z';
    final d = DateTime.tryParse(iso);
    if (d == null) return raw.substring(0, raw.length >= 10 ? 10 : raw.length);
    final local = d.toLocal();
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${local.day} ${bulan[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.screen, 0, Gap.screen, Gap.lg),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => NewsDetailPage(slug: post.slug)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(R.lg),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 8.4,
                child: Image.network(
                  post.cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: c.overlay,
                    child: Center(
                      child: Icon(
                        LucideIcons.newspaper,
                        size: 26,
                        color: c.textLow,
                      ),
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return ColoredBox(
                      color: c.overlay,
                      child: const Center(
                        child: SkeletonBox(width: 22, height: 22),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textMid,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        _date(context),
                        style: TextStyle(fontSize: 11, color: c.textLow),
                      ),
                      const Spacer(),
                      Icon(LucideIcons.heart, size: 13, color: c.textLow),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likeCount}',
                        style: TextStyle(fontSize: 11, color: c.textLow),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        LucideIcons.messageCircle,
                        size: 13,
                        color: c.textLow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.commentCount}',
                        style: TextStyle(fontSize: 11, color: c.textLow),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
