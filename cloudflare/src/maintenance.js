export const services = ['web','desktop','android','signal'];
export const emptyMaintenance = () => ({ web:false, desktop:false, android:false, signal:false, message:'', revision:0 });
export function validMaintenancePatch(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return false;
  if (body.message !== undefined && (typeof body.message !== 'string' || body.message.length > 2000)) return false;
  if (body.revision !== undefined && (!Number.isSafeInteger(body.revision) || body.revision < 0)) return false;
  if (body.services) return typeof body.message === 'string' && services.every(k=>typeof body.services[k] === 'boolean') && Object.keys(body.services).every(k=>services.includes(k));
  return services.includes(body.service) && typeof body.enabled === 'boolean';
}
