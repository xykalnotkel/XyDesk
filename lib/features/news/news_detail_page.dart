//! Detail berita — konten penuh, like, komentar, dan berbagi.
//!
//! Berbagi memakai tautan `news.xydesk.my.id/n/:slug` yang merender
//! OpenGraph untuk crawler sosial (WhatsApp/Telegram/X/Facebook), lalu
//! mengarahkan manusia ke halaman web penuh.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n_bridge.dart';
import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/official_badge.dart';
import '../../widgets/seamless.dart';
import 'news_service.dart';
import '../../widgets/brand_icons.dart';

/// Blok gambar di badan berita: baris sendiri berbentuk
/// `![keterangan](url)`. Hanya gambar dari domain sendiri
/// (`app.xydesk.my.id`) yang dirender — sesuai `docs/NEWS_STYLE.md`;
/// baris lain tetap tampil sebagai paragraf biasa. Meniru web
/// (`NEWS_IMAGE_BLOCK` di `web/src/App.tsx`).
final _newsImageBlock = RegExp(
  r'^!\[([^\]]*)\]\((https://app\.xystudio\.my\.id/[^\s)]+)\)$',
);

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

  final _commentText = TextEditingController();
  bool _commentBusy = false;
  String? _notice;

  /// Komentar yang sedang dibalas — non-null saat mode balas aktif.
  NewsComment? _replyTo;

  // Langganan email berita.
  final _emailCtrl = TextEditingController();
  bool _subBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Tanpa listener ini, tombol "Kirim" tidak pernah aktif saat pengguna
    // mengetik — teks di TextField berubah, tetapi widget tidak di-build
    // ulang sehingga `_commentText.text.trim().length < 2` tetap dibaca
    // dari nilai awal (kosong). Ini juga yang membuat tombol balasan tampak
    // "tidak sinkron": setState datang hanya saat pengiriman, bukan saat
    // mengetik.
    _commentText.addListener(() => setState(() {}));
    _emailCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _commentText.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (post, comments, liked) = await ref
          .read(newsApiProvider)
          .detail(widget.slug);
      if (!mounted) return;
      setState(() {
        _post = post;
        _comments = comments;
        _likeCount = post.likeCount;
        _liked = liked;
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
    // Terisi duluan, baru kirim. Menunggu jaringan sebelum hati berubah
    // membuat tombolnya terasa tidak menanggapi.
    final before = _liked;
    final beforeCount = _likeCount;
    setState(() {
      _likeBusy = true;
      _liked = !before;
      _likeCount = beforeCount + (before ? -1 : 1);
    });
    HapticFeedback.selectionClick();
    try {
      final (liked, count) = await ref
          .read(newsApiProvider)
          .toggleLike(widget.slug);
      if (!mounted) return;
      setState(() {
        _liked = liked;
        _likeCount = count;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = before;
        _likeCount = beforeCount;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  /// Nama penulis komentar: akun jika sudah masuk, nama manusia deterministik
  /// jika tamu (tidak pernah lagi "tamu-xxxx").
  String _commentAuthor() {
    final session = ref.read(authProvider);
    if (!session.isGuest) {
      final name = session.name?.trim();
      if (name != null && name.isNotEmpty) return name;
      final email = session.email?.trim();
      if (email != null && email.isNotEmpty) return email.split('@').first;
      return context.tr('account_user');
    }
    return ref.read(newsApiProvider).displayName;
  }

  Future<void> _sendComment() async {
    final text = _commentText.text.trim();
    if (text.length < 2 || _commentBusy || _post == null) return;
    setState(() => _commentBusy = true);
    try {
      // Akun terbaca lewat profil bila login; tamu memakai nama acak yang
      // deterministik (tetap dapat avatar dari DiceBear).
      final name = _commentAuthor();
      final c = await ref
          .read(newsApiProvider)
          .addComment(widget.slug, name, text, parentId: _replyTo?.id);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, c];
        _commentText.clear();
        _replyTo = null;
        _notice = context.tr('news_comment_sent');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _notice = e.toString());
    } finally {
      if (mounted) setState(() => _commentBusy = false);
    }
  }

  Future<void> _subscribe() async {
    final email = _emailCtrl.text.trim();
    if (_subBusy || email.isEmpty || !email.contains('@')) return;
    setState(() {
      _subBusy = true;
      _notice = null;
    });
    try {
      final (ok, _) = await ref.read(newsApiProvider).subscribe(email);
      if (!mounted) return;
      setState(() {
        _notice = ok
            ? context.tr('news_subscribe_ok')
            : context.tr('news_subscribe_dup');
        if (ok) _emailCtrl.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _notice = context.tr('news_subscribe_err'));
    } finally {
      if (mounted) setState(() => _subBusy = false);
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
                'Judul dan gambar akan muncul otomatis di aplikasi tujuan.',
                style: TextStyle(fontSize: 12.5, color: ctx.c.textMid),
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  _ShareButton(
                    label: 'Salin tautan',
                    child: Icon(
                      LucideIcons.copy,
                      size: 20,
                      color: ctx.c.textHi,
                    ),
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
                  for (final entry in _shareTargets(post.title, url).entries)
                    _ShareButton(
                      label: brandMarks[entry.key]!.label,
                      child: brandMarks[entry.key]!.icon(),
                      onTap: () async {
                        await launchUrl(
                          Uri.parse(entry.value),
                          mode: LaunchMode.externalApplication,
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

  /// Tautan berbagi per platform. Dipisah dari widget supaya daftarnya
  /// mudah dibaca dan mudah ditambah.
  Map<SharePlatform, String> _shareTargets(String title, String url) {
    final t = Uri.encodeComponent(title);
    final u = Uri.encodeComponent(url);
    return {
      SharePlatform.whatsapp:
          'https://wa.me/?text=${Uri.encodeComponent('$title $url')}',
      SharePlatform.telegram: 'https://t.me/share/url?url=$u&text=$t',
      SharePlatform.x: 'https://twitter.com/intent/tweet?text=$t&url=$u',
      SharePlatform.facebook: 'https://www.facebook.com/sharer/sharer.php?u=$u',
    };
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

  /// Satu blok isi berita. Baris gambar `![keterangan](url)` — hanya URL
  /// domain sendiri (`app.xydesk.my.id`) — dirender sebagai gambar
  /// berbingkai + keterangan; baris lain tetap paragraf biasa. Meniru web.
  Widget _newsContentBlock(BuildContext context, String para) {
    final c = context.c;
    final img = _newsImageBlock.firstMatch(para.trim());
    if (img == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Gap.md),
        child: Text(
          para,
          style: TextStyle(
            fontSize: 15,
            height: 1.65,
            color: c.textHi.withValues(alpha: 0.92),
          ),
        ),
      );
    }

    final alt = (img.group(1) ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(R.lg),
            child: Image.network(
              img.group(2)!,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: c.overlay,
                child: Center(
                  child: Icon(LucideIcons.imageOff, size: 26, color: c.textLow),
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
          if (alt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                alt,
                style: TextStyle(fontSize: 11.5, color: c.textLow),
              ),
            ),
        ],
      ),
    );
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
          : post == null
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
                // Artikel hanya bisa terbit lewat endpoint admin, jadi
                // penulisnya resmi menurut konstruksi.
                AuthorName(
                  name: post.author,
                  official: true,
                  trailing: _date(post.createdAt),
                  fontSize: 12.5,
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
                  _newsContentBlock(context, para),
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
                      // Mode balas: tunjukkan komentar yang sedang dibalas.
                      if (_replyTo != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${context.tr('news_reply_to')} '
                                  '${_replyTo!.author}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: c.accent,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(LucideIcons.x, size: 15),
                                color: c.textLow,
                                tooltip: context.tr('news_reply_cancel'),
                                onPressed: () =>
                                    setState(() => _replyTo = null),
                              ),
                            ],
                          ),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CommentAvatar(
                                  author: comment.author,
                                  official: comment.official,
                                  size: 32,
                                ),
                                const SizedBox(width: Gap.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: AuthorName(
                                              name: comment.author,
                                              official: comment.official,
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
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                          ),
                                          icon: const Icon(
                                            LucideIcons.cornerUpLeft,
                                            size: 13,
                                          ),
                                          label: Text(
                                            context.tr('news_reply'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          onPressed: () {
                                            setState(() => _replyTo = comment);
                                            _commentText.clear();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Balasan (satu tingkat) tampil menjorok di bawah.
                            for (final reply in _comments.where(
                              (r) => r.parentId == comment.id,
                            ))
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  left: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 2,
                                      height: 34,
                                      margin: const EdgeInsets.only(
                                        top: 3,
                                        right: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c.accent.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CommentAvatar(
                                                author: reply.author,
                                                official: reply.official,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: AuthorName(
                                                  name: reply.author,
                                                  official: reply.official,
                                                  trailing: _date(
                                                    reply.createdAt,
                                                  ),
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            reply.content,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                // ── Langganan email berita ──
                const SizedBox(height: Gap.xl),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('news_subscribe_title'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('news_subscribe_sub'),
                        style: TextStyle(fontSize: 12.5, color: c.textMid),
                      ),
                      const SizedBox(height: Gap.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: context.tr(
                                  'news_subscribe_email_hint',
                                ),
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: c.textLow,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: Gap.sm),
                          FilledButton(
                            onPressed: _subBusy ? null : _subscribe,
                            child: Text(
                              _subBusy ? '…' : context.tr('news_subscribe_btn'),
                            ),
                          ),
                        ],
                      ),
                    ],
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
              AnimatedScale(
                scale: active ? 1.12 : 1,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                child: Icon(
                  // Hati kosong berubah jadi hati penuh saat disukai. Dulu
                  // parameter iconFilled ada tapi tidak pernah dipakai, jadi
                  // tombolnya tidak pernah kelihatan aktif.
                  iconFilled && active ? Icons.favorite : icon,
                  size: 15,
                  color: active ? c.accent : c.textMid,
                ),
              ),
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
    required this.child,
    required this.label,
    required this.onTap,
  });

  /// Logo platform, atau ikon biasa untuk aksi seperti "Salin tautan".
  final Widget child;
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
                child: Padding(padding: const EdgeInsets.all(16), child: child),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 10.5, color: c.textMid),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
