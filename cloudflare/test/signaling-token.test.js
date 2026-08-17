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
