// Kontrol sesi lanjutan versi web: rail kontrol ikon di tepi kanan,
// panel pengaturan ber-tab (Gambar/Suara/Kontrol/Sesi), keyboard virtual
// penuh, dan panel gaming. Cermin konsep dari lib/features/session/
// session_page.dart (rail kanan + sembunyikan kontrol) dan
// session_panels.dart (empat tab panel) di aplikasi — protokol inputnya
// sama persis (host/src/input.rs), hanya medianya yang beda.
import { useEffect, useState } from 'react';
import { InputCodec } from './rtc';
import type { SessionStats } from './rtc';

type Send = (bytes: Uint8Array) => void;

// ── Ikon garis (stroke) 24px, ala set ikon aplikasi ────────────
// Digambar inline supaya overlay sesi tidak menunggu aset eksternal.
function Svg({ children }: { children: React.ReactNode }) {
  return (
    <svg
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}
const IcChevronLeft = () => <Svg><path d="M15 18l-6-6 6-6" /></Svg>;
const IcChevronRight = () => <Svg><path d="M9 18l6-6-6-6" /></Svg>;
const IcVolume = () => (
  <Svg>
    <path d="M11 5L6 9H2v6h4l5 4V5z" />
    <path d="M15.5 8.5a5 5 0 0 1 0 7" />
    <path d="M18.3 5.7a9 9 0 0 1 0 12.6" />
  </Svg>
);
const IcMic = () => (
  <Svg>
    <rect x="9" y="2" width="6" height="12" rx="3" />
    <path d="M5 10a7 7 0 0 0 14 0" />
    <path d="M12 17v4" />
  </Svg>
);
const IcKeyboard = () => (
  <Svg>
    <rect x="2" y="6" width="20" height="12" rx="2" />
    <path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M8 14h8" />
  </Svg>
);
const IcGamepad = () => (
  <Svg>
    <path d="M6 11h4M8 9v4" />
    <path d="M15 12h.01M18 10h.01" />
    <path d="M17.3 5H6.7a4 4 0 0 0-4 3.6C2.6 9.4 2 14.5 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.4-1.4a2 2 0 0 1 1.4-.6h4.4a2 2 0 0 1 1.4.6L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.5-.6-6.6-.7-7.4a4 4 0 0 0-4-3.6z" />
  </Svg>
);
const IcMove = () => (
  <Svg>
    <path d="M5 9l-3 3 3 3M9 5l3-3 3 3M15 19l-3 3-3-3M19 9l3 3-3 3" />
    <path d="M2 12h20M12 2v20" />
  </Svg>
);
const IcClipboardUp = () => (
  <Svg>
    <rect x="8" y="2" width="8" height="4" rx="1" />
    <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" />
    <path d="M12 16V8M9 11l3-3 3 3" />
  </Svg>
);
const IcClipboardDown = () => (
  <Svg>
    <rect x="8" y="2" width="8" height="4" rx="1" />
    <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" />
    <path d="M12 8v8M9 13l3 3 3-3" />
  </Svg>
);
const IcFullscreen = () => (
  <Svg>
    <path d="M8 3H5a2 2 0 0 0-2 2v3M21 8V5a2 2 0 0 0-2-2h-3M3 16v3a2 2 0 0 0 2 2h3M16 21h3a2 2 0 0 0 2-2v-3" />
  </Svg>
);
const IcSliders = () => (
  <Svg>
    <path d="M21 4h-7M10 4H3M21 12h-9M8 12H3M21 20h-5M12 20H3" />
    <path d="M14 2v4M8 10v4M16 18v4" />
  </Svg>
);
const IcPower = () => (
  <Svg>
    <path d="M18.4 6.6a9 9 0 1 1-12.8 0" />
    <path d="M12 2v10" />
  </Svg>
);

// ── Rail kontrol kanan, ala aplikasi ───────────────────────────
// Kolom ikon di tepi kanan video. Bisa disembunyikan jadi pil kecil
// supaya kontrol tidak menutupi game — perilaku yang sama dengan rail
// _SessionRail di aplikasi (sembunyikan kontrol).
export function SessionRail({
  collapsed,
  onToggleCollapsed,
  audioOn,
  onAudio,
  micOn,
  onMic,
  kbOpen,
  onKeyboard,
  padOpen,
  onPad,
  trackpad,
  onTrackpad,
  onClipboardPush,
  onClipboardPull,
  onFullscreen,
  panelOpen,
  onPanel,
  onDisconnect,
}: {
  collapsed: boolean;
  onToggleCollapsed: () => void;
  audioOn: boolean;
  onAudio: () => void;
  micOn: boolean;
  onMic: () => void;
  kbOpen: boolean;
  onKeyboard: () => void;
  padOpen: boolean;
  onPad: () => void;
  trackpad: boolean;
  onTrackpad: () => void;
  onClipboardPush: () => void;
  onClipboardPull: () => void;
  onFullscreen: () => void;
  panelOpen: boolean;
  onPanel: () => void;
  onDisconnect: () => void;
}) {
  if (collapsed) {
    return (
      <button
        type="button"
        className="srail-pill"
        title="Tampilkan kontrol"
        aria-label="Tampilkan kontrol"
        onClick={onToggleCollapsed}
      >
        <IcChevronLeft />
      </button>
    );
  }
  return (
    <div className="srail" role="toolbar" aria-label="Kontrol sesi" onPointerDown={(e) => e.stopPropagation()}>
      <button type="button" className="srail-btn" title="Sembunyikan kontrol" aria-label="Sembunyikan kontrol" onClick={onToggleCollapsed}>
        <IcChevronRight />
      </button>
      <span className="srail-sep" />
      <button type="button" className={`srail-btn${audioOn ? ' on' : ''}`} title="Suara PC" aria-label="Suara PC" aria-pressed={audioOn} onClick={onAudio}>
        <IcVolume />
      </button>
      <button type="button" className={`srail-btn${micOn ? ' on' : ''}`} title="Mik ke PC" aria-label="Mik ke PC" aria-pressed={micOn} onClick={onMic}>
        <IcMic />
      </button>
      <button type="button" className={`srail-btn${kbOpen ? ' on' : ''}`} title="Keyboard" aria-label="Keyboard" aria-pressed={kbOpen} onClick={onKeyboard}>
        <IcKeyboard />
      </button>
      <button type="button" className={`srail-btn${padOpen ? ' on' : ''}`} title="Panel gaming: WASD, Shift, Spasi, E/Q/R/F — tombol tahan" aria-label="Panel gaming" aria-pressed={padOpen} onClick={onPad}>
        <IcGamepad />
      </button>
      <button type="button" className={`srail-btn${trackpad ? ' on' : ''}`} title="Mode trackpad: geser = gerak kursor, ketuk = klik, dua jari = scroll" aria-label="Mode trackpad" aria-pressed={trackpad} onClick={onTrackpad}>
        <IcMove />
      </button>
      <button type="button" className="srail-btn" title="Kirim ke papan klip PC" aria-label="Kirim ke papan klip PC" onClick={onClipboardPush}>
        <IcClipboardUp />
      </button>
      <button type="button" className="srail-btn" title="Ambil dari papan klip PC" aria-label="Ambil dari papan klip PC" onClick={onClipboardPull}>
        <IcClipboardDown />
      </button>
      <button type="button" className="srail-btn" title="Layar penuh" aria-label="Layar penuh" onClick={onFullscreen}>
        <IcFullscreen />
      </button>
      <button type="button" className={`srail-btn${panelOpen ? ' on' : ''}`} title="Pengaturan sesi" aria-label="Pengaturan sesi" aria-pressed={panelOpen} onClick={onPanel}>
        <IcSliders />
      </button>
      <span className="srail-sep" />
      <button type="button" className="srail-btn danger" title="Putuskan" aria-label="Putuskan" onClick={onDisconnect}>
        <IcPower />
      </button>
    </div>
  );
}

// ── Keyboard virtual penuh ─────────────────────────────────────
// [label, vk, lebar-relatif, modifier?]
type KeySpec = [string, number, number?, boolean?];

const VKB_ROWS: KeySpec[][] = [
  [
    ['Esc', 0x1b], ['F1', 0x70], ['F2', 0x71], ['F3', 0x72], ['F4', 0x73],
    ['F5', 0x74], ['F6', 0x75], ['F7', 0x76], ['F8', 0x77], ['F9', 0x78],
    ['F10', 0x79], ['F11', 0x7a], ['F12', 0x7b], ['\u232b', 0x08, 1.6],
  ],
  [
    ['`', 0xc0], ['1', 0x31], ['2', 0x32], ['3', 0x33], ['4', 0x34],
    ['5', 0x35], ['6', 0x36], ['7', 0x37], ['8', 0x38], ['9', 0x39],
    ['0', 0x30], ['-', 0xbd], ['=', 0xbb], ['Del', 0x2e, 1.6],
  ],
  [
    ['Tab', 0x09, 1.5], ['Q', 0x51], ['W', 0x57], ['E', 0x45], ['R', 0x52],
    ['T', 0x54], ['Y', 0x59], ['U', 0x55], ['I', 0x49], ['O', 0x4f],
    ['P', 0x50], ['[', 0xdb], [']', 0xdd], ['\\', 0xdc, 1.4],
  ],
  [
    ['Caps', 0x14, 1.8], ['A', 0x41], ['S', 0x53], ['D', 0x44], ['F', 0x46],
    ['G', 0x47], ['H', 0x48], ['J', 0x4a], ['K', 0x4b], ['L', 0x4c],
    [';', 0xba], ["'", 0xde], ['Enter', 0x0d, 2.1],
  ],
  [
    ['Shift', 0xa0, 2.2, true], ['Z', 0x5a], ['X', 0x58], ['C', 0x43],
    ['V', 0x56], ['B', 0x42], ['N', 0x4e], ['M', 0x4d], [',', 0xbc],
    ['.', 0xbe], ['/', 0xbf], ['Shift', 0xa1, 2.2, true],
  ],
  [
    ['Ctrl', 0xa2, 1.5, true], ['Win', 0x5b, 1.2, true],
    ['Alt', 0xa4, 1.2, true], ['Spasi', 0x20, 5.4],
    ['Alt', 0xa5, 1.1, true], ['\u2190', 0x25], ['\u2191', 0x26],
    ['\u2193', 0x28], ['\u2192', 0x27],
  ],
];

/// Keyboard QWERTY penuh dengan modifier lengket: ketuk Ctrl/Shift/Alt/Win
/// untuk menahannya, tombol biasa berikutnya dikirim bersama modifier lalu
/// modifier dilepas otomatis — pola yang sama dengan keyboard virtual
/// aplikasi Android. Caps dikirim sebagai ketukan biasa karena host yang
/// memegang status caps lock sesungguhnya.
export function VirtualKeyboard({ send }: { send: Send }) {
  const [held, setHeld] = useState<ReadonlySet<number>>(new Set());

  const tap = (vk: number, modifier: boolean) => {
    if (modifier) {
      if (held.has(vk)) {
        send(InputCodec.key(vk, false));
        const next = new Set(held);
        next.delete(vk);
        setHeld(next);
      } else {
        send(InputCodec.key(vk, true));
        setHeld(new Set(held).add(vk));
      }
      return;
    }
    send(InputCodec.key(vk, true));
    send(InputCodec.key(vk, false));
    if (held.size) {
      for (const m of held) send(InputCodec.key(m, false));
      setHeld(new Set());
    }
  };

  return (
    <div className="vkb" onPointerDown={(e) => e.stopPropagation()}>
      {VKB_ROWS.map((row, i) => (
        <div className="vkb-row" key={i}>
          {row.map(([label, vk, flex = 1, modifier = false], j) => (
            <button
              key={`${label}-${j}`}
              type="button"
              className={`vkb-key${modifier ? ' mod' : ''}${held.has(vk) ? ' on' : ''}`}
              style={{ flexGrow: flex, flexBasis: 0 }}
              onClick={() => tap(vk, modifier)}
            >
              {label}
            </button>
          ))}
        </div>
      ))}
    </div>
  );
}

// ── Panel gaming dua sisi ──────────────────────────────────────
// Tombol TAHAN, bukan ketuk: down saat jari menyentuh, up saat lepas —
// wajib untuk gerak WASD dan sprint. Glyph border-only seperti HUD
// aplikasi Android agar tidak menutupi game.
function HoldKey({
  vk,
  label,
  send,
  wide = false,
}: {
  vk: number;
  label: string;
  send: Send;
  wide?: boolean;
}) {
  const [down, setDown] = useState(false);
  const press = (isDown: boolean) => {
    if (isDown === down) return;
    setDown(isDown);
    send(InputCodec.key(vk, isDown));
  };
  return (
    <button
      type="button"
      className={`gp-key${wide ? ' wide' : ''}${down ? ' down' : ''}`}
      onPointerDown={(e) => {
        e.stopPropagation();
        e.currentTarget.setPointerCapture?.(e.pointerId);
        press(true);
      }}
      onPointerUp={() => press(false)}
      onPointerCancel={() => press(false)}
      onContextMenu={(e) => e.preventDefault()}
    >
      {label}
    </button>
  );
}

/// Dua gugus kontrol gaming: kiri = gerak (WASD + Shift/Ctrl),
/// kanan = aksi (Spasi lompat, E/Q/R/F interaksi, Esc/Enter).
export function GamingPad({ send }: { send: Send }) {
  return (
    <>
      <div className="gp-cluster gp-left" onPointerDown={(e) => e.stopPropagation()}>
        <div className="gp-row"><HoldKey vk={0x57} label="W" send={send} /></div>
        <div className="gp-row">
          <HoldKey vk={0x41} label="A" send={send} />
          <HoldKey vk={0x53} label="S" send={send} />
          <HoldKey vk={0x44} label="D" send={send} />
        </div>
        <div className="gp-row">
          <HoldKey vk={0xa0} label="Shift" send={send} wide />
          <HoldKey vk={0xa2} label="Ctrl" send={send} wide />
        </div>
      </div>
      <div className="gp-cluster gp-right" onPointerDown={(e) => e.stopPropagation()}>
        <div className="gp-row">
          <HoldKey vk={0x1b} label="Esc" send={send} wide />
          <HoldKey vk={0x0d} label="Enter" send={send} wide />
        </div>
        <div className="gp-row">
          <HoldKey vk={0x51} label="Q" send={send} />
          <HoldKey vk={0x45} label="E" send={send} />
          <HoldKey vk={0x52} label="R" send={send} />
          <HoldKey vk={0x46} label="F" send={send} />
        </div>
        <div className="gp-row">
          <HoldKey vk={0x20} label="Spasi" send={send} wide />
        </div>
      </div>
    </>
  );
}

// ── Panel pengaturan sesi: empat tab ala aplikasi ──────────────
// Tab yang sama dengan SessionControlPanel aplikasi: Gambar, Suara,
// Kontrol, Sesi. Hanya setelan yang BENAR-BENAR bisa dikendalikan
// browser — tidak ada slider pajangan.
export type SessionPrefs = {
  /// Volume audio PC di sisi browser (elemen <audio>), 0..1.
  volume: number;
  /// Sensitivitas gerak kursor mode trackpad.
  sens: number;
  /// Ketuk singkat = klik kiri (mode trackpad).
  tapClick: boolean;
  /// Arah scroll dua jari dibalik.
  reverseScroll: boolean;
};

export const DEFAULT_PREFS: SessionPrefs = {
  volume: 0.8,
  sens: 1.7,
  tapClick: true,
  reverseScroll: false,
};

function ToggleRow({
  label,
  hint,
  on,
  onToggle,
}: {
  label: string;
  hint?: string;
  on: boolean;
  onToggle: () => void;
}) {
  return (
    <div className="spanel-row">
      <div className="spanel-copy">
        <span>{label}</span>
        {hint && <small>{hint}</small>}
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={on}
        className={`spanel-switch${on ? ' on' : ''}`}
        onClick={onToggle}
      >
        <i />
      </button>
    </div>
  );
}

function StatRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="stat-line">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

/// "12,4 Mbps" / "0,0 %" — angka Indonesia, koma desimal, tanpa library.
function idNum(n: number, digits = 0) {
  return n.toFixed(digits).replace('.', ',');
}

type PanelTab = 'gambar' | 'suara' | 'kontrol' | 'sesi';

const PANEL_TABS: [PanelTab, string, React.ReactNode][] = [
  ['gambar', 'Gambar', <Svg key="g"><rect x="2" y="3" width="20" height="14" rx="2" /><path d="M8 21h8M12 17v4" /></Svg>],
  ['suara', 'Suara', <IcVolume key="v" />],
  ['kontrol', 'Kontrol', <IcGamepad key="k" />],
  ['sesi', 'Sesi', <Svg key="s"><circle cx="12" cy="12" r="9" /><path d="M12 8h.01M11 12h1v4h1" /></Svg>],
];

/// Detik sesi berjalan yang berdetak — dipakai tab Sesi dan chip HUD.
export function useElapsedSec(from: number | null) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    if (from === null) return;
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, [from]);
  if (from === null) return null;
  return Math.max(0, Math.floor((now - from) / 1000));
}

