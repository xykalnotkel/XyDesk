-- Badge resmi pada komentar (rilis 6.2).
--
-- Nama saja tidak pernah cukup: siapa pun bisa mengetik "Haekal Saputra" di
-- kolom nama. Badge harus berasal dari sesuatu yang hanya dimiliki tim —
-- di sini ADMIN_TOKEN yang sama dengan penerbitan artikel.
--
-- D1 tidak punya "ADD COLUMN IF NOT EXISTS"; jalankan sekali saja:
--   npx wrangler d1 execute xydesk-news --remote \
--     --file=migrations/0002_official_badge.sql
ALTER TABLE comments ADD COLUMN official INTEGER NOT NULL DEFAULT 0;
