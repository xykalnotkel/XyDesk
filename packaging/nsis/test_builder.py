import importlib.util
from pathlib import Path
import tempfile
import hashlib
import json
import zipfile
import unittest

spec = importlib.util.spec_from_file_location('builder', Path(__file__).with_name('build_installer.py'))
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class BuilderTests(unittest.TestCase):
    def test_valid_relative_names(self):
        for name in ['manifest.json', 'licenses/crate-1.0/LICENSE-MIT', 'licenses/']:
            self.assertFalse(builder.safe_relative(name).is_absolute())

    def test_zip_traversal_and_script_injection_rejected(self):
        for name in ['../file', 'x/../../file', '/file', 'C:/file', 'x\\file', '$INSTDIR/x', 'x"y', 'x\ny']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                builder.safe_relative(name)

    def test_wrong_payload_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            bad = root / 'bad.zip'
            bad.write_bytes(b'not-the-pinned-payload')
            with self.assertRaisesRegex(ValueError, 'SHA-256'):
                builder.prepare(bad, root / 'work', 'fixture')
            self.assertFalse((root / 'work').exists())

    def test_wrong_source_and_engine_rejected(self):
        for wrong_source in [True, False]:
            with self.subTest(wrong_source=wrong_source), tempfile.TemporaryDirectory() as folder:
                root=Path(folder);archive=root/'payload.zip';engine=b'MZfixture'
                manifest={'version':'6.8.5','target':'x86_64-pc-windows-msvc','sourceSha':'a'*40 if wrong_source else 'b'*40,'sha256':'0'*64}
                with zipfile.ZipFile(archive,'w') as z:
                    z.writestr('manifest.json',json.dumps(manifest));z.writestr('xydesk-host.exe',engine)
                with self.assertRaisesRegex(ValueError,'source SHA' if wrong_source else 'Engine berubah'):
                    builder.prepare(archive,root/'work','b'*40,hashlib.sha256(archive.read_bytes()).hexdigest())

    def test_valid_payload_binds_source_and_both_hashes(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);archive=root/'payload.zip';engine=b'MZfixture';sha='a'*40
            digest=hashlib.sha256(engine).hexdigest()
            manifest={'version':'6.8.5','target':'x86_64-pc-windows-msvc','sourceSha':sha,'sha256':digest}
            with zipfile.ZipFile(archive,'w') as z:
                z.writestr('manifest.json',json.dumps(manifest));z.writestr('xydesk-host.exe',engine)
            archive_hash=hashlib.sha256(archive.read_bytes()).hexdigest()
            payload,generated=builder.prepare(archive,root/'work',sha,archive_hash)
            evidence=json.loads((payload/'installer-source.json').read_text())
            self.assertEqual(evidence['engineSha256'],digest);self.assertEqual(evidence['payloadZipSha256'],archive_hash)
            self.assertEqual(evidence['engineSourceSha'],sha);self.assertTrue((generated/'install-files.nsh').exists())

    def test_launcher_hash_does_not_require_get_filehash_cmdlet(self):
        source = Path(__file__).parents[1].joinpath('manual-host/Start-TestHost.ps1').read_text()
        commands = '\n'.join(line for line in source.splitlines() if not line.lstrip().startswith('#'))
        self.assertNotIn('Get-FileHash', commands)
        self.assertIn('[Security.Cryptography.SHA256]::Create()', commands)
        self.assertIn('ComputeHash($bytes)', commands)

    def test_installer_has_no_recursive_delete_or_auto_start(self):
        source = Path(__file__).with_name('host-test.nsi').read_text()
        commands = '\n'.join(line for line in source.splitlines() if not line.lstrip().startswith(';'))
        self.assertNotIn('RMDir /r', commands)
        self.assertNotIn('ExecWait', commands)
        self.assertEqual(commands.count('ExecShell'), 1)
        self.assertIn('ExecShell "runas"', commands.split('Function SetupVirtualDisplay')[1])
        self.assertNotIn('ExecShell', commands.split('Function SetupVirtualDisplay')[0])
        self.assertNotIn('Exec ', commands)
        self.assertNotIn('DeleteRegKey HKLM', commands)
        self.assertIn('RequestExecutionLevel user', commands)
        self.assertIn('MUI_PAGE_FINISH', commands)


if __name__ == '__main__':
    unittest.main()
