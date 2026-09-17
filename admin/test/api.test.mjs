import test, { afterEach } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import ts from 'typescript'

const source = readFileSync(new URL('../src/api.ts', import.meta.url), 'utf8')
const { outputText } = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } })
const api = await import(`data:text/javascript;base64,${Buffer.from(outputText).toString('base64')}`)
const originalFetch = globalThis.fetch
const storage = new Map()
globalThis.localStorage = { getItem: key => storage.get(key) ?? null, setItem: (key,value) => storage.set(key,value), removeItem: key => storage.delete(key) }
afterEach(() => { globalThis.fetch = originalFetch; storage.clear() })

test('statistik: nilai API nol tetap nol tanpa substitusi', async () => {
  const stats = { totalUsers: 0, mau: 0, guest: 0, onlineDevices: 0, totalDevices: 0, activeSessions: 0, todaySessions: 0, revenue: 0, revenueSubs: 0 }
  api.setAdminToken('test-token')
  globalThis.fetch = async (url, init) => {
    assert.equal(url, 'https://signal.xydesk.my.id/admin/stats')
    assert.equal(init.headers.authorization, 'Bearer test-token')
    return Response.json(stats)
  }
  assert.deepEqual(await api.fetchStats(), stats)
})
for (const [name, fn] of [['statistik',api.fetchStats], ['maintenance',api.fetchMaintenance], ['log',api.fetchLogs]]) {
  test(`${name}: HTTP 503 tidak menjadi data sukses`, async () => {
    globalThis.fetch = async () => new Response('', { status:503 })
    await assert.rejects(fn, /503/)
  })
  test(`${name}: kegagalan jaringan diteruskan`, async () => {
    globalThis.fetch = async () => { throw new Error('offline') }
    await assert.rejects(fn, /offline/)
  })
  test(`${name}: 401 menghapus token tanpa fallback`, async () => {
    api.setAdminToken('expired')
    globalThis.fetch = async () => new Response('', { status:401 })
    await assert.rejects(fn, /Sesi admin habis/)
    assert.equal(api.getAdminToken(), null)
  })
}
test('maintenance: payload simpan memakai layanan dan pesan yang dipilih', async () => {
  globalThis.fetch = async (url, init) => {
    assert.equal(url, 'https://signal.xydesk.my.id/admin/maintenance')
    assert.equal(init.method, 'POST')
    assert.deepEqual(JSON.parse(init.body), { service:'signal', enabled:false, message:'Kembali normal' })
    return Response.json({ ok:true })
  }
  assert.equal(await api.setMaintenance('signal',false,'Kembali normal'),true)
})
test('maintenance: simpan gagal tidak dianggap berhasil', async () => {
  globalThis.fetch = async () => new Response('gagal menyimpan', { status:500 })
  await assert.rejects(() => api.setMaintenance('web',true,'Perawatan'), /gagal menyimpan/)
})

test('maintenance batch menyertakan revision dalam satu request', async () => {
  let calls=0
  globalThis.fetch=async (_url,init)=>{
    calls++
    assert.deepEqual(JSON.parse(init.body),{services:{web:true,desktop:false,android:false,signal:true},message:'Perawatan',revision:7})
    return Response.json({ok:true})
  }
  await api.saveMaintenance({web:true,desktop:false,android:false,signal:true,message:'',revision:7},'Perawatan')
  assert.equal(calls,1)
})
test('konflik revision meminta muat ulang', async () => {
  globalThis.fetch=async()=>Response.json({error:'maintenance-conflict'},{status:409})
  await assert.rejects(()=>api.saveMaintenance({web:false,desktop:false,android:false,signal:false,message:'',revision:1},''),/admin lain/)
})
test('health gagal tidak menjadi status sehat',async()=>{
  globalThis.fetch=async()=>new Response('',{status:503})
  await assert.rejects(api.fetchHealth,/503/)
})
