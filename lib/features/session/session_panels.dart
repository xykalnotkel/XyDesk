import 'package:flutter/material.dart';
import '../../core/l10n_bridge.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/tokens.dart';

/// Kategori pengaturan sesi. Tiap kategori punya panel sendiri, jadi isinya
/// tetap pendek — tidak perlu menggulir daftar panjang saat sedang main.
enum PanelCat {
  info('Info', LucideIcons.gauge),
  video('Video', LucideIcons.video),
  audio('Audio', LucideIcons.volume2),
  mic('Mik', LucideIcons.mic),
  control('Kontrol', LucideIcons.gamepad2),
  pointer('Pointer', LucideIcons.mouse),
  network('Jaringan', LucideIcons.wifi),
  other('Lain', LucideIcons.settings);

  const PanelCat(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Bilah ikon kiri — navigasi cepat + aksi sesi.
///
/// Restart / Kembali / Putus ditaruh di sini agar selalu terjangkau ibu jari
/// kiri saat memegang HP dalam mode landscape.
class LeftRail extends StatelessWidget {
  const LeftRail({
    super.key,
    required this.active,
    required this.onSelect,
    this.onRestart,
    this.onBack,
    this.onDisconnect,
    this.onClose,
  });

  /// Menyembunyikan bilah kiri.
  final VoidCallback? onClose;

  final PanelCat active;
  final ValueChanged<PanelCat> onSelect;
  final VoidCallback? onRestart;
  final VoidCallback? onBack;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 48,
      color: c.overlay.withValues(alpha: 0.96),
      child: SafeArea(
        right: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 4),
              if (onClose != null)
                _RailItem(
                  icon: LucideIcons.chevronLeft,
                  label: 'Tutup',
                  onTap: onClose,
                ),
              const SizedBox(height: 2),
              for (final cat in PanelCat.values)
                _RailItem(
                  icon: cat.icon,
                  label: cat.label,
                  active: cat == active,
                  onTap: () => onSelect(cat),
                ),
              Container(
                width: 22,
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: c.textLow.withValues(alpha: 0.22),
              ),
              _RailItem(
                icon: LucideIcons.refreshCw,
                label: 'Restart',
                onTap: onRestart,
              ),
              _RailItem(
                icon: LucideIcons.arrowLeft,
                label: 'Kembali',
                onTap: onBack,
              ),
              _RailItem(
                icon: LucideIcons.power,
                label: context.tr('session_disconnect_action'),
                danger: true,
                onTap: onDisconnect,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = danger ? c.danger : (active ? c.textHi : c.textLow);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active ? c.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 38,
            height: 33,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: col),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(fontSize: 6.5, color: col, height: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Panel kanan — isi berganti sesuai kategori terpilih.
class RightPanel extends StatelessWidget {
  const RightPanel({
    super.key,
    required this.cat,
    required this.deviceName,
    required this.onBackToHub,
    required this.state,
    required this.onChanged,
    this.onClose,
    this.onSelectCat,
  });

  final PanelCat cat;
  final String deviceName;
  final VoidCallback onBackToHub;
  final SessionSettings state;
  final ValueChanged<SessionSettings> onChanged;

  /// Menutup panel sepenuhnya. Tanpa ini panel hanya bisa ditutup lewat
  /// panah di pojok, yang mudah terlewat.
  final VoidCallback? onClose;

  /// Berpindah kategori dari tile di layar Info.
  final ValueChanged<PanelCat>? onSelectCat;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 252,
      color: c.overlay.withValues(alpha: 0.96),
      child: SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cat != PanelCat.info)
                InkWell(
                  onTap: onBackToHub,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.chevronLeft,
                          size: 13,
                          color: c.textMid,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Kembali ke kategori',
                          style: TextStyle(fontSize: 10, color: c.textMid),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textHi,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _badge(),
                    style: TextStyle(fontSize: 9.5, color: c.textLow),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: SingleChildScrollView(child: _content(context))),
            ],
          ),
        ),
      ),
    );
  }

  String _badge() => switch (cat) {
        PanelCat.info => deviceName,
        PanelCat.video => 'H.264',
        PanelCat.audio => 'Stereo',
        PanelCat.mic => state.micOn ? 'Aktif' : 'Mati',
        PanelCat.control => 'Gaming',
        PanelCat.pointer => 'Touchpad',
        PanelCat.network => 'P2P',
        PanelCat.other => 'Demo',
      };

  Widget _content(BuildContext context) => switch (cat) {
        PanelCat.info => _InfoPanel(
            name: deviceName,
            onSelect: onSelectCat ?? (_) {},
          ),
        PanelCat.video => _VideoPanel(state: state, onChanged: onChanged),
        PanelCat.audio => const _AudioPanel(),
        PanelCat.mic => _MicPanel(state: state, onChanged: onChanged),
        PanelCat.control => const _ControlPanel(),
        PanelCat.pointer => _PointerPanel(state: state, onChanged: onChanged),
        PanelCat.network => const _NetworkPanel(),
        PanelCat.other => const _OtherPanel(),
      };
}

