#!/usr/bin/env python3
"""Gerbang konsistensi versi.

`pubspec.yaml` adalah satu-satunya sumber nomor versi XyDesk (lihat
`docs/VERSIONING.md`). Skrip ini memastikan setiap manifest turunan menyebut
angka yang sama, dan bahwa versi teratas `CHANGELOG.md` cocok.

Latar belakangnya nyata: footer situs memajang "v2.5.0" selama empat rilis
karena angkanya diketik tangan di JSX dan tidak ada yang membandingkannya
dengan apa pun.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def pubspec_version() -> tuple[str, int]:
    m = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", read("pubspec.yaml"), re.M)
    if not m:
        sys.exit("VERSI GAGAL: pubspec.yaml tidak punya baris 'version: X.Y.Z+NN'")
    return m.group(1), int(m.group(2))


def main() -> None:
    version, build = pubspec_version()
    problems: list[str] = []

    # host/Cargo.toml — versi paket, ambil kemunculan pertama di [package].
    m = re.search(r'^version\s*=\s*"([^"]+)"', read("host/Cargo.toml"), re.M)
    if not m or m.group(1) != version:
        problems.append(
            f"host/Cargo.toml = {m.group(1) if m else 'tidak ada'}, seharusnya {version}"
        )

    for pkg in ("web/package.json", "desktop/package.json"):
        path = ROOT / pkg
        if not path.exists():
            continue
        got = json.loads(read(pkg)).get("version")
        if got != version:
            problems.append(f"{pkg} = {got}, seharusnya {version}")

    # CHANGELOG wajib punya entri untuk versi ini, di paling atas.
    m = re.search(r"^## \[([^\]]+)\]", read("CHANGELOG.md"), re.M)
    if not m or m.group(1) != version:
        problems.append(
            f"CHANGELOG.md entri teratas = {m.group(1) if m else 'tidak ada'}, "
            f"seharusnya {version}"
        )

    # Angka versi tidak boleh diketik tangan di sumber web.
    for rel in ("web/src/App.tsx", "web/src/version.ts"):
        for hit in re.findall(r"v\d+\.\d+\.\d+", read(rel)):
            problems.append(f"{rel} memuat versi literal '{hit}' — baca APP_VERSION")

    if problems:
        print("VERSI GAGAL:")
        for p in problems:
            print(f"  - {p}")
        sys.exit(1)

    print(f"Lulus: versi {version}+{build} konsisten di semua manifest.")


if __name__ == "__main__":
    main()
