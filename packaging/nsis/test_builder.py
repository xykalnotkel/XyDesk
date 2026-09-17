import importlib.util
from pathlib import Path
import tempfile
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
        self.assertNotIn('ExecShell', commands)
        self.assertNotIn('Exec ', commands)
        self.assertNotIn('DeleteRegKey HKLM', commands)
        self.assertIn('RequestExecutionLevel user', commands)
        self.assertIn('MUI_PAGE_FINISH', commands)


if __name__ == '__main__':
    unittest.main()