/// Nilai pengaturan sesi yang bisa diubah live tanpa reconnect.
class SessionSettings {
  const SessionSettings({
    this.bitrate = 12,
    this.fps = 60,
    this.micOn = true,
    this.noiseSuppression = true,
    this.aec = true,
    this.agc = false,
    this.micGain = 0.62,
    this.micVolume = 0.8,
    this.sensitivity = 1.4,
    this.invertScroll = true,
    this.tapToClick = true,
    this.pointerLock = false,
  });

  final double bitrate;
  final int fps;
  final bool micOn, noiseSuppression, aec, agc;
  final double micGain, micVolume, sensitivity;
  final bool invertScroll, tapToClick, pointerLock;

  SessionSettings copyWith({
    double? bitrate,
    int? fps,
    bool? micOn,
    bool? noiseSuppression,
    bool? aec,
    bool? agc,
    double? micGain,
    double? micVolume,
    double? sensitivity,
    bool? invertScroll,
    bool? tapToClick,
    bool? pointerLock,
  }) =>
      SessionSettings(
        bitrate: bitrate ?? this.bitrate,
        fps: fps ?? this.fps,
        micOn: micOn ?? this.micOn,
        noiseSuppression: noiseSuppression ?? this.noiseSuppression,
        aec: aec ?? this.aec,
        agc: agc ?? this.agc,
        micGain: micGain ?? this.micGain,
        micVolume: micVolume ?? this.micVolume,
        sensitivity: sensitivity ?? this.sensitivity,
        invertScroll: invertScroll ?? this.invertScroll,
        tapToClick: tapToClick ?? this.tapToClick,
        pointerLock: pointerLock ?? this.pointerLock,
      );
}

// ── Bagian isi panel ──────────────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.name, required this.onSelect});

  final String name;
  final ValueChanged<PanelCat> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelRow('Perangkat', name),
        const PanelRow('Waktu', '24 mnt'),
        const PanelRow('Jalur', 'P2P langsung'),
        const PanelRow('Ping', '24 ms'),
        const PanelRow('Kualitas', '1080p · 60'),
        const PanelSub('Kategori'),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final cat in [
              PanelCat.video,
              PanelCat.audio,
              PanelCat.mic,
              PanelCat.control,
              PanelCat.pointer,
              PanelCat.network,
              PanelCat.other,
            ])
              _CatTile(cat: cat, onTap: () => onSelect(cat)),
          ],
        ),
      ],
    );
  }
}

