//! Detail berita — konten penuh, like, komentar, dan berbagi.
//!
//! Berbagi memakai tautan `news.xystudio.my.id/n/:slug` yang merender
//! OpenGraph untuk crawler sosial (WhatsApp/Telegram/X/Facebook), lalu
//! mengarahkan manusia ke halaman web penuh.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tokens.dart';
import '../../widgets/seamless.dart';
import 'news_service.dart';

class NewsDetailPage extends ConsumerStatefulWidget {
  const NewsDetailPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends ConsumerState<NewsDetailPage> {
  NewsPost? _post;
  List<NewsComment> _comments = [];
  String? _error;
  bool _loading = true;

  int _likeCount = 0;
  bool _liked = false;
  bool _likeBusy = false;

  final _author = TextEditingController();
  final _commentText = TextEditingController();
  bool _commentBusy = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _author.dispose();
    _commentText.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (post, comments) = await ref
          .read(newsApiProvider)
          .detail(widget.slug);
      if (!mounted) return;
      setState(() {
        _post = post;
        _comments = comments;
        _likeCount = post.likeCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_likeBusy || _post == null) return;
    setState(() => _likeBusy = true);
    try {
      final (liked, count) = await ref
          .read(newsApiProvider)
          .toggleLike(widget.slug);
      if (!mounted) return;
      setState(() {
        _liked = liked;
        _likeCount = count;
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentText.text.trim();
    if (text.length < 2 || _commentBusy || _post == null) return;
    setState(() => _commentBusy = true);
    try {
      final name = _author.text.trim().isEmpty ? 'Anonim' : _author.text.trim();
      final c = await ref
          .read(newsApiProvider)
          .addComment(widget.slug, name, text);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, c];
        _commentText.clear();
        _notice = context.tr('news_comment_sent');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _notice = e.toString());
    } finally {
      if (mounted) setState(() => _commentBusy = false);
    }
  }

  Future<void> _share() async {
    final post = _post;
    if (post == null) return;
    final url = ref.read(newsApiProvider).shareUrl(post.slug);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('news_share'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: Gap.md),
              Text(
                'Kartu pratinjau (judul + gambar) dibuat otomatis oleh tautan ini.',
                style: TextStyle(fontSize: 12.5, color: ctx.c.textMid),
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  _ShareButton(
                    icon: LucideIcons.copy,
                    label: 'Salin',
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.tr('news_copied'))),
                        );
                      }
                    },
                  ),
                  _ShareButton(
                    icon: LucideIcons.messageCircle,
                    label: 'WhatsApp',
                    onTap: () async {
                      await launchUrl(
                        Uri.parse(
                          'https://wa.me/?text=${Uri.encodeComponent('${post.title} $url')}',
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  _ShareButton(
                    icon: LucideIcons.send,
                    label: 'Telegram',
                    onTap: () async {
                      await launchUrl(
                        Uri.parse(
                          'https://t.me/share/url?url=${Uri.encodeComponent(url)}&text=${Uri.encodeComponent(post.title)}',
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  _ShareButton(
                    icon: LucideIcons.link,
                    label: 'X',
                    onTap: () async {
                      await launchUrl(
                        Uri.parse(
                          'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(post.title)}&url=${Uri.encodeComponent(url)}',
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _date(String raw) {
    final iso = raw.contains('T') ? raw : '${raw.replaceFirst(' ', 'T')}Z';
    final d = DateTime.tryParse(iso);
    if (d == null) return raw;
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
  Widget build(BuildContext context) {
    final c = context.c;
    final post = _post;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(context.tr('news_title')),
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(Gap.screen),
              children: const [
                SkeletonBox(height: 180, radius: R.lg),
                SizedBox(height: Gap.lg),
                SkeletonBox(width: 220, height: 24),
                SizedBox(height: Gap.md),
                SkeletonBox(height: 12),
                SizedBox(height: 8),
                SkeletonBox(height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 160, height: 12),
              ],
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('news_load_error'),
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
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.screen,
                8,
                Gap.screen,
                Gap.h56,
              ),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.lg),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      post.cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: c.overlay,
                        child: Center(
                          child: Icon(
                            LucideIcons.newspaper,
                            size: 30,
                            color: c.textLow,
                          ),
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return ColoredBox(
                          color: c.overlay,
                          child: const Center(
                            child: SkeletonBox(width: 24, height: 24),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: Gap.lg),
                Text(
                  post.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: c.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${post.author} · ${_date(post.createdAt)}',
                  style: TextStyle(fontSize: 12, color: c.textLow),
                ),
                const SizedBox(height: Gap.lg),
                // ── Aksi ──
                Row(
                  children: [
                    _PillAction(
                      icon: LucideIcons.heart,
                      iconFilled: _liked,
                      label: '$_likeCount',
                      onTap: _toggleLike,
                      active: _liked,
                    ),
                    const SizedBox(width: 10),
                    _PillAction(
                      icon: LucideIcons.share2,
                      label: context.tr('news_share'),
                      onTap: _share,
                      active: false,
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xxl),
                for (final para in post.content.split(RegExp(r'\n\n+')))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.md),
                    child: Text(
                      para,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.65,
                        color: c.textHi.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                const SizedBox(height: Gap.lg),
                // ── Komentar ──
                Text(
                  '${context.tr('news_comments')} (${_comments.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Gap.md),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _author,
                        maxLength: 40,
                        decoration: InputDecoration(
                          hintText: context.tr('news_comment_name'),
                          counterText: '',
                          isDense: true,
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 13, color: c.textLow),
                        ),
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      TextField(
                        controller: _commentText,
                        maxLength: 1000,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: context.tr('news_comment_hint'),
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: c.textLow,
                          ),
                        ),
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      if (_notice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: Gap.sm),
                          child: Text(
                            _notice!,
                            style: TextStyle(fontSize: 12, color: c.textMid),
                          ),
                        ),
                      const SizedBox(height: Gap.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed:
                              _commentBusy ||
                                  _commentText.text.trim().length < 2
                              ? null
                              : _sendComment,
                          child: Text(
                            _commentBusy
                                ? '…'
                                : context.tr('news_comment_send'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),
                if (_comments.isEmpty)
                  Text(
                    context.tr('news_no_comments'),
                    style: TextStyle(fontSize: 13, color: c.textMid),
                  )
                else
                  for (final comment in _comments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.md),
                      child: SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  comment.author,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _date(comment.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: c.textLow,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              comment.content,
                              style: TextStyle(fontSize: 13.5, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.active,
    this.iconFilled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool iconFilled;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: active ? c.accentSoft : c.overlay,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: active ? c.accent : c.textMid),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? c.accent : c.textHi,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Material(
              color: c.overlay,
              borderRadius: BorderRadius.circular(R.lg),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(icon, size: 20, color: c.textHi),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, color: c.textMid)),
          ],
        ),
      ),
    );
  }
}
