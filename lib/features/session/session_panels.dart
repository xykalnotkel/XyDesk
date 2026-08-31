import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../webrtc/session_transport.dart';
import 'media_capabilities.dart';

enum SessionExperience { gaming, desktop }

enum SessionPanelSection { stream, audio, controls, session }

enum AudioLatencyMode { lowLatency, balanced, quality }

enum MicrophoneMode { alwaysOn, pushToTalk }

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
  const _PanelHeader({required this.deviceName, required this.onClose});

  final String deviceName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(R.sm),
            ),
            child: Icon(LucideIcons.settings, size: 18, color: c.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kontrol sesi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textHi,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: c.textLow),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tutup panel',
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
      (SessionPanelSection.stream, 'Stream'),
      (SessionPanelSection.audio, 'Audio & mik'),
      (SessionPanelSection.controls, 'Kontrol'),
      (SessionPanelSection.session, 'Sesi'),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final active = value == tab.$1;
          return InkWell(
            onTap: () => onChanged(tab.$1),
            borderRadius: BorderRadius.circular(R.sm),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? c.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(R.sm),
              ),
              child: Text(
                tab.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? c.accent : c.textMid,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StreamPanel extends ConsumerWidget {
  const _StreamPanel({this.transport = const TransportState()});

  final TransportState transport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final codec = settings.codec.split(' ')[0];
    final resolution = settings.resolution.split(' ')[0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Kualitas gambar',
          subtitle: 'Preferensi dipakai saat transport video tersedia.',
        ),
        _PanelCard(
          child: Column(
            children: [
              _InfoRow(
                icon: LucideIcons.monitor,
                title: 'Resolusi',
                value: resolution,
              ),
              const _CardGap(),
              _InfoRow(icon: LucideIcons.cpu, title: 'Codec', value: codec),
              const _CardGap(),
              _SliderRow(
                label: 'Bitrate maksimal',
                valueLabel: '${settings.bitrateMbps} Mbps',
                value: (settings.bitrateMbps - 5) / 45,
                onChanged: (value) => ref
                    .read(settingsProvider.notifier)
                    .setBitrateMbps((5 + value * 45).round()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SectionTitle(title: 'Status transport'),
        _StatusCard(
          icon: transport.status == TransportStatus.error
              ? LucideIcons.wifiOff
              : LucideIcons.video,
          title: switch (transport.status) {
            TransportStatus.connected => 'Video terhubung ke host',
            TransportStatus.pairing => 'Menghubungi host…',
            TransportStatus.negotiating => 'Negosiasi koneksi…',
            TransportStatus.rejected => 'Pairing ditolak',
            TransportStatus.peerOffline => 'Host tidak online',
            TransportStatus.hostBusy => 'Perangkat sedang dipakai',
            TransportStatus.ended => 'Sesi berakhir',
            TransportStatus.error => 'Koneksi gagal',
            TransportStatus.preview => 'Transport tidak aktif',
          },
          body: transport.status == TransportStatus.connected
              ? 'Video diterima dari host. Statistik jaringan & kualitas akan '
                    'tampil di sini saat telemetry hadir.'
              : (transport.message ??
                    'Tidak ada sesi aktif. Mulai sesi dari daftar perangkat.'),
        ),
      ],
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
              'Daftar perangkat belum tersedia karena engine audio belum '
              'terhubung. Diperlukan: $requirement.',
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
                    ? 'Preferensi tersimpan • belum aktif'
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
                    ? 'Preferensi tersimpan • belum mengirim audio'
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
  const _SessionPanel({required this.deviceName, required this.onDisconnect});

  final String deviceName;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Tentang sesi'),
        _PanelCard(
          child: Column(
            children: [
              _InfoRow(
                icon: LucideIcons.monitor,
                title: 'Perangkat',
                value: deviceName,
              ),
              const _CardGap(),
              const _InfoRow(
                icon: LucideIcons.wifi,
                title: 'Transport',
                value: 'Tidak terhubung',
              ),
              const _CardGap(),
              const _InfoRow(
                icon: LucideIcons.video,
                title: 'Video',
                value: 'Tidak aktif',
              ),
              const _CardGap(),
              const _InfoRow(
                icon: LucideIcons.volume2,
                title: 'Audio',
                value: 'Belum diimplementasikan',
              ),
            ],
          ),
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