class _CatTile extends StatelessWidget {
  const _CatTile({required this.cat, this.onTap});
  final PanelCat cat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.input.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 108,
          padding: const EdgeInsets.fromLTRB(7, 8, 7, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(cat.icon, size: 15, color: c.textMid),
              const SizedBox(height: 4),
              Text(
                cat.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: c.textHi,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPanel extends StatelessWidget {
  const _VideoPanel({required this.state, required this.onChanged});
  final SessionSettings state;
  final ValueChanged<SessionSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelSub('Preset'),
        const PanelSegmented(
          items: ['Auto', 'Ultra', 'Seimbang', 'HD'],
          index: 1,
        ),
        PanelSlider(
          label: 'Bitrate',
          value: '${state.bitrate.round()} Mbps',
          fraction: state.bitrate / 50,
          onChanged: (v) => onChanged(state.copyWith(bitrate: v * 50)),
        ),
        const PanelSub('FPS'),
        const PanelSegmented(items: ['30', '60', '120'], index: 1),
        const PanelSub('Resolusi'),
        const PanelSegmented(items: ['Native', '1080', '720', '480'], index: 1),
        const PanelRow('Codec', 'H.264 ›'),
        PanelToggle(
          label: context.tr('session_hw_decode'),
          value: true,
          onChanged: (_) {},
        ),
        PanelToggle(
          label: context.tr('session_limit_60hz'),
          value: true,
          onChanged: (_) {},
        ),
      ],
    );
  }
}

class _MicPanel extends StatelessWidget {
  const _MicPanel({required this.state, required this.onChanged});
  final SessionSettings state;
  final ValueChanged<SessionSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelToggle(
          label: 'Kirim mik ke PC',
          value: state.micOn,
          onChanged: (v) => onChanged(state.copyWith(micOn: v)),
        ),
        const PanelRow('Perangkat', 'Mik HP ›'),
        const PanelSub('Level masuk'),
        const VuMeter(level: 7),
        PanelSlider(
          label: 'Gain',
          value: '+6 dB',
          fraction: state.micGain,
          onChanged: (v) => onChanged(state.copyWith(micGain: v)),
        ),
        PanelSlider(
          label: 'Volume kirim',
          value: '${(state.micVolume * 100).round()} %',
          fraction: state.micVolume,
          onChanged: (v) => onChanged(state.copyWith(micVolume: v)),
        ),
        const PanelSub('Pemrosesan'),
        PanelToggle(
          label: 'Peredam bising',
          value: state.noiseSuppression,
          onChanged: (v) => onChanged(state.copyWith(noiseSuppression: v)),
        ),
        PanelToggle(
          label: 'Peredam gema (AEC)',
          value: state.aec,
          onChanged: (v) => onChanged(state.copyWith(aec: v)),
        ),
        PanelToggle(
          label: 'Gain otomatis (AGC)',
          value: state.agc,
          onChanged: (v) => onChanged(state.copyWith(agc: v)),
        ),
        const PanelRow('Mode', 'Selalu aktif ›'),
      ],
    );
  }
}

class _PointerPanel extends StatelessWidget {
  const _PointerPanel({required this.state, required this.onChanged});
  final SessionSettings state;
  final ValueChanged<SessionSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelSub('Mode'),
        const PanelSegmented(items: ['Pad', 'Trek', 'Langsung'], index: 0),
        PanelSlider(
          label: 'Sensitivitas',
          value: '${state.sensitivity.toStringAsFixed(1)}×',
          fraction: (state.sensitivity - 0.5) / 2.5,
          onChanged: (v) =>
              onChanged(state.copyWith(sensitivity: 0.5 + v * 2.5)),
        ),
        PanelToggle(
          label: 'Ketuk untuk klik',
          value: state.tapToClick,
          onChanged: (v) => onChanged(state.copyWith(tapToClick: v)),
        ),
        PanelToggle(
          label: 'Balik gulir',
          value: state.invertScroll,
          onChanged: (v) => onChanged(state.copyWith(invertScroll: v)),
        ),
        PanelToggle(
          // Penting untuk game FPS: mouse jadi relatif tak terbatas.
          label: 'Kunci pointer (FPS)',
          value: state.pointerLock,
          onChanged: (v) => onChanged(state.copyWith(pointerLock: v)),
        ),
        const PanelSub('Roda gulir'),
        const PanelSlider(label: 'Kecepatan', value: '3 baris', fraction: 0.4),
        PanelToggle(label: 'Gulir halus', value: true, onChanged: (_) {}),
      ],
    );
  }
}

