const base = Deno.env.get('SUPABASE_URL')!;
const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
export const headers = { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
export async function db(path: string, method = 'GET', body?: unknown) {
  const response = await fetch(`${base}/rest/v1/${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  if (!response.ok) { const error = await response.json().catch(() => ({})); throw new Error(error.message ?? 'storage_unavailable'); }
  return response.status === 204 ? null : await response.json();
}
export const rpc = (name: string, args: unknown) => db(`rpc/${name}`, 'POST', args);
export async function identity(email: string) {
  const cryptoKey = await crypto.subtle.importKey('raw', new TextEncoder().encode(key), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const bytes = await crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(email.toLowerCase().trim()));
  return Array.from(new Uint8Array(bytes)).map(x => x.toString(16).padStart(2, '0')).join('');
}
export async function authenticate(request: Request) {
  const bearer = request.headers.get('Authorization');
  if (!bearer?.startsWith('Bearer ')) throw new Error('sign_in_required');
  const response = await fetch(`${base}/auth/v1/user`, { headers: { apikey: Deno.env.get('SUPABASE_ANON_KEY')!, Authorization: bearer } });
  if (!response.ok) throw new Error('sign_in_required');
  const user = await response.json();
  if (!user.email || !user.email_confirmed_at || user.is_anonymous) throw new Error('verified_email_required');
  let payload;
  try { payload = JSON.parse(atob(bearer.slice(7).split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))); } catch { throw new Error('sign_in_required'); }
  if (!payload.session_id || !await rpc('coach_session_valid', { p_user: user.id, p_session: payload.session_id })) throw new Error('sign_in_required');
  return user;
}
export async function removeAuthUser(id: string) {
  const response = await fetch(`${base}/auth/v1/admin/users/${encodeURIComponent(id)}`, { method: 'DELETE', headers });
  if (!response.ok) throw new Error('delete_unavailable');
}
