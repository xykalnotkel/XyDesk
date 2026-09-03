import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../webrtc/rtc_service.dart';
import '../../webrtc/session_transport.dart';
import 'media_capabilities.dart';

enum SessionExperience { gaming, desktop }

enum SessionPanelSection { stream, audio, controls, session }

enum AudioLatencyMode { lowLatency, balanced, quality }

enum MicrophoneMode { alwaysOn, pushToTalk }

/// Sumber papan ketik saat sesi.
enum KeyboardSource {
  /// Papan ketik XyDesk (tata letak penuh, F1–F12, modifier sticky) —
  /// mengirim keycode Windows ke host. Paling cocok untuk game dan kontrol
  /// penuh.
  xydesk,

  /// Papan ketik sistem (IME Android) lewat field teks — mengetik sebagai
  /// teks bebas, tidak tergantung tata letak keyboard host. Cocok untuk
  /// formulir, kolom pencarian, dan mengetik cepat.
  system,
}

@immutable
class SessionSettings {
  const SessionSettings({
    this.experience = SessionExperience.gaming,
    this.pcAudioRequested = true,
    this.microphoneRequested = false,
    this.remoteVolume = 0.78,
    this.microphoneGain = 0.58,
    this.microphoneSendLevel = 0.86,
    this.noiseSuppression = true,
    this.echoCancellation = true,
    this.autoGainControl = false,
    this.audioLatencyMode = AudioLatencyMode.balanced,
    this.microphoneMode = MicrophoneMode.alwaysOn,
    this.stereoAudio = true,
    this.showGamingControls = true,
    this.haptics = true,
    this.pointerSensitivity = 0.46,
    this.tapToClick = true,
    this.reverseScroll = false,
    this.pointerLock = false,
    this.keyboardSource = KeyboardSource.xydesk,
  });

  final SessionExperience experience;
  final bool pcAudioRequested;
  final bool microphoneRequested;
  final double remoteVolume;
  final double microphoneGain;
  final double microphoneSendLevel;
  final bool noiseSuppression;
  final bool echoCancellation;
  final bool autoGainControl;
  final AudioLatencyMode audioLatencyMode;
  final MicrophoneMode microphoneMode;
  final bool stereoAudio;
  final bool showGamingControls;
  final bool haptics;
  final double pointerSensitivity;
  final bool tapToClick;
  final bool reverseScroll;
  final bool pointerLock;
  final KeyboardSource keyboardSource;

  SessionSettings copyWith({
    SessionExperience? experience,
    bool? pcAudioRequested,
    bool? microphoneRequested,
    double? remoteVolume,
    double? microphoneGain,
    double? microphoneSendLevel,
    bool? noiseSuppression,
    bool? echoCancellation,
    bool? autoGainControl,
    AudioLatencyMode? audioLatencyMode,
    MicrophoneMode? microphoneMode,
    bool? stereoAudio,
    bool? showGamingControls,
    bool? haptics,
    double? pointerSensitivity,
    bool? tapToClick,
    bool? reverseScroll,
    bool? pointerLock,
    KeyboardSource? keyboardSource,
  }) {
    return SessionSettings(
      experience: experience ?? this.experience,
      pcAudioRequested: pcAudioRequested ?? this.pcAudioRequested,
      microphoneRequested: microphoneRequested ?? this.microphoneRequested,
      remoteVolume: remoteVolume ?? this.remoteVolume,
      microphoneGain: microphoneGain ?? this.microphoneGain,
      microphoneSendLevel: microphoneSendLevel ?? this.microphoneSendLevel,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      echoCancellation: echoCancellation ?? this.echoCancellation,
      autoGainControl: autoGainControl ?? this.autoGainControl,
      audioLatencyMode: audioLatencyMode ?? this.audioLatencyMode,
      microphoneMode: microphoneMode ?? this.microphoneMode,
      stereoAudio: stereoAudio ?? this.stereoAudio,
      showGamingControls: showGamingControls ?? this.showGamingControls,
      haptics: haptics ?? this.haptics,
      pointerSensitivity: pointerSensitivity ?? this.pointerSensitivity,
      tapToClick: tapToClick ?? this.tapToClick,
      reverseScroll: reverseScroll ?? this.reverseScroll,
      pointerLock: pointerLock ?? this.pointerLock,
      keyboardSource: keyboardSource ?? this.keyboardSource,
    );
  }
}

