import {
  buildDiscoveryCatalog,
  DiscoveryError,
  makeCatalogResponse,
  parseDiscoveryRequest,
  searchDiscoveryCities,
  type CatalogResponse,
  type DiscoveryDeps,
} from "./discovery.ts";

export type DiscoveryCacheClaim = { state: "fresh" | "stale" | "busy" | "claimed"; payload?: CatalogResponse | null; retry_after_seconds?: number };
export type DiscoveryCacheStore = {
  claim(key: string, cityQID: string, language: string, token: string, now: string): Promise<DiscoveryCacheClaim>;
  complete(key: string, token: string, payload: CatalogResponse): Promise<boolean>;
  release(key: string, token: string, nextRefreshAt: string): Promise<boolean>;
  reserveRate(userID: string, action: string, limit: number, now: string): Promise<{ ok: boolean; retry_after_seconds?: number }>;
};

export async function handleDiscoveryRequest(body: unknown, userID: string, deps: DiscoveryDeps, cache: DiscoveryCacheStore, signal: AbortSignal, now = new Date()) {
  const request = parseDiscoveryRequest(body);
  const limit = request.action === "search_cities" ? 10 : 3;
  const reservation = await cache.reserveRate(userID, request.action, limit, now.toISOString());
  if (!reservation.ok) throw new DiscoveryError("rate_limited", "Discovery request limit reached", reservation.retry_after_seconds ?? 60);
  if (request.action === "search_cities") {
    const cities = await searchDiscoveryCities(request.query, request.language_code, deps, signal);
    return { protocol_version: 1, cities };
  }

  const key = `catalog-v1|${request.city_qid}|${request.language_code}`;
  const token = crypto.randomUUID();
  const claim = await cache.claim(key, request.city_qid, request.language_code, token, now.toISOString());
  if ((claim.state === "fresh" || claim.state === "stale") && claim.payload) return { ...claim.payload, cache_status: claim.state };
  if (claim.state === "busy") {
    if (claim.payload) return { ...claim.payload, cache_status: "stale" as const };
    throw new DiscoveryError("source_unavailable", "Catalog refresh is already running", claim.retry_after_seconds ?? 2);
  }
  if (claim.state !== "claimed") throw new DiscoveryError("source_unavailable", "Catalog cache unavailable", 2);

  try {
    const catalog = await buildDiscoveryCatalog(request.city_qid, request.language_code, deps, signal);
    const payload = makeCatalogResponse(catalog, now);
    if (!await cache.complete(key, token, payload)) throw new DiscoveryError("source_unavailable", "Catalog lease expired during refresh", 2);
    return payload;
  } catch (error) {
    await cache.release(key, token, new Date(now.getTime() + 60 * 60_000).toISOString()).catch(() => false);
    if (claim.payload) return { ...claim.payload, cache_status: "stale" as const };
    if (error instanceof DiscoveryError) throw error;
    throw new DiscoveryError("source_unavailable", "Discovery sources are unavailable", 30);
  }
}
