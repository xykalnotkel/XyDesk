// Kontrol sesi lanjutan versi web: keyboard virtual penuh + panel gaming.
// Cermin konsep dari lib/features/session/virtual_keyboard.dart dan
// session_panels.dart di aplikasi Android — protokolnya sama persis
// (host/src/input.rs), hanya medianya yang beda.
import { useState } from 'react';
import { InputCodec } from './rtc';

type Send = (bytes: Uint8Array) => void;

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

// ── Panel pengaturan sesi ──────────────────────────────────────
// Cermin ringkas SessionControlPanel aplikasi Android — hanya setelan
// yang BENAR-BENAR bisa dikendalikan browser. Tidak ada slider palsu.
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

export function SessionPanel({
  prefs,
  onChange,
  onClose,
  hostId,
  onDisconnect,
}: {
  prefs: SessionPrefs;
  onChange: (next: SessionPrefs) => void;
  onClose: () => void;
  hostId: string;
  onDisconnect: () => void;
}) {
  return (
    <aside className="spanel" onPointerDown={(e) => e.stopPropagation()} onWheel={(e) => e.stopPropagation()}>
      <header className="spanel-head">
        <strong>Pengaturan sesi</strong>
        <button type="button" className="spanel-close" onClick={onClose} title="Tutup">
          ✕
        </button>
      </header>

      <p className="spanel-section">Audio</p>
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

      <p className="spanel-section">Trackpad</p>
      <div className="spanel-row">
        <div className="spanel-copy">
          <span>Sensitivitas kursor</span>
          <small>{prefs.sens.toFixed(1)}×</small>
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

      <p className="spanel-section">Sesi</p>
      <div className="spanel-row">
        <div className="spanel-copy">
          <span>Terhubung ke</span>
          <small className="spanel-host">{hostId}</small>
        </div>
      </div>
      <button type="button" className="spanel-disconnect" onClick={onDisconnect}>
        Putuskan sesi
      </button>
    </aside>
  );
}