/// "1:47:26" / "12:05" — tanpa library, angka konsisten lebar.
export function fmtDurasi(totalDetik: number): string {
  const s = Math.max(0, Math.floor(totalDetik));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const ss = s % 60;
  const pad = (n: number) => String(n).padStart(2, '0');
  return h > 0 ? `${h}:${pad(m)}:${pad(ss)}` : `${m}:${pad(ss)}`;
}

export function SessionPanel({
  prefs,
  onChange,
  onClose,
  hostId,
  onDisconnect,
  stats,
  displays,
  wantedDisplay,
  onSelectDisplay,
  connectedAt,
  railCollapsed,
  totalSesiDetik,
  trackpad,
  onTrackpadMode,
}: {
  prefs: SessionPrefs;
  onChange: (next: SessionPrefs) => void;
  onClose: () => void;
  hostId: string;
  onDisconnect: () => void;
  /// Statistik live dari getStats() — null berarti belum ada sampel.
  stats: SessionStats | null;
  /// Daftar layar host (kosong bila host tidak mengirim meta/tidak multi-layar).
  displays: { index: number; name?: string; width: number; height: number }[];
  wantedDisplay: number;
  onSelectDisplay: (index: number) => void;
  /// Waktu mulai sesi (epoch ms) untuk durasi di tab Sesi.
  connectedAt: number | null;
  railCollapsed: boolean;
  /// Batas total sesi dalam detik (sesi tamu = 2 jam); null = tanpa batas.
  totalSesiDetik: number | null;
  /// Mode gerak kursor: true = trackpad (relatif), false = langsung (absolut).
  trackpad: boolean;
  onTrackpadMode: (on: boolean) => void;
}) {
  const [tab, setTab] = useState<PanelTab>('gambar');
  const elapsed = useElapsedSec(connectedAt);

  return (
    <aside
      className={`spanel${railCollapsed ? ' no-rail' : ''}`}
      onPointerDown={(e) => e.stopPropagation()}
      onWheel={(e) => e.stopPropagation()}
    >
      <header className="spanel-head">
        <strong>Pengaturan sesi</strong>
        <button type="button" className="spanel-close" onClick={onClose} title="Tutup">
          ✕
        </button>
      </header>

      <div className="spanel-tabs" role="tablist">
        {PANEL_TABS.map(([id, label, icon]) => (
          <button
            key={id}
            type="button"
            role="tab"
            aria-selected={tab === id}
            className={`spanel-tab${tab === id ? ' on' : ''}`}
            onClick={() => setTab(id)}
          >
            {icon}
            <span>{label}</span>
          </button>
        ))}
      </div>

      {tab === 'gambar' && (
        <>
          <p className="spanel-section">Yang sedang berjalan</p>
          <div className="spanel-card">
            {stats ? (
              <>
                <StatRow label="Ukuran gambar" value={stats.width ? `${stats.width}×${stats.height}` : '—'} />
                <StatRow label="Kehalusan" value={stats.fps ? `${idNum(stats.fps)} fps` : '—'} />
                <StatRow label="Pemakaian data" value={`${idNum(stats.mbps, 1)} Mbps`} />
                <StatRow label="Ping" value={stats.rttMs ? `${idNum(stats.rttMs)} ms` : '—'} />
                <StatRow label="Paket hilang" value={`${idNum(stats.lossPct, 1)} %`} />
                <StatRow label="Codec" value={stats.codec || '—'} />
              </>
            ) : (
              <p className="spanel-note">Angka kualitas muncul begitu koneksi mengalir.</p>
            )}
          </div>
          {displays.length > 1 && (
            <>
              <p className="spanel-section">Layar PC</p>
              <div className="display-chips">
                {displays.map((d) => (
                  <button
                    key={d.index}
                    type="button"
                    className={d.index === wantedDisplay ? 'active' : ''}
                    onClick={() => onSelectDisplay(d.index)}
                  >
                    {d.name || `Layar ${d.index + 1}`} · {d.width}×{d.height}
                  </button>
                ))}
              </div>
            </>
          )}
        </>
      )}

      {tab === 'suara' && (
        <>
          <p className="spanel-section">Volume</p>
          <div className="spanel-row">
            <div className="spanel-copy">
              <span>Volume audio PC</span>
              <small>{Math.round(prefs.volume * 100)}%</small>
            </div>
          </div>
          <input
            type="range"
            min={0}
            max={100}
            value={Math.round(prefs.volume * 100)}
            onChange={(e) => onChange({ ...prefs, volume: Number(e.target.value) / 100 })}
          />
          <p className="spanel-note">Volume berlaku di perangkat ini; pembicara di sekitar kamu tetap tidak terdengar PC.</p>
        </>
      )}

      {tab === 'kontrol' && (
        <>
          <p className="spanel-section">Gerak kursor</p>
          <div className="spanel-seg">
            <button
              type="button"
              className={!trackpad ? 'on' : ''}
              onClick={() => onTrackpadMode(false)}
            >
              Langsung
            </button>
            <button
              type="button"
              className={trackpad ? 'on' : ''}
              onClick={() => onTrackpadMode(true)}
            >
              Trackpad
            </button>
          </div>
          <p className="spanel-note">
            Langsung: sentuh posisi di layar. Trackpad: geser relatif seperti touchpad HP — cocok untuk game.
          </p>
          <div className="spanel-row">
            <div className="spanel-copy">
              <span>Sensitivitas trackpad</span>
              <small>{prefs.sens.toFixed(1).replace('.', ',')}×</small>
            </div>
          </div>
          <input
            type="range"
            min={8}
            max={30}
            value={Math.round(prefs.sens * 10)}
            onChange={(e) => onChange({ ...prefs, sens: Number(e.target.value) / 10 })}
          />
          <ToggleRow
            label="Ketuk untuk klik"
            hint="Ketukan singkat tanpa geser = klik kiri"
            on={prefs.tapClick}
            onToggle={() => onChange({ ...prefs, tapClick: !prefs.tapClick })}
          />
          <ToggleRow
            label="Scroll terbalik"
            hint="Balik arah scroll dua jari"
            on={prefs.reverseScroll}
            onToggle={() => onChange({ ...prefs, reverseScroll: !prefs.reverseScroll })}
          />
        </>
      )}

      {tab === 'sesi' && (
        <>
          <p className="spanel-section">Sesi</p>
          <div className="spanel-card">
            <StatRow label="Terhubung ke" value={hostId} />
            <StatRow label="Durasi" value={elapsed !== null ? fmtDurasi(elapsed) : '—'} />
            <StatRow label="Total" value={totalSesiDetik !== null ? fmtDurasi(totalSesiDetik) : 'Bebas'} />
            <StatRow
              label="Sisa waktu"
              value={
                totalSesiDetik !== null && elapsed !== null
                  ? fmtDurasi(Math.max(0, totalSesiDetik - elapsed))
                  : '—'
              }
            />
          </div>
          <button type="button" className="spanel-disconnect" onClick={onDisconnect}>
            Putuskan sesi
          </button>
        </>
      )}
    </aside>
  );
}
