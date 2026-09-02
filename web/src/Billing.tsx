// Halaman Billing: sewa PC (bayar per jam, dikendalikan lewat XyDesk) dan
// jalur beli PC. Keputusan produk & harga oleh operator (chat, 3 Sep 2026):
// sewa mulai 1 jam / Rp 5.000.
//
// JUJUR SOAL OTOMASI: pembayaran & pembuatan billing otomatis belum aktif —
// backend + gateway pembayarannya belum dibangun (lihat HANDOFF.md bagian
// Backend). Sampai itu siap, pemesanan berjalan lewat WhatsApp dan operator
// mengirim ID + password + kode billing secara manual. Halaman ini TIDAK
// berpura-pura punya pembayaran otomatis.
import { useMemo, useState } from 'react';

/// Nomor WhatsApp pemesanan (format internasional tanpa +). Kosong = tombol
/// pesan memakai saluran WhatsApp resmi sebagai cadangan.
const ORDER_WA = '6283116632566';
const WA_CHANNEL = 'https://whatsapp.com/channel/0029VbB7nwuJZg3ym6UQ4Z1L';

type Paket = {
  id: string;
  nama: string;
  hargaPerJam: number;
  ringkas: string;
  spesifikasi: string[];
  unggulan?: boolean;
};

// Spesifikasi tiap paket menyusul dari operator — angka harga dasar
// (Rp 5.000/jam) adalah keputusan operator; dua tingkat di atasnya
// mengikuti pola umum warnet dan mudah diubah di sini.
const PAKETS: Paket[] = [
  {
    id: 'reguler',
    nama: 'Reguler',
    hargaPerJam: 5000,
    ringkas: 'Buat kerja, browsing, dan game ringan.',
    spesifikasi: ['PC warnet standar', 'Game populer terpasang', 'Simpanan sesi aman'],
  },
  {
    id: 'gaming',
    nama: 'Gaming',
    hargaPerJam: 8000,
    ringkas: 'Buat game kompetitif dengan frame stabil.',
    spesifikasi: ['GPU kelas gaming', 'Monitor refresh tinggi', 'Game AAA siap main'],
    unggulan: true,
  },
  {
    id: 'pro',
    nama: 'Pro',
    hargaPerJam: 12000,
    ringkas: 'Buat streaming, render, dan game berat.',
    spesifikasi: ['GPU + CPU tertinggi kami', 'RAM lega untuk multitask', 'Prioritas bandwidth'],
  },
];

const DURASI = [1, 2, 3, 5, 10];

function rupiah(n: number): string {
  return 'Rp ' + n.toLocaleString('id-ID');
}

export default function BillingPage() {
  const [paketId, setPaketId] = useState('gaming');
  const [jam, setJam] = useState(1);
  const paket = useMemo(() => PAKETS.find((p) => p.id === paketId) ?? PAKETS[0], [paketId]);
  const total = paket.hargaPerJam * jam;

  const pesan = `Halo XySpace! Mau sewa PC:%0A- Paket: ${paket.nama}%0A- Durasi: ${jam} jam%0A- Total: ${rupiah(total)}`;
  const orderHref = ORDER_WA ? `https://wa.me/${ORDER_WA}?text=${pesan}` : WA_CHANNEL;

  return (
    <main className="content-page billing-page">
      <p className="eyebrow">SEWA PC</p>
      <h1>
        Main di PC kencang, bayar <span className="grad">per jam</span>.
      </h1>
      <p className="page-lead">
        Tidak punya PC gaming? Sewa punya kami. Kamu terima ID + password,
        konek lewat XyDesk dari HP atau browser, dan PC-nya jadi milikmu
        selama durasi berjalan. Mulai {rupiah(5000)} / jam.
      </p>

      <section className="billing-pakets">
        {PAKETS.map((p) => (
          <button
            type="button"
            key={p.id}
            className={`paket-card${p.id === paketId ? ' active' : ''}${p.unggulan ? ' featured' : ''}`}
            onClick={() => setPaketId(p.id)}
          >
            {p.unggulan && <span className="paket-flag">Paling laris</span>}
            <h3>{p.nama}</h3>
            <p className="paket-harga">
              <strong>{rupiah(p.hargaPerJam)}</strong> / jam
            </p>
            <p className="paket-ringkas">{p.ringkas}</p>
            <ul>
              {p.spesifikasi.map((s) => (
                <li key={s}>{s}</li>
              ))}
            </ul>
          </button>
        ))}
      </section>

      <section className="billing-order surface-card">
        <h2>Hitung sewamu</h2>
        <div className="durasi-row">
          {DURASI.map((d) => (
            <button
              type="button"
              key={d}
              className={`durasi-chip${d === jam ? ' active' : ''}`}
              onClick={() => setJam(d)}
            >
              {d} jam
            </button>
          ))}
        </div>
        <div className="order-summary">
          <div>
            <span>
              Paket {paket.nama} · {jam} jam
            </span>
            <small>
              {rupiah(paket.hargaPerJam)} × {jam}
            </small>
          </div>
          <strong>{rupiah(total)}</strong>
        </div>
        <a className="btn primary big" href={orderHref} target="_blank" rel="noopener noreferrer">
          Pesan via WhatsApp
        </a>
        <p className="order-note">
          Pembayaran otomatis (QRIS) sedang disiapkan — untuk sekarang pesanan
          dikonfirmasi manual oleh tim, biasanya dalam hitungan menit pada jam
          operasional.
        </p>
      </section>

      <section className="billing-steps">
        <h2>Cara kerjanya</h2>
        <ol>
          <li>
            <strong>Pilih paket & durasi</strong>
            <p>Tentukan spek PC dan berapa lama kamu main — mulai dari 1 jam.</p>
          </li>
          <li>
            <strong>Bayar</strong>
            <p>Selesaikan pembayaran lewat WhatsApp (QRIS otomatis menyusul).</p>
          </li>
          <li>
            <strong>Terima akses</strong>
            <p>
              Kamu dikirimi <strong>ID + password XyDesk</strong> dan{' '}
              <strong>kode billing</strong> untuk PC-nya.
            </p>
          </li>
          <li>
            <strong>Konek & main</strong>
            <p>
              Masuk lewat halaman Connect atau aplikasi. Saat menebus kode
              billing, masukkan <strong>4 digit terakhir nomor WhatsApp</strong>{' '}
              kamu (contoh: 2566) sebagai verifikasi.
            </p>
          </li>
        </ol>
      </section>

      <section className="billing-buy surface-card">
        <h2>Mau sekalian beli PC?</h2>
        <p className="muted">
          Kami juga merakit PC sesuai budget — konsultasi spek gratis, garansi
          toko, dan XyDesk Host terpasang siap remote dari hari pertama.
        </p>
        <a className="btn ghost" href={orderHref} target="_blank" rel="noopener noreferrer">
          Konsultasi via WhatsApp
        </a>
      </section>
    </main>
  );
}
