import test from 'node:test';
import assert from 'node:assert/strict';

import { signSignalToken, verifyToken } from '../src/worker.js';

const SECRET = 'signaling-role-binding-test-secret';

test('token signaling terikat ke ID dan role', async () => {
  const now = Math.floor(Date.now() / 1000);
  const token = await signSignalToken('client-123', 'client', SECRET, now);

  assert.equal(await verifyToken(token, 'client-123', 'client', SECRET), true);
  assert.equal(await verifyToken(token, 'victim-host', 'client', SECRET), false);
  assert.equal(await verifyToken(token, 'client-123', 'host', SECRET), false);
});

test('token signaling menolak timestamp lewat batas dan role asing', async () => {
  const old = Math.floor(Date.now() / 1000) - 301;
  const token = await signSignalToken('client-123', 'client', SECRET, old);

  assert.equal(await verifyToken(token, 'client-123', 'client', SECRET), false);
  assert.equal(await verifyToken(token, 'client-123', 'admin', SECRET), false);
});

test('token signaling menolak bentuk rusak, tamper, dan secret kosong', async () => {
  const now = Math.floor(Date.now() / 1000);
  const token = await signSignalToken('client-123', 'client', SECRET, now);
  const parts = token.split('.');

  // Bukan tiga bagian / timestamp bukan angka / timestamp rusak.
  assert.equal(await verifyToken('a.b', 'client-123', 'client', SECRET), false);
  assert.equal(await verifyToken('abc.def.ghi', 'client-123', 'client', SECRET), false);

  // Tanda tangan diubah di salah satu byte.
  const tampered = `${parts[0]}.${parts[1]}.${'0'.repeat(parts[2].length)}`;
  assert.equal(await verifyToken(tampered, 'client-123', 'client', SECRET), false);

  // Tanpa secret, tidak ada token yang sah.
  assert.equal(await verifyToken(token, 'client-123', 'client', ''), false);
});
