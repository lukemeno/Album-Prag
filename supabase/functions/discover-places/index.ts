import { clients, jsonHeaders, respond } from "../_shared/album.ts";
import { DiscoveryError, type CatalogResponse } from "../_shared/discovery.ts";
import { handleDiscoveryRequest, type DiscoveryCacheClaim, type DiscoveryCacheStore } from "../_shared/discovery_handler.ts";
import { createWikidataDiscoveryDeps } from "../_shared/discovery_source.ts";
function createCacheStore(admin: any): DiscoveryCacheStore {
  return {
    async claim(key, cityQID, language, token, now) {
      const { data, error } = await admin.rpc("discovery_cache_claim", { p_cache_key: key, p_catalog_version: 1, p_city_qid: cityQID, p_language_code: language, p_lease_token: token, p_now: now });
      if (error) throw error;
      return data as DiscoveryCacheClaim;
    },
    async complete(key, token, payload) {
      const { data, error } = await admin.rpc("discovery_cache_complete", { p_cache_key: key, p_lease_token: token, p_payload: payload, p_fetched_at: payload.fetched_at, p_expires_at: payload.expires_at, p_stale_until: payload.stale_until });
      if (error) throw error;
      return data === true;
    },
    async release(key, token, nextRefreshAt) {
      const { data, error } = await admin.rpc("discovery_cache_release", { p_cache_key: key, p_lease_token: token, p_next_refresh_at: nextRefreshAt });
      if (error) throw error;
      return data === true;
    },
    async reserveRate(userID, action, limit, now) {
      const { data, error } = await admin.rpc("discovery_rate_reserve", { p_user_id: userID, p_action: action, p_limit: limit, p_now: now });
      if (error) throw error;
      return data;
    },
  };
}

Deno.serve(async request => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  try {
    const { user, admin } = await clients(request);
    if (Deno.env.get("DISCOVERY_ENABLED")?.toLowerCase() !== "true") return jsonError("Discovery is disabled", "disabled", 503);
    const body = await request.json();
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(new DOMException("Discovery deadline exceeded", "TimeoutError")), 20_000);
    const abortRequest = () => controller.abort(request.signal.reason);
    request.signal.addEventListener("abort", abortRequest, { once: true });
    try {
      const result = await handleDiscoveryRequest(body, user.id, createWikidataDiscoveryDeps(), createCacheStore(admin), controller.signal);
      return json(result);
    } finally {
      clearTimeout(timeout); request.signal.removeEventListener("abort", abortRequest);
    }
  } catch (error) {
    if (error instanceof DiscoveryError) return jsonError(error.message, error.code, error.code === "invalid_request" ? 400 : error.code === "rate_limited" ? 429 : 503, error.retryAfterSeconds);
    return respond(error);
  }
});

function json(value: unknown) { return new Response(JSON.stringify(value), { headers: jsonHeaders }); }
function jsonError(error: string, code: DiscoveryError["code"], status: number, retry_after_seconds?: number) {
  return new Response(JSON.stringify({ error, code, ...(retry_after_seconds ? { retry_after_seconds } : {}) }), { status, headers: { ...jsonHeaders, ...(retry_after_seconds ? { "Retry-After": String(retry_after_seconds) } : {}) } });
}
