// Token lama tanpa versi tetap berlaku hanya pada akun generasi nol.
export function memberClaims(payload) {
  return !!payload && typeof payload.sub === 'string' && !!payload.sub
    && typeof payload.email === 'string' && !!payload.email
    && payload.guest !== true && payload.role === undefined
    && (payload.aud === undefined || payload.aud === 'xydesk-account')
    && Number.isSafeInteger(payload.ver === undefined ? 0 : payload.ver)
    && (payload.ver === undefined ? 0 : payload.ver) >= 0;
}
export function memberMatches(payload, user) {
  const version = user?.token_version ?? 0;
  return memberClaims(payload) && !!user && !user.banned
    && user.id === payload.sub && user.email === payload.email
    && Number.isSafeInteger(version) && version >= 0
    && version === (payload.ver === undefined ? 0 : payload.ver);
}
export function sameMember(current, previous) {
  return memberMatches({sub:previous.id,email:previous.email,ver:previous.token_version ?? 0},current);
}
export function guestClaims(payload) {
  return !!payload && payload.guest === true
    && typeof payload.sub === 'string' && payload.sub.startsWith('guest:') && payload.sub.length > 6
    && payload.email === undefined && payload.role === undefined
    && (payload.aud === undefined || payload.aud === 'xydesk-guest');
}
export function accountClaims(user) {
  return {sub:user.id,email:user.email,ver:user.token_version ?? 0,aud:'xydesk-account'};
}
