import { sameMember } from './member_session.js';
const MAX_ITEMS = 20;
const MAX_BODY = 48 * 1024;
const json = (data, status = 200) => new Response(JSON.stringify(data), {status, headers: {'content-type':'application/json','cache-control':'no-store'}});
const clean = (v, n) => typeof v === 'string' ? v.replace(/[\u0000-\u001f\u007f]/g, '').slice(0,n) : '';
const validId = id => typeof id === 'string' && /^[0-9a-f-]{36}$/.test(id);

export function normalizeHistory(value, now = Date.now()) {
  if (!value || !validId(value.id) || typeof value.deviceId !== 'string' || !/^\d{9}$/.test(value.deviceId)) throw Error('invalid-record');
  if (!['ended','interrupted','failed','cancelled'].includes(value.state)) throw Error('invalid-state');
  const start = Number(value.startedAt), end = Number(value.endedAt);
  if (!Number.isFinite(start) || !Number.isFinite(end) || start > end || start < now - 90*86400000 || end > now + 60000) throw Error('invalid-time');
  const specs = {};
  for (const k of ['hostname','os','cpu','gpu','ram','storage','motherboard']) {
    const s = clean(value.specs?.[k], 180); if(s) specs[k] = s;
  }
  let preview = null;
  if (value.preview) {
    if (value.previewConsent !== true || typeof value.preview !== 'string' || value.preview.length > 32768 || !/^data:image\/jpeg;base64,[A-Za-z0-9+/]+={0,2}$/.test(value.preview)) throw Error('invalid-preview');
    const bytes = atob(value.preview.slice(23));
    if (!bytes.startsWith('\xff\xd8') || !bytes.endsWith('\xff\xd9')) throw Error('invalid-preview');
    preview = value.preview;
  }
  return {id:value.id, deviceId:value.deviceId, name:clean(value.name,80) || `PC ${value.deviceId}`, startedAt:start, endedAt:end, state:value.state, specs, preview, savedAt:now};
}

export async function historyEndpoint(request, storage, user) {
  if (!user || user.banned) return json({error:'unauthorized'},401);
  const prefix = `history:${user.id}:`, indexKey = prefix+'index';
  if (request.method === 'GET') {
    const ids = await storage.get(indexKey) || [];
    const items = await Promise.all(ids.map(id=>storage.get(prefix+id)));
    return json({items:items.filter(Boolean).sort((a,b)=>b.endedAt-a.endedAt), limit:MAX_ITEMS});
  }
  if (request.method !== 'POST') return json({error:'method-not-allowed'},405);
  // Baca streaming dengan batas, jangan percaya Content-Length dari client.
  const reader = request.body?.getReader(); let chunks=[], size=0;
  if(!reader) return json({error:'bad-json'},400);
  while(true){const {value,done}=await reader.read();if(done)break;size+=value.length;if(size>MAX_BODY){await reader.cancel();return json({error:'body-too-large'},413);}chunks.push(value);}
  let body;
  try {const bytes=new Uint8Array(size);let i=0;for(const c of chunks){bytes.set(c,i);i+=c.length;}body=JSON.parse(new TextDecoder().decode(bytes));}catch{return json({error:'bad-json'},400);}
  if(!body || !['save','delete','clear'].includes(body.action))return json({error:'invalid-action'},400);
  let record;
  try {if(body.action==='save')record=normalizeHistory(body.record);if(body.action==='delete'&&!validId(body.id))throw Error('invalid-id');}catch(e){return json({error:e.message},400);}
  const result = await storage.transaction(async tx=>{
    const current=await tx.get(`user:${user.email}`);
    if(!sameMember(current,user))return {unauthorized:true};
    const now=Date.now(), rateKey=prefix+'rate';let rate=await tx.get(rateKey);
    if(!rate||now-rate.at>60000)rate={at:now,n:0};
    if(rate.n>=40)return {limited:true};rate.n++;await tx.put(rateKey,rate);
    let ids=await tx.get(indexKey)||[];
    if(body.action==='clear'){for(const id of ids)await tx.delete(prefix+id);ids=[];}
    else if(body.action==='delete'){await tx.delete(prefix+body.id);ids=ids.filter(id=>id!==body.id);}
    else {
      await tx.put(prefix+record.id,record);ids=[record.id,...ids.filter(id=>id!==record.id)];
      for(const id of ids.slice(MAX_ITEMS))await tx.delete(prefix+id);ids=ids.slice(0,MAX_ITEMS);
    }
    await tx.put(indexKey,ids);return {ok:true};
  });
  return result.unauthorized ? json({error:'unauthorized'},401) : result.limited ? json({error:'rate-limited'},429) : json(result);
}

export async function deleteUserHistory(storage, userId, email, version = 0) {
  const prefix=`history:${userId}:`;
  return storage.transaction(async tx=>{if(email){const current=await tx.get(`user:${email}`);if(!sameMember(current,{id:userId,email,token_version:version}))return false;}const ids=await tx.get(prefix+'index')||[];for(const id of ids)await tx.delete(prefix+id);await tx.delete(prefix+'index');await tx.delete(prefix+'rate');if(email){await tx.delete(`user:${email}`);await tx.delete(`otp:${email}`);}return true;});
}
