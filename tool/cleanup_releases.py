#!/usr/bin/env python3
"""Bersihkan rilis & tag lama XyDesk saat rilis baru terbit.

Kebijakan operator (14 Sep 2026): ketika rilis baru diterbitkan, rilis dan
tag lama dihapus supaya halaman Release tinggal satu entri bersih.
Urutan WAJIB (demi updater klien yang membaca `releases/latest`):

  1. Terbitkan rilis baru dulu (Build -> Release workflow seperti biasa).
  2. Baru jalankan skrip ini dengan `--keep <tag-baru>`.

Tanpa `--yes` skrip hanya DRY-RUN (menampilkan apa yang akan dihapus).
Dengan `--yes` eksekusi sungguhan — tindakan ini TIDAK bisa di-undo.

Token: env GITHUB_TOKEN (butuh scope `repo` / `delete_repo` tidak perlu;
hapus release & tag cukup dengan `repo` untuk repo privat, `public_repo`
untuk publik).
"""
from __future__ import annotations

import argparse
import os
import sys
import urllib.request

REPO = "xykalnotkel/XyDesk"
API = f"https://api.github.com/repos/{REPO}"


def _get(path: str, token: str) -> object:
    req = urllib.request.Request(
        API + path,
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "xydesk-cleanup",
        },
    )
    import json

    with urllib.request.urlopen(req, timeout=30) as res:
        return json.load(res)


def _delete(path: str, token: str) -> int:
    req = urllib.request.Request(
        API + path,
        method="DELETE",
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "xydesk-cleanup",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as res:
        return res.status


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--keep",
        required=True,
        help="Tag rilis baru yang DIPERTAHANKAN (mis. v6.9.0). "
        "Semua rilis & tag lain akan dihapus.",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Eksekusi sungguhan. Tanpa ini hanya dry-run.",
    )
    args = parser.parse_args()

    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        print("GAGAL: env GITHUB_TOKEN wajib diisi.", file=sys.stderr)
        return 2

    releases = _get("/releases?per_page=100", token)
    keep_rel = next((r for r in releases if r["tag_name"] == args.keep), None)
    if keep_rel is None:
        print(
            f"GAGAL: rilis dengan tag {args.keep} belum ada. "
            "Terbitkan rilis barunya DULU (aturan urutan), baru bersihkan.",
            file=sys.stderr,
        )
        return 3

    # Pastikan yang kept benar-benar `latest` menurut API sebelum menghapus
    # apa pun — updater klien membaca endpoint ini.
    latest = _get("/releases/latest", token)
    if latest.get("tag_name") != args.keep:
        print(
            f"GAGAL: /releases/latest = {latest.get('tag_name')}, bukan "
            f"{args.keep}. Jangan hapus apa pun sebelum rilis baru jadi "
            "latest, atau updater klien 404.",
            file=sys.stderr,
        )
        return 4

    doomed_releases = [r for r in releases if r["tag_name"] != args.keep]
    tags = _get("/tags?per_page=100", token)
    doomed_tags = [t for t in tags if t["name"] != args.keep]

    print(f"Pertahankan : rilis {args.keep} (latest) ")
    print(f"Akan hapus  : {len(doomed_releases)} rilis + "
          f"{len(doomed_tags)} tag")
    for r in doomed_releases:
        print(f"  - release {r['tag_name']} ({r['name'][:40]})")
    for t in doomed_tags:
        print(f"  - tag     {t['name']}")

    if not args.yes:
        print("\nDRY-RUN. Jalankan lagi dengan --yes untuk eksekusi.")
        return 0

    for r in doomed_releases:
        status = _delete(f"/releases/{r['id']}", token)
        print(f"hapus release {r['tag_name']} -> {status}")
    for t in doomed_tags:
        status = _delete(f"/git/refs/tags/{t['name']}", token)
        print(f"hapus tag     {t['name']} -> {status}")
    print("SELESAI. Halaman Release kini satu entri.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
