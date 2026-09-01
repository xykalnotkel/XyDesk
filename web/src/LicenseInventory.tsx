import { useState } from 'react';

import {
  LICENSE_DART,
  LICENSE_HIGHLIGHTS,
  LICENSE_NPM,
  LICENSE_RUST,
  LICENSE_SUMMARY,
} from './licenses.generated';

/// Inventaris lisensi.
///
/// Datanya berasal dari `web/src/licenses.generated.ts` yang ditulis oleh
/// `tool/gen-licenses.mjs`. Daftar panjang dilipat per ekosistem supaya
/// halaman tetap bisa dibaca, tetapi tidak ada satu pun entri yang dibuang —
/// daftar lisensi yang tidak lengkap adalah masalah hukum, bukan sekadar
/// dokumentasi yang kurang rapi.
export default function LicenseInventory() {
  const groups = [
    { key: 'dart', label: 'Paket Dart / Flutter', items: LICENSE_DART },
    { key: 'rust', label: 'Crate Rust (aplikasi Host)', items: LICENSE_RUST },
    { key: 'npm', label: 'Paket npm (web & layanan)', items: LICENSE_NPM },
  ] as const;
  const [open, setOpen] = useState<string | null>(null);

  return (
    <div className="license-inventory">
      <div className="license-summary">
        {LICENSE_SUMMARY.slice(0, 8).map(([name, count]) => (
          <span key={name} className="license-chip">
            {name} <b>{count}</b>
          </span>
        ))}
      </div>

      <h3>Komponen inti, aset, dan layanan</h3>
      {LICENSE_HIGHLIGHTS.map((l) => (
        <div className="license-card" key={l.name}>
          <strong>{l.name}</strong>
          <span>{l.license}</span>
          <p>{l.note}</p>
        </div>
      ))}

      <h3>Inventaris penuh</h3>
      {groups.map((g) => (
        <div className="license-group" key={g.key}>
          <button
            className="license-toggle"
            onClick={() => setOpen(open === g.key ? null : g.key)}
          >
            <span>{g.label}</span>
            <span className="license-count">{g.items.length} komponen</span>
            <span className="license-caret">{open === g.key ? '−' : '+'}</span>
          </button>
          {open === g.key && (
            <div className="license-table">
              {g.items.map((l) => (
                <div className="license-row" key={`${l.name}@${l.version}`}>
                  <code>{l.name}</code>
                  <span className="license-version">{l.version}</span>
                  <span className="license-spdx">{l.license}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