class _NetworkPanel extends StatelessWidget {
  const _NetworkPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelRow('Jalur', 'P2P (srflx)'),
        const PanelRow('Server', 'Jakarta ›'),
        const PanelRow('Ping', '24 ms'),
        const PanelRow('Jitter', '3,1 ms'),
        const PanelRow('Paket hilang', '0,08 %'),
        const PanelSub('Penyesuaian'),
        PanelToggle(label: 'Bitrate adaptif', value: true, onChanged: (_) {}),
        PanelToggle(
          label: 'FEC saat paket hilang',
          value: true,
          onChanged: (_) {},
        ),
        PanelToggle(
          label: 'Paksa lewat relay',
          value: false,
          onChanged: (_) {},
        ),
        PanelToggle(label: 'Utamakan IPv6', value: true, onChanged: (_) {}),
      ],
    );
  }
}

class _AudioPanel extends StatelessWidget {
  const _AudioPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelRow('Output', 'Speaker HP ›'),
        const PanelSub('Volume'),
        const PanelSlider(label: 'Suara remote', value: '78 %', fraction: 0.78),
        PanelToggle(label: 'Suara sistem', value: true, onChanged: (_) {}),
        PanelToggle(label: 'Audio adaptif', value: true, onChanged: (_) {}),
        PanelToggle(
            label: 'Turunkan saat notifikasi', value: false, onChanged: (_) {}),
        const PanelSub('Mode'),
        const PanelSegmented(items: ['Stereo', 'Mono'], index: 0),
      ],
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelSub('Profil kontrol'),
        const PanelSegmented(
          items: ['Gaming', 'Desktop', 'Custom'],
          index: 0,
        ),
        const PanelRow('Mapping', 'Gaming default ›'),
        PanelToggle(label: 'Tombol virtual', value: true, onChanged: (_) {}),
        PanelToggle(label: 'Getaran saat tap', value: true, onChanged: (_) {}),
        PanelToggle(
            label: 'Tampilkan titik sentuh', value: false, onChanged: (_) {}),
        const PanelSub('Layout'),
        const PanelRow('Keyboard', 'Split ›'),
        const PanelRow('Pointer', 'Touchpad ›'),
      ],
    );
  }
}

class _OtherPanel extends StatelessWidget {
  const _OtherPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelToggle(label: 'Overlay performa', value: true, onChanged: (_) {}),
        PanelToggle(
            label: 'Jaga layar tetap aktif', value: true, onChanged: (_) {}),
        PanelToggle(
            label: 'Kunci orientasi landscape', value: true, onChanged: (_) {}),
        const PanelSub('Tentang sesi'),
        const PanelRow('Mode', 'Demo UI'),
        const PanelRow('Versi aplikasi', '1.0.0+2'),
        const PanelRow('WebRTC', 'Belum tersambung'),
      ],
    );
  }
}

// ── Elemen kecil panel ────────────────────────────────────────────

class PanelRow extends StatelessWidget {
  const PanelRow(this.label, this.value, {super.key});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 10, color: c.textMid),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: c.textHi,
            ),
          ),
        ],
      ),
    );
  }
}

class PanelSub extends StatelessWidget {
  const PanelSub(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 8.5,
          letterSpacing: 0.4,
          color: context.c.textLow,
        ),
      ),
    );
  }
}

class PanelToggle extends StatelessWidget {
  const PanelToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 10, color: c.textMid),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Transform.scale(
            scale: 0.62,
            alignment: Alignment.centerRight,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class PanelSlider extends StatelessWidget {
  const PanelSlider({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.onChanged,
  });

  final String label, value;
  final double fraction;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, color: c.textMid),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: c.textHi,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 20,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: fraction.clamp(0, 1),
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ],
    );
  }
}

class PanelSegmented extends StatelessWidget {
  const PanelSegmented({super.key, required this.items, required this.index});
  final List<String> items;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: i == index
                    ? BoxDecoration(
                        color: c.raised,
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: Text(
                  items[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: i == index ? c.textHi : c.textMid,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// VU meter mikrofon — 12 segmen.
class VuMeter extends StatelessWidget {
  const VuMeter({super.key, required this.level, this.total = 12});

  final int level, total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: i < level
                      ? (i >= total - 2 ? AppColors.warning : AppColors.success)
                      : context.c.textLow.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            if (i != total - 1) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}