class SessionControlPanel extends ConsumerStatefulWidget {
  const SessionControlPanel({
    super.key,
    required this.deviceName,
    required this.state,
    required this.onChanged,
    required this.onClose,
    required this.onDisconnect,
    this.initialSection = SessionPanelSection.stream,
    this.transport = const TransportState(),
    this.rtc,
    this.elapsedSec = 0,
    this.isGuestSession = false,
    this.guestSessionTotal = 0,
  });

  final String deviceName;
  final SessionSettings state;
  final ValueChanged<SessionSettings> onChanged;
  final VoidCallback onClose;
  final VoidCallback onDisconnect;
  final SessionPanelSection initialSection;

  /// Status transport nyata — dipakai panel Stream supaya tidak menampilkan
  /// teks dummy statis saat koneksi gagal/offline.
  final TransportState transport;

  /// Sesi WebRTC yang sedang jalan. Dari sini panel membaca statistik nyata
  /// (resolusi, fps, bitrate, ping) dan daftar layar host. Null berarti belum
  /// ada sesi, dan panel menampilkan tanda strip — bukan angka contoh.
  final RtcService? rtc;

  /// Detik elapsed sejak sesi tersambung. Ditampilkan di tab Sesi.
  final int elapsedSec;

  /// Apakah ini sesi tamu (tanpa login). Tamu punya batas waktu 2 jam.
  final bool isGuestSession;

  /// Total durasi sesi untuk tamu (dalam detik). Biasanya 7200 (2 jam).
  final int guestSessionTotal;

  @override
  ConsumerState<SessionControlPanel> createState() =>
      _SessionControlPanelState();
}

class _SessionControlPanelState extends ConsumerState<SessionControlPanel> {
  late SessionPanelSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  void didUpdateWidget(covariant SessionControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      _section = widget.initialSection;
    }
  }

  void _update(SessionSettings next) {
    final previous = widget.state;
    widget.onChanged(next);
    if (next.pcAudioRequested != previous.pcAudioRequested) {
      ref
          .read(settingsProvider.notifier)
          .setAudioEnabled(next.pcAudioRequested);
    }
    if (next.microphoneRequested != previous.microphoneRequested) {
      ref
          .read(settingsProvider.notifier)
          .setMicPassthrough(next.microphoneRequested);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.overlay.withValues(alpha: 0.98),
          border: Border(
            left: BorderSide(color: c.textLow.withValues(alpha: 0.24)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 24,
              offset: const Offset(-8, 0),
            ),
          ],
        ),
        child: SafeArea(
          left: false,
          child: Column(
            children: [
              _PanelHeader(
                deviceName: widget.deviceName,
                transport: widget.transport,
                onClose: widget.onClose,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ExperienceSelector(
                  value: widget.state.experience,
                  onChanged: (value) =>
                      _update(widget.state.copyWith(experience: value)),
                ),
              ),
              _SectionTabs(
                value: _section,
                onChanged: (value) => setState(() => _section = value),
              ),
              const SizedBox(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: switch (_section) {
                    SessionPanelSection.stream => _StreamPanel(
                      transport: widget.transport,
                      rtc: widget.rtc,
                    ),
                    SessionPanelSection.audio => _AudioPanel(
                      state: widget.state,
                      onChanged: _update,
                    ),
                    SessionPanelSection.controls => _ControlsPanel(
                      state: widget.state,
                      onChanged: _update,
                    ),
                    SessionPanelSection.session => _SessionPanel(
                      deviceName: widget.deviceName,
                      transport: widget.transport,
                      rtc: widget.rtc,
                      elapsedSec: widget.elapsedSec,
                      isGuestSession: widget.isGuestSession,
                      guestSessionTotal: widget.guestSessionTotal,
                      onDisconnect: widget.onDisconnect,
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.deviceName,
    required this.transport,
    required this.onClose,
  });

  final String deviceName;
  final TransportState transport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final live = transport.live;
    final (dot, status) = switch (transport.status) {
      TransportStatus.connected => (c.successText, 'Tersambung'),
      TransportStatus.pairing => (c.warningText, 'Menghubungi PC'),
      TransportStatus.negotiating => (c.warningText, 'Menyiapkan koneksi'),
      TransportStatus.hostBusy => (c.warningText, 'PC sedang dipakai'),
      TransportStatus.peerOffline => (c.dangerText, 'PC tidak online'),
      TransportStatus.rejected => (c.dangerText, 'Pairing ditolak'),
      TransportStatus.error => (c.dangerText, 'Koneksi gagal'),
      TransportStatus.ended => (c.textLow, 'Sesi selesai'),
      TransportStatus.preview => (c.textLow, 'Belum tersambung'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: live ? c.accentSoft : c.raised,
              borderRadius: BorderRadius.circular(R.sm),
            ),
            child: Icon(
              LucideIcons.monitor,
              size: 19,
              color: live ? c.accent : c.textMid,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textHi,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: c.textLow),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tutup',
            onPressed: onClose,
            icon: Icon(LucideIcons.x, size: 20, color: c.textMid),
          ),
        ],
      ),
    );
  }
}

