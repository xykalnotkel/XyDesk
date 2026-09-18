"""Bungkus payload MSVC yang sudah diuji; tidak membangun atau mengubah engine."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import zipfile

HERE = Path(__file__).resolve().parent


def safe_relative(name):
    p = PurePosixPath(name)
    if p.is_absolute() or '..' in p.parts or any(c in name for c in '\\:\r\n"$'):
        raise ValueError('Nama berkas ZIP tidak aman')
    return p


def quote(value):
    return str(value).replace('$', '$$').replace('"', '$\\"')


def prepare(archive, work, source_sha, expected_zip_sha=None):
    data = archive.read_bytes()
    if not expected_zip_sha or hashlib.sha256(data).hexdigest() != expected_zip_sha:
        raise ValueError('SHA-256 payload ZIP tidak cocok')
    payload = work / 'payload'
    generated = work / 'generated'
    # Tidak menghapus pohon direktori yang mungkin berisi berkas pengguna.
    payload.mkdir(parents=True, exist_ok=False)
    generated.mkdir(parents=True, exist_ok=False)
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:
            raise ValueError('CRC ZIP gagal')
        for info in z.infolist():
            rel = safe_relative(info.filename)
            dest = payload.joinpath(*rel.parts)
            if info.is_dir():
                dest.mkdir(parents=True, exist_ok=True)
            else:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(z.read(info))
    manifest = json.loads((payload / 'manifest.json').read_text(encoding='utf-8-sig'))
    if manifest['version'] != '6.8.5' or manifest['target'] != 'x86_64-pc-windows-msvc':
        raise ValueError('Versi/arsitektur payload tidak cocok')
    if not re.fullmatch(r'[0-9a-f]{40}', source_sha) or manifest.get('sourceSha') != source_sha:
        raise ValueError('Engine bukan dari source SHA yang sedang dikemas')
    expected_engine_sha=manifest.get('sha256','')
    if not re.fullmatch(r'[0-9a-f]{64}', expected_engine_sha) or hashlib.sha256((payload / 'xydesk-host.exe').read_bytes()).hexdigest() != expected_engine_sha:
        raise ValueError('Engine berubah')
    shutil.copy2(HERE.parent / 'manual-host' / 'Start-TestHost.ps1', payload / 'Start-TestHost.ps1')
    shutil.copy2(HERE.parent / 'windows' / 'xydesk.ico', payload / 'xydesk.ico')
    shutil.copy2(HERE / 'README-INSTALLER.txt', payload / 'README-INSTALLER.txt')
    (payload / 'installer-source.json').write_text(json.dumps({
        'installerSourceSha': source_sha, 'engineSourceSha': manifest['sourceSha'],
        'payloadZipSha256': expected_zip_sha, 'engineSha256': expected_engine_sha,
    }, indent=2) + '\n', encoding='utf-8')
    files = sorted(p.relative_to(payload) for p in payload.rglob('*') if p.is_file())
    total = sum((payload / p).stat().st_size for p in files)
    install = [f'!define ESTIMATED_KB {math.ceil(total / 1024) + 512}']
    uninstall = []
    dirs = set()
    for rel in files:
        parent = str(rel.parent).replace('/', '\\')
        path = str(rel).replace('/', '\\')
        target = '$INSTDIR' if parent == '.' else '$INSTDIR\\' + quote(parent)
        install.append(f'SetOutPath "{target}"')
        install.append(f'File "{quote(payload / rel)}"')
        uninstall.append(f'Delete "$INSTDIR\\{quote(path)}"')
        dirs.update(p for p in rel.parents if str(p) != '.')
    for rel in sorted(dirs, key=lambda p: (-len(p.parts), str(p))):
        path = str(rel).replace('/', '\\')
        uninstall.append(f'RMDir "$INSTDIR\\{quote(path)}"')
    (generated / 'install-files.nsh').write_text('\n'.join(install) + '\n', encoding='utf-8-sig')
    (generated / 'uninstall-files.nsh').write_text('\n'.join(uninstall) + '\n', encoding='utf-8-sig')
    return payload, generated


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('archive', type=Path)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--makensis', default='makensis')
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--expected-zip-sha', required=True)
    args = parser.parse_args()
    payload, generated = prepare(args.archive.resolve(), args.work.resolve(), args.source_sha, args.expected_zip_sha)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    prefix = '/' if __import__('os').name == 'nt' else '-'
    subprocess.run([
        args.makensis, prefix + 'V3',
        prefix + 'DPAYLOAD=' + str(payload),
        prefix + 'DGENERATED=' + str(generated),
        prefix + 'DOUTPUT=' + str(args.output.resolve()), str(HERE / 'host-test.nsi'),
    ], check=True)
    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    args.output.with_suffix('.exe.sha256').write_text(digest + '  ' + args.output.name + '\n')
    print(json.dumps({'installer': args.output.name, 'sha256': digest,
                      'bytes': args.output.stat().st_size, 'engineSha256': json.loads((payload/'manifest.json').read_text(encoding='utf-8-sig'))['sha256']}))


if __name__ == '__main__':
    main()
