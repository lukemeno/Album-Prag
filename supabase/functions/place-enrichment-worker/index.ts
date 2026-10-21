import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createPlaceEnrichmentWorker, type EnrichmentResult } from "../_shared/place_enrichment.ts";

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
  defer: async (job, seconds, code) => { await rpc("place_enrichment_defer", { p_job_id: job.job_id, p_lease_token: job.lease_token, p_delay_seconds: seconds, p_error_code: code }); },
  complete: async (job, result: EnrichmentResult, status = "ready") => {
    await rpc("place_enrichment_complete", { p_job_id: job.job_id, p_lease_token: job.lease_token, p_result: result, p_status: status });
  },
  fail: async (job, code, retryable) => { await rpc("place_enrichment_fail", { p_job_id: job.job_id, p_lease_token: job.lease_token, p_error_code: code, p_retryable: retryable }); },
  googleKey: () => Deno.env.get("GOOGLE_PLACES_API_KEY"),
  ...(edgeRuntime ? { waitUntil: (promise: Promise<unknown>) => edgeRuntime.waitUntil(promise.catch(() => console.error("Place enrichment background batch failed"))) } : {}),
});
Deno.serve(worker);
