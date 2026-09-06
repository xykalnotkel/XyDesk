-- Schema XyDesk News (D1). Idempoten — aman dijalankan ulang.

CREATE TABLE IF NOT EXISTS posts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  excerpt TEXT NOT NULL,
  content TEXT NOT NULL,
  cover TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'umum',
  author TEXT NOT NULL DEFAULT 'Haekal Saputra',
  published INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS likes (
  post_id INTEGER NOT NULL REFERENCES posts(id),
  fp TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (post_id, fp)
);

CREATE TABLE IF NOT EXISTS comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id INTEGER NOT NULL REFERENCES posts(id),
  author TEXT NOT NULL,
  content TEXT NOT NULL,
  fp TEXT NOT NULL DEFAULT '',
  parent_id INTEGER,
  -- Badge resmi. HANYA diisi 1 oleh worker saat request membawa
  -- ADMIN_TOKEN. Tidak pernah dibaca dari body request — kalau boleh
  -- dikirim klien, badge-nya tidak berarti apa-apa.
  official INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Pelanggan email berita (fitur rilis 6.0).
CREATE TABLE IF NOT EXISTS subscribers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  -- 'berita' (bawaan) atau 'unduhan' — lihat migrations/0003.
  source TEXT NOT NULL DEFAULT 'berita',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Alias slug artikel.
--
-- Footer web dan layar "Tentang" menautkan versi berjalan ke slug kanonik
-- `changelog-vX-Y-Z` (CHANGELOG_SLUG di web/src/version.ts), tetapi sebagian
-- rilis terlanjur terbit dengan slug lain atau disisipkan langsung ke D1 di
-- luar endpoint publish. Mengganti slug artikelnya akan memutus tautan yang
-- sudah terlanjur tersebar lewat push/email, jadi keduanya dipetakan di sini.
-- Barisnya diisi news/migrate.mjs, bukan berkas ini — tabelnya boleh dibuat
-- ulang kapan pun, tapi isinya adalah data produksi.
CREATE TABLE IF NOT EXISTS post_aliases (
  alias TEXT PRIMARY KEY,
  slug TEXT NOT NULL REFERENCES posts(slug),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_posts_published ON posts(published, created_at DESC);