class ExperienceSelector extends StatelessWidget {
  const ExperienceSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final SessionExperience value;
  final ValueChanged<SessionExperience> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _Segmented<SessionExperience>(
      value: value,
      height: compact ? 38 : 44,
      entries: const [
        _SegmentEntry(
          value: SessionExperience.gaming,
          label: 'Gaming',
          icon: LucideIcons.gamepad2,
        ),
        _SegmentEntry(
          value: SessionExperience.desktop,
          label: 'Desktop',
          icon: LucideIcons.mouse,
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.value, required this.onChanged});

  final SessionPanelSection value;
  final ValueChanged<SessionPanelSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const tabs = [
      (SessionPanelSection.stream, 'Gambar', LucideIcons.monitor),
      (SessionPanelSection.audio, 'Suara', LucideIcons.volume2),
      (SessionPanelSection.controls, 'Kontrol', LucideIcons.gamepad2),
      (SessionPanelSection.session, 'Sesi', LucideIcons.info),
    ];
    // Empat tab dengan lebar sama: tidak perlu digeser-geser, dan posisinya
    // tidak berpindah saat label berubah panjang.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.raised,
          borderRadius: BorderRadius.circular(R.md),
        ),
        child: Row(
          children: [
            for (final tab in tabs)
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(tab.$1),
                  borderRadius: BorderRadius.circular(R.sm),
                  child: AnimatedContainer(
                    duration: D.fast,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == tab.$1
                          ? c.accentSoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(R.sm),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.$3,
                          size: 16,
                          color: value == tab.$1 ? c.accent : c.textMid,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.$2,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: value == tab.$1
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: value == tab.$1 ? c.accent : c.textMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StreamPanel extends ConsumerWidget {
  const _StreamPanel({this.transport = const TransportState(), this.rtc});

  final TransportState transport;
  final RtcService? rtc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final service = rtc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Yang sedang berjalan',
          subtitle: 'Angka di bawah dibaca langsung dari koneksi.',
        ),
        if (service == null)
          const _PanelCard(
            child: Text(
              'Belum ada sesi. Angka kualitas muncul begitu PC tersambung.',
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
          )
        else
          StreamBuilder<SessionStats>(
            initialData: service.stats,
            stream: service.statsStream,
            builder: (context, snapshot) {
              final st = snapshot.data ?? const SessionStats();
              return _PanelCard(
                child: Column(
                  children: [
                    _InfoRow(
                      icon: LucideIcons.monitor,
                      title: 'Ukuran gambar',
                      value: st.resolutionLabel,
                    ),
                    const _CardGap(),
                    _InfoRow(
                      icon: LucideIcons.activity,
                      title: 'Kehalusan',
                      value: st.fpsLabel,
                    ),
                    const _CardGap(),
                    _InfoRow(
                      icon: LucideIcons.gauge,
                      title: 'Pemakaian data',
                      value: st.bitrateLabel,
                    ),
                    const _CardGap(),
                    _InfoRow(
                      icon: LucideIcons.wifi,
                      title: 'Ping',
                      value: st.rttLabel,
                    ),
                    const _CardGap(),
                    _InfoRow(
                      icon: LucideIcons.triangleAlert,
                      title: 'Paket hilang',
                      value: st.lossLabel,
                    ),
                    const _CardGap(),
                    _InfoRow(
                      icon: LucideIcons.cpu,
                      title: 'Codec',
                      value: st.codec ?? '-',
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        if (service != null) _DisplayPicker(rtc: service),
        const _SectionTitle(
          title: 'Batas yang kamu pilih',
          subtitle: 'Dipakai saat sesi berikutnya dimulai.',
        ),
        _PanelCard(
          child: Column(
            children: [
              _InfoRow(
                icon: LucideIcons.maximize,
                title: 'Resolusi diminta',
                value: settings.resolution.split(' ')[0],
              ),
              const _CardGap(),
              _InfoRow(
                icon: LucideIcons.fileVideo,
                title: 'Codec diminta',
                value: settings.codec.split(' ')[0],
              ),
              const _CardGap(),
              _SliderRow(
                label: 'Batas pemakaian data',
                valueLabel: '${settings.bitrateMbps} Mbps',
                value: (settings.bitrateMbps - 5) / 45,
                onChanged: (value) => ref
                    .read(settingsProvider.notifier)
                    .setBitrateMbps((5 + value * 45).round()),
              ),
            ],
          ),
        ),
        if (!transport.live) ...[
          const SizedBox(height: 16),
          _StatusCard(
            icon: transport.status == TransportStatus.error
                ? LucideIcons.wifiOff
                : LucideIcons.info,
            title: switch (transport.status) {
              TransportStatus.pairing => 'Sedang menghubungi PC',
              TransportStatus.negotiating => 'Sedang menyiapkan koneksi',
              TransportStatus.rejected => 'PC menolak sambungan',
              TransportStatus.peerOffline => 'PC tidak online',
              TransportStatus.hostBusy => 'PC sedang dipakai sesi lain',
              TransportStatus.ended => 'Sesi sudah ditutup',
              TransportStatus.error => 'Koneksi gagal',
              TransportStatus.connected => 'Tersambung',
              TransportStatus.preview => 'Belum tersambung',
            },
            body:
                transport.message ??
                'Belum ada sesi berjalan. Mulai dari daftar perangkat.',
          ),
        ],
      ],
    );
  }
}

/// Pemilih layar host. Dulu chip ini melayang di bawah layar sesi dan menutupi
/// gambar; sekarang tinggal di panel bersama pengaturan gambar lainnya.
class _DisplayPicker extends StatelessWidget {
  const _DisplayPicker({required this.rtc});

  final RtcService rtc;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return StreamBuilder<HostMeta>(
      initialData: rtc.hostMeta,
      stream: rtc.hostMetaStream,
      builder: (context, snapshot) {
        final displays = snapshot.data?.displays ?? const <HostDisplay>[];
        if (displays.length < 2) return const SizedBox.shrink();
        final wanted = snapshot.data?.wantedDisplay ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              title: 'Layar PC',
              subtitle: 'PC ini punya lebih dari satu monitor.',
            ),
            _PanelCard(
              child: Column(
                children: [
                  for (final d in displays) ...[
                    if (d != displays.first) const _CardGap(),
                    InkWell(
                      onTap: () => rtc.selectDisplay(d.index),
                      borderRadius: BorderRadius.circular(R.sm),
                      child: Row(
                        children: [
                          Icon(
                            d.index == wanted
                                ? LucideIcons.circleCheck
                                : LucideIcons.circle,
                            size: 17,
                            color: d.index == wanted ? c.accent : c.textLow,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              d.name.isEmpty ? 'Layar ${d.index + 1}' : d.name,
                              style: TextStyle(fontSize: 13, color: c.textHi),
                            ),
                          ),
                          Text(
                            '${d.width} x ${d.height}',
                            style: TextStyle(fontSize: 11.5, color: c.textLow),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _AudioPanel extends StatelessWidget {
  const _AudioPanel({required this.state, required this.onChanged});

  final SessionSettings state;
  final ValueChanged<SessionSettings> onChanged;

  static const _capabilities = SessionMediaCapabilities.currentBuild;

  void _showDeviceStatus(
    BuildContext context, {
    required String title,
    required String current,
    required String requirement,
  }) {
    final c = context.c;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              current,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textHi,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Jalur audio aktif sejak rilis 6.1. $requirement',
              style: TextStyle(fontSize: 12, height: 1.5, color: c.textMid),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CapabilityCard(capabilities: _capabilities),
        const SizedBox(height: 18),
        const _SectionTitle(
          title: 'Suara PC ke perangkat',
          subtitle: 'Preferensi output untuk audio sistem Windows.',
        ),
        _PanelCard(
          child: Column(
            children: [
              _ToggleRow(
                icon: LucideIcons.volume2,
                title: 'Minta audio PC',
                subtitle: state.pcAudioRequested
                    ? 'Aktif — audio PC (WASAPI loopback) diputar di '
                          'perangkat ini'
                    : 'Tidak diminta',
                value: state.pcAudioRequested,
                onChanged: (value) =>
                    onChanged(state.copyWith(pcAudioRequested: value)),
              ),
              const _CardGap(),
              _DeviceRow(
                icon: LucideIcons.monitor,
                title: 'Sumber host',
                value: 'Output default Windows',
                onTap: () => _showDeviceStatus(
                  context,
                  title: 'Pilih sumber audio PC',
                  current: 'Output default Windows',
                  requirement:
                      'WASAPI loopback dan daftar render endpoint host',
                ),
              ),
              const _CardGap(),
              _DeviceRow(
                icon: LucideIcons.volume2,
                title: 'Output perangkat',
                value: 'Otomatis',
                onTap: () => _showDeviceStatus(
                  context,
                  title: 'Pilih output perangkat',
                  current: 'Otomatis',
                  requirement: 'Track audio remote yang aktif',
                ),
              ),
              const _CardGap(),
              _SliderRow(
                label: 'Volume remote',
                valueLabel: '${(state.remoteVolume * 100).round()}%',
                value: state.remoteVolume,
                onChanged: (value) =>
                    onChanged(state.copyWith(remoteVolume: value)),
              ),
              const _CardGap(),
              _ToggleRow(
                icon: LucideIcons.activity,
                title: 'Audio stereo',
                subtitle: 'Mono menghemat bandwidth',
                value: state.stereoAudio,
                onChanged: (value) =>
                    onChanged(state.copyWith(stereoAudio: value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'MODE LATENSI',
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.7,
            fontWeight: FontWeight.w600,
            color: context.c.textLow,
          ),
        ),
        const SizedBox(height: 8),
        _Segmented<AudioLatencyMode>(
          value: state.audioLatencyMode,
          entries: const [
            _SegmentEntry(value: AudioLatencyMode.lowLatency, label: 'Gaming'),
            _SegmentEntry(value: AudioLatencyMode.balanced, label: 'Seimbang'),
            _SegmentEntry(value: AudioLatencyMode.quality, label: 'Kualitas'),
          ],
          onChanged: (value) =>
              onChanged(state.copyWith(audioLatencyMode: value)),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Mikrofon HP ke Windows',
          subtitle: 'Target akhir: endpoint XyDesk Virtual Microphone.',
        ),
        _PanelCard(
          child: Column(
            children: [
              _ToggleRow(
                icon: LucideIcons.mic,
                title: 'Minta passthrough mikrofon',
                subtitle: state.microphoneRequested
                    ? 'Aktif — mic dikirim dan diputar di speaker PC host'
                    : 'Mikrofon tidak diminta',
                value: state.microphoneRequested,
                onChanged: (value) =>
                    onChanged(state.copyWith(microphoneRequested: value)),
              ),
              const _CardGap(),
              _DeviceRow(
                icon: LucideIcons.smartphone,
                title: 'Input',
                value: 'Mikrofon default HP',
                onTap: () => _showDeviceStatus(
                  context,
                  title: 'Pilih input mikrofon',
                  current: 'Mikrofon default HP',
                  requirement: 'Izin mikrofon dan enumerasi input perangkat',
                ),
              ),
              const _CardGap(),
              _DeviceRow(
                icon: LucideIcons.monitor,
                title: 'Output Windows',
                value: 'XyDesk Virtual Mic',
                onTap: () => _showDeviceStatus(
                  context,
                  title: 'Target Windows',
                  current: 'XyDesk Virtual Microphone',
                  requirement: 'Komponen virtual microphone terpasang di host',
                ),
              ),
              const _CardGap(),
              const _InactiveLevelMeter(),
              const _CardGap(),
              _SliderRow(
                label: 'Gain input',
                valueLabel: '${((state.microphoneGain - 0.5) * 24).round()} dB',
                value: state.microphoneGain,
                onChanged: (value) =>
                    onChanged(state.copyWith(microphoneGain: value)),
              ),
              const _CardGap(),
              _SliderRow(
                label: 'Level kirim',
                valueLabel: '${(state.microphoneSendLevel * 100).round()}%',
                value: state.microphoneSendLevel,
                onChanged: (value) =>
                    onChanged(state.copyWith(microphoneSendLevel: value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _SectionTitle(
          title: 'Pemrosesan suara',
          subtitle: 'Diterapkan pada capture sebelum Opus ketika engine siap.',
        ),
        _PanelCard(
          child: Column(
            children: [
              _ToggleRow(
                icon: LucideIcons.activity,
                title: 'Peredam bising',
                subtitle: 'Noise suppression',
                value: state.noiseSuppression,
                onChanged: (value) =>
                    onChanged(state.copyWith(noiseSuppression: value)),
              ),
              const _CardGap(),
              _ToggleRow(
                icon: LucideIcons.volume2,
                title: 'Peredam gema',
                subtitle: 'AEC untuk suara speaker perangkat',
                value: state.echoCancellation,
                onChanged: (value) =>
                    onChanged(state.copyWith(echoCancellation: value)),
              ),
              const _CardGap(),
              _ToggleRow(
                icon: LucideIcons.gauge,
                title: 'Gain otomatis',
                subtitle: 'AGC menstabilkan volume suara',
                value: state.autoGainControl,
                onChanged: (value) =>
                    onChanged(state.copyWith(autoGainControl: value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Segmented<MicrophoneMode>(
          value: state.microphoneMode,
          entries: const [
            _SegmentEntry(
              value: MicrophoneMode.alwaysOn,
              label: 'Selalu aktif',
              icon: LucideIcons.mic,
            ),
            _SegmentEntry(
              value: MicrophoneMode.pushToTalk,
              label: 'Push to talk',
              icon: LucideIcons.gamepad2,
            ),
          ],
          onChanged: (value) =>
              onChanged(state.copyWith(microphoneMode: value)),
        ),
        const SizedBox(height: 14),
        const _PreferenceNotice(),
      ],
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({required this.state, required this.onChanged});

  final SessionSettings state;
  final ValueChanged<SessionSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final gaming = state.experience == SessionExperience.gaming;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: gaming ? 'Kontrol gaming' : 'Kontrol desktop',
          subtitle: gaming
              ? 'HUD sentuh yang ringkas untuk permainan.'
              : 'Pointer, klik, keyboard, dan clipboard lebih diprioritaskan.',
        ),
        _PanelCard(
          child: Column(
            children: [
              if (gaming) ...[
                _ToggleRow(
                  icon: LucideIcons.gamepad2,
                  title: 'Tampilkan kontrol sentuh',
                  subtitle: 'D-pad, stik, dan tombol aksi',
                  value: state.showGamingControls,
                  onChanged: (value) =>
                      onChanged(state.copyWith(showGamingControls: value)),
                ),
                const _CardGap(),
              ],
              _Segmented<KeyboardSource>(
                value: state.keyboardSource,
                onChanged: (value) =>
                    onChanged(state.copyWith(keyboardSource: value)),
                entries: const [
                  _SegmentEntry<KeyboardSource>(
                    value: KeyboardSource.xydesk,
                    label: 'XyDesk',
                    icon: LucideIcons.keyboard,
                  ),
                  _SegmentEntry<KeyboardSource>(
                    value: KeyboardSource.system,
                    label: 'Sistem',
                    icon: LucideIcons.smartphone,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 10),
                child: Text(
                  state.keyboardSource == KeyboardSource.system
                      ? 'Mengetik memakai papan ketik HP (IME); cocok untuk '
                            'formulir dan mengetik teks.'
                      : 'Papan ketik penuh XyDesk (F1–F12, modifier); cocok '
                            'untuk game dan kontrol tepat.',
                  style: TextStyle(fontSize: 10.5, color: c.textLow),
                ),
              ),
              const _CardGap(),
              _ToggleRow(
                icon: LucideIcons.vibrate,
                title: 'Umpan balik haptik',
                value: state.haptics,
                onChanged: (value) => onChanged(state.copyWith(haptics: value)),
              ),
              const _CardGap(),
              _SliderRow(
                label: gaming ? 'Sensitivitas bidik' : 'Kecepatan pointer',
                valueLabel:
                    '${(0.5 + state.pointerSensitivity * 2.5).toStringAsFixed(1)}×',
                value: state.pointerSensitivity,
                onChanged: (value) =>
                    onChanged(state.copyWith(pointerSensitivity: value)),
              ),
              if (!gaming) ...[
                const _CardGap(),
                _ToggleRow(
                  icon: LucideIcons.mouse,
                  title: 'Ketuk untuk klik',
                  value: state.tapToClick,
                  onChanged: (value) =>
                      onChanged(state.copyWith(tapToClick: value)),
                ),
                const _CardGap(),
                _ToggleRow(
                  icon: LucideIcons.activity,
                  title: 'Balik arah gulir',
                  value: state.reverseScroll,
                  onChanged: (value) =>
                      onChanged(state.copyWith(reverseScroll: value)),
                ),
                const _CardGap(),
                _ToggleRow(
                  icon: LucideIcons.crosshair,
                  title: 'Pointer relatif',
                  subtitle: 'Untuk aplikasi 3D dan FPS',
                  value: state.pointerLock,
                  onChanged: (value) =>
                      onChanged(state.copyWith(pointerLock: value)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _StatusCard(
          icon: LucideIcons.info,
          title: 'Input transport belum tersambung',
          body:
              'Kontrol di layar dapat dipreview, tetapi belum mengirim input '
              'ke host sampai transport tersambung.',
        ),
      ],
    );
  }
}

class _SessionPanel extends StatelessWidget {
  const _SessionPanel({
    required this.deviceName,
    required this.transport,
    required this.onDisconnect,
    this.rtc,
    this.elapsedSec = 0,
    this.isGuestSession = false,
    this.guestSessionTotal = 0,
  });

  final String deviceName;
  final TransportState transport;
  final RtcService? rtc;
  final int elapsedSec;
  final bool isGuestSession;
  final int guestSessionTotal;
  final VoidCallback onDisconnect;

  static String _fmtDurasi(int totalSec) {
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '${h}j ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}d';
    }
    return '${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}d';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final service = rtc;

    // Hitung sisa waktu untuk sesi tamu
    final remaining = isGuestSession
        ? (guestSessionTotal - elapsedSec).clamp(0, guestSessionTotal)
        : 0;
    final isCritical = isGuestSession && remaining <= 300 && remaining > 0;
    final isExpired = isGuestSession && remaining <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Countdown card untuk sesi tamu
        if (isGuestSession) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isExpired
                  ? c.danger.withValues(alpha: 0.12)
                  : isCritical
                      ? c.warning.withValues(alpha: 0.12)
                      : c.raised,
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(
                color: isExpired
                    ? c.danger.withValues(alpha: 0.5)
                    : isCritical
                        ? c.warning.withValues(alpha: 0.5)
                        : c.textLow.withValues(alpha: 0.16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isExpired
                          ? LucideIcons.circleX
                          : isCritical
                              ? LucideIcons.timer
                              : LucideIcons.clock,
                      size: 18,
                      color: isExpired
                          ? c.danger
                          : isCritical
                              ? c.warning
                              : c.textMid,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isExpired
                          ? 'Sesi tamu berakhir'
                          : isCritical
                              ? 'Sesaat lagi berakhir!'
                              : 'Sesi tamu',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isExpired
                            ? c.danger
                            : isCritical
                                ? c.warning
                                : c.textHi,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 10,
                              color: c.textLow,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fmtDurasi(guestSessionTotal),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.textHi,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: c.textLow.withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SISA',
                            style: TextStyle(
                              fontSize: 10,
                              color: isExpired
                                  ? c.danger
                                  : isCritical
                                      ? c.warning
                                      : c.textLow,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isExpired ? '00m 00d' : _fmtDurasi(remaining),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isExpired
                                  ? c.danger
                                  : isCritical
                                      ? c.warning
                                      : c.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isExpired) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Sesi tamu telah berakhir. Silakan login untuk '\
                    'melanjutkan.',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.danger,
                      height: 1.4,
                    ),
                  ),
                ] else if (isCritical) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Sesi akan berakhir dalam kurang dari 5 menit. '\
                    'Segera simpan pekerjaanmu.',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.warning,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const _SectionTitle(title: 'Sesi ini'),
        StreamBuilder<SessionStats>(
          initialData: service?.stats,
          stream: service?.statsStream,
          builder: (context, snapshot) {
            final st = snapshot.data;
            return _PanelCard(
              child: Column(
                children: [
                  _InfoRow(
                    icon: LucideIcons.monitor,
                    title: 'Perangkat',
                    value: deviceName,
                  ),
                  const _CardGap(),
                  _InfoRow(
                    icon: LucideIcons.clock,
                    title: 'Durasi',
                    value: transport.live
                        ? _fmtDurasi(elapsedSec)
                        : '—',
                  ),
                  const _CardGap(),
                  _InfoRow(
                    icon: LucideIcons.wifi,
                    title: 'Sambungan',
                    value: switch (transport.status) {
                      TransportStatus.connected => 'Langsung ke PC',
                      TransportStatus.pairing => 'Menghubungi PC',
                      TransportStatus.negotiating => 'Menyiapkan koneksi',
                      TransportStatus.hostBusy => 'PC dipakai sesi lain',
                      TransportStatus.peerOffline => 'PC tidak online',
                      TransportStatus.rejected => 'Ditolak PC',
                      TransportStatus.error => 'Gagal',
                      TransportStatus.ended => 'Sudah ditutup',
                      TransportStatus.preview => 'Belum tersambung',
                    },
                  ),
                  const _CardGap(),
                  _InfoRow(
                    icon: LucideIcons.video,
                    title: 'Gambar',
                    value: st?.hasVideo == true
                        ? '${st!.resolutionLabel} - ${st.fpsLabel}'
                        : 'Belum ada gambar',
                  ),
                  const _CardGap(),
                  _InfoRow(
                    icon: LucideIcons.volume2,
                    title: 'Suara dari PC',
                    value: st?.audioLabel ?? 'Tidak ada suara masuk',
                  ),
                  const _CardGap(),
                  _InfoRow(
                    icon: LucideIcons.mic,
                    title: 'Mik ke PC',
                    value: service?.micEnabled == true ? 'Aktif' : 'Mati',
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onDisconnect,
            icon: const Icon(LucideIcons.power, size: 18),
            label: const Text('Putuskan sesi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.c.danger,
              side: BorderSide(color: context.c.danger.withValues(alpha: 0.55)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(R.md),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capabilities});

  final SessionMediaCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: c.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.activity, size: 19, color: c.warning),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Engine audio belum terhubung',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textHi,
                        ),
                      ),
                    ),
                    if (capabilities.freeDuringBeta)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(R.sm),
                        ),
                        child: Text(
                          'GRATIS BETA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: c.success,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Kontrol di bawah menyiapkan preferensi sesi; pilihan audio dan '
                  'mikrofon utama disimpan. Tidak ada audio yang dikirim atau '
                  'diputar pada build ini.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: c.textMid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceNotice extends StatelessWidget {
  const _PreferenceNotice();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Text(
      'Tidak ada paywall selama beta. Nantinya, aktivasi dapat mengikuti '
      'capability negotiation setelah host, track Opus, dan virtual microphone '
      'tersedia.',
      style: TextStyle(fontSize: 11, height: 1.5, color: c.textLow),
    );
  }
}

class _InactiveLevelMeter extends StatelessWidget {
  const _InactiveLevelMeter();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Level mikrofon',
                  style: TextStyle(fontSize: 12.5, color: c.textMid),
                ),
              ),
              Text(
                'Tidak aktif',
                style: TextStyle(fontSize: 11, color: c.textLow),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              for (var index = 0; index < 14; index++) ...[
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.textLow.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index != 13) const SizedBox(width: 3),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: c.textHi,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 11, height: 1.4, color: c.textLow),
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: c.input.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: c.textLow.withValues(alpha: 0.16)),
      ),
      child: child,
    );
  }
}

class _CardGap extends StatelessWidget {
  const _CardGap();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 1);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Icon(icon, size: 17, color: c.textLow),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 12.5, color: c.textMid),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: c.textHi,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Icon(icon, size: 17, color: c.textLow),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 12.5, color: c.textMid),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: c.textHi,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 15, color: c.textLow),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Row(
        children: [
          Icon(icon, size: 17, color: value ? c.accent : c.textLow),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12.5, color: c.textHi),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: c.textLow,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Transform.scale(
            scale: 0.78,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: c.textMid),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: c.textHi,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 30,
            child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.textLow),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.textHi,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: c.textLow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentEntry<T> {
  const _SegmentEntry({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.entries,
    required this.onChanged,
    this.height = 42,
  });

  final T value;
  final List<_SegmentEntry<T>> entries;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: c.textLow.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          for (final entry in entries)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(entry.value),
                borderRadius: BorderRadius.circular(R.sm),
                child: AnimatedContainer(
                  duration: D.fast,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == entry.value ? c.raised : Colors.transparent,
                    borderRadius: BorderRadius.circular(R.sm),
                    boxShadow: value == entry.value
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 5,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (entry.icon != null) ...[
                        Icon(
                          entry.icon,
                          size: 15,
                          color: value == entry.value ? c.accent : c.textLow,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: value == entry.value
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: value == entry.value ? c.textHi : c.textMid,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
