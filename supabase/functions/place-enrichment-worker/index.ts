import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createPlaceEnrichmentWorker, EnrichmentError, type EnrichmentResult, type EnrichmentRequest, type PlaceImage } from "../_shared/place_enrichment.ts";
import { createDistributedPhotoCache, publicPhotoCacheKey, type PublicPhotoIdentity } from "../_shared/place_photo_cache.ts";
import type { WikimediaRequestLimiter } from "../_shared/wikimedia_photos.ts";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const edgeRuntime = (globalThis as typeof globalThis & { EdgeRuntime?: { waitUntil: (promise: Promise<unknown>) => void } }).EdgeRuntime;
async function rpc(name: string, args: Record<string, unknown>) {
  const result = await admin.rpc(name, args);
  if (result.error) throw new Error(name);
  return result.data;
}
const worker = createPlaceEnrichmentWorker({
  verifyToken: async token => Boolean(await rpc("place_enrichment_verify_worker_token", { p_token: token })),
  claim: async limit => await rpc("place_enrichment_claim", { p_limit: limit }) ?? [],
  reserveGoogle: async job => await rpc("place_enrichment_reserve_google", { p_job_id: job.job_id, p_lease_token: job.lease_token }) ?? { ok: false, code: "quota_unavailable" },
  cacheWikimedia: async (job, input: EnrichmentRequest, identity: PublicPhotoIdentity | null, load: () => Promise<PlaceImage[]>) => {
    const cacheKey = identity ? await publicPhotoCacheKey(identity) : null;
    const reserve = async () => {
      const result = await rpc("place_photo_reserve_run", { p_resolution_id: job.job_id, p_user_id: job.user_id, p_trip_id: job.trip_id ?? input.trip_id, p_cache_key: cacheKey, p_manual: false });
      if (!result?.ok) throw new EnrichmentError(String(result?.code ?? "photo_quota"), "Bildquelle ist vorübergehend begrenzt", 429, Number(result?.retry_after_seconds) || 60);
    };
    if (!cacheKey) { await reserve(); return await load(); }
    const cache = createDistributedPhotoCache<PlaceImage>({
      claim: async (key, token) => await rpc("place_photo_cache_claim", { p_cache_key: key, p_identity_protocol: identity!.protocol, p_pipeline_version: 1, p_lease_token: token }),
      complete: async (key, token, payload) => { const now = new Date(); const hasPhoto = payload.length > 0; await rpc("place_photo_cache_complete", { p_cache_key: key, p_lease_token: token, p_payload: payload, p_fetched_at: now.toISOString(), p_expires_at: new Date(now.getTime() + (hasPhoto ? 30 : 7) * 86400000).toISOString(), p_stale_until: new Date(now.getTime() + 90 * 86400000).toISOString() }); },
      release: async (key, token) => { await rpc("place_photo_cache_release", { p_cache_key: key, p_lease_token: token }); },
    });
    return await cache(cacheKey, async () => { await reserve(); return await load(); });
  },
  wikimediaLimiter: job => ({
    run: async <T>(work: () => Promise<T>) => {
      const result = await rpc("place_photo_reserve_upstream", { p_resolution_id: job.job_id, p_provider: "wikimedia" });
      if (!result?.ok) throw new EnrichmentError(String(result?.code ?? "photo_upstream_quota"), "Bildquelle ist vorübergehend begrenzt", 429, Number(result?.retry_after_seconds) || 60);
      try { return await work(); }
      finally { await rpc("place_photo_release_upstream", { p_resolution_id: job.job_id, p_sequence: result.sequence }); }
    },
  } satisfies WikimediaRequestLimiter),
  defer: async (job, seconds, code) => { await rpc("place_enrichment_defer", { p_job_id: job.job_id, p_lease_token: job.lease_token, p_delay_seconds: seconds, p_error_code: code }); },
  complete: async (job, result: EnrichmentResult, status = "ready") => {
    await rpc("place_enrichment_complete", { p_job_id: job.job_id, p_lease_token: job.lease_token, p_result: result, p_status: status });
  },
  fail: async (job, code, retryable) => { await rpc("place_enrichment_fail", { p_job_id: job.job_id, p_lease_token: job.lease_token, p_error_code: code, p_retryable: retryable }); },
  googleKey: () => Deno.env.get("GOOGLE_PLACES_API_KEY"),
  ...(edgeRuntime ? { waitUntil: (promise: Promise<unknown>) => edgeRuntime.waitUntil(promise.catch(() => console.error("Place enrichment background batch failed"))) } : {}),
});
Deno.serve(worker);
