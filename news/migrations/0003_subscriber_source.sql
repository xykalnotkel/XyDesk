-- Asal pendaftaran pelanggan.
--
-- Sebelumnya satu tabel dipakai untuk dua maksud yang berbeda: orang yang
-- ingin dikabari saat ada berita, dan orang yang memencet "Ingatkan saya"
-- di halaman unduh. Tanpa pembeda, keduanya tidak bisa dikabari secara
-- terpisah — padahal yang satu menunggu artikel, yang lain menunggu tombol
-- unduh dibuka.
--
-- 'berita'  = nilai bawaan, juga nilai untuk data lama (daftar lewat artikel)
-- 'unduhan' = memencet "Ingatkan saya" saat unduhan masih ditahan
ALTER TABLE subscribers ADD COLUMN source TEXT NOT NULL DEFAULT 'berita';

CREATE INDEX IF NOT EXISTS idx_subscribers_source ON subscribers(source);
