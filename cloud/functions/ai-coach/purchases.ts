import { rpc } from './db.ts';
const project = 'projf460fca3';
export async function purchaseConfig() {
  const products: string[] = await rpc('coach_enabled_products', {});
  return { products, available: products.length > 0 && Boolean(Deno.env.get('REVENUECAT_SECRET_KEY')) };
}
export async function syncPurchases(userID: string) {
  const config = await purchaseConfig();
  if (!config.available) return;
  for (const environment of environments()) await syncEnvironment(userID, environment, config.products);
}
// Sandbox purchases (TestFlight builds and App Review) are free test transactions. They are credited
// only while COACH_ALLOW_SANDBOX_PURCHASES is "true"; App Store customers cannot make them.
export function environments(): string[] {
  return Deno.env.get('COACH_ALLOW_SANDBOX_PURCHASES') === 'true' ? ['production', 'sandbox'] : ['production'];
}
type PurchasePage = { items?: { store?: string; environment?: string; product_id?: string; store_purchase_identifier?: string; status?: string }[]; next_page?: string | null };
async function syncEnvironment(userID: string, environment: string, products: string[]) {
  let next: string | null = `/v2/projects/${project}/customers/${encodeURIComponent(`coach_${userID}`)}/purchases?environment=${environment}&limit=100`;
  for (let page = 0; next && page < 20; page++) {
    if (!next.startsWith(`/v2/projects/${project}/customers/`)) throw new Error('purchase_verification_unavailable');
    const response: Response = await fetch(`https://api.revenuecat.com${next}`, {
      headers: { Authorization: `Bearer ${Deno.env.get('REVENUECAT_SECRET_KEY')}` }, signal: AbortSignal.timeout(15000)
    });
    if (response.status === 404) return;
    if (!response.ok) throw new Error('purchase_verification_unavailable');
    const result: PurchasePage = await response.json();
    for (const p of result.items ?? []) {
      if (p.store !== 'app_store' || p.environment !== environment || !p.product_id || !products.includes(p.product_id) || !p.store_purchase_identifier) continue;
      await rpc('coach_purchase', { p_user: userID, p_transaction: `app_store:${p.store_purchase_identifier}`, p_product: p.product_id, p_status: p.status });
    }
    next = result.next_page ?? null;
  }
  if (next) throw new Error('purchase_verification_unavailable');
}
