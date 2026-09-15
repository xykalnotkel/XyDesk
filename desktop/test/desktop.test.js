import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));

test('desktop shell memakai Tauri dan bukan Electron', () => {
  assert.equal(packageJson.main, undefined);
  assert.equal(packageJson.devDependencies?.electron, undefined);
  assert.equal(packageJson.devDependencies?.['electron-builder'], undefined);
  assert.match(packageJson.description, /Tauri/);
  assert.ok(fs.existsSync(path.join(root, 'src-tauri', 'tauri.conf.json')));
  assert.equal(fs.existsSync(path.join(root, 'electron')), false);
});
