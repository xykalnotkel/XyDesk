import test from 'node:test';
import assert from 'node:assert/strict';

import { Hub } from '../src/hub.js';

test('arah relay hanya mengizinkan alur client-host yang sah', () => {
  const hub = new Hub({ getWebSockets: () => [] }, {});

  assert.equal(hub.relayAllowed('pair', 'client', 'host'), true);
  assert.equal(hub.relayAllowed('pair', 'client', 'client'), false);
  assert.equal(hub.relayAllowed('pair-response', 'host', 'client'), true);
  assert.equal(hub.relayAllowed('pair-response', 'client', 'host'), false);
  assert.equal(hub.relayAllowed('offer', 'client', 'host'), true);
  assert.equal(hub.relayAllowed('answer', 'host', 'client'), true);
  assert.equal(hub.relayAllowed('ice', 'host', 'client'), true);
  assert.equal(hub.relayAllowed('ice', 'client', 'client'), false);
});

test('bye dan ice sah dua arah, tetapi tidak pernah sesama role', () => {
  const hub = new Hub({ getWebSockets: () => [] }, {});

  assert.equal(hub.relayAllowed('bye', 'host', 'client'), true);
  assert.equal(hub.relayAllowed('bye', 'client', 'host'), true);
  assert.equal(hub.relayAllowed('bye', 'host', 'host'), false);
  assert.equal(hub.relayAllowed('bye', 'client', 'client'), false);

  assert.equal(hub.relayAllowed('ice', 'client', 'host'), true);
  assert.equal(hub.relayAllowed('ice', 'host', 'client'), true);
  assert.equal(hub.relayAllowed('ice', 'host', 'host'), false);
  assert.equal(hub.relayAllowed('ice', 'client', 'client'), false);
});
