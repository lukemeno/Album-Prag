import { clients, jsonHeaders } from "../_shared/album.ts";
import { assistantSystemPrompt, assistantUserPrompt } from "../_shared/assistant_prompt.ts";
import { AssistantMembershipError, verifyAssistantTripContext } from "../_shared/assistant_membership.ts";
import {
  ASSISTANT_RESPONSE_SCHEMA,
  AssistantValidationError,
  excerptMatchesDocument,
  extractActualWebSources,
  extractResponseText,
  parseAssistantRequest,
  providerCostUsd,
  sanitizeAssistantReply,
  type AssistantRequest,
} from "../_shared/assistant_validation.ts";

const RESERVATION_USD = 0.05;
const MAX_BODY_BYTES = 80_000;
const PROVIDER_TIMEOUT_MS = 45_000;

class AssistantError extends Error {
  status: number;
  code: string;
  constructor(message: string, code: string, status: number) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function errorResponse(error: unknown): Response {
  if (error instanceof AssistantValidationError || error instanceof AssistantError || error instanceof AssistantMembershipError) {
    return new Response(JSON.stringify({ error: error.message, code: error.code }), {
      status: error.status,
      headers: jsonHeaders,
    });
  }
  if (error instanceof Response) {
    const status = error.status || 500;
    const code = status === 401 ? "unauthorized" : status === 403 ? "forbidden" : "request_error";
    return new Response(JSON.stringify({ error: status === 401 ? "Nicht angemeldet" : "Anfrage nicht zulässig.", code }), {
      status,
      headers: jsonHeaders,
    });
  }
  return new Response(JSON.stringify({ error: "Der Assistent ist vorübergehend nicht verfügbar.", code: "server_error" }), {
    status: 500,
    headers: jsonHeaders,
  });
}

function quotaError(code: string): AssistantError {
  if (code === "duplicate_request") return new AssistantError("Diese Anfrage wurde bereits verarbeitet.", code, 409);
  if (code === "rate_limit") return new AssistantError("Zu viele Anfragen in kurzer Zeit. Bitte später erneut versuchen.", code, 429);
  if (code === "monthly_limit" || code === "user_monthly_limit") {
    return new AssistantError("Das monatliche Assistentenlimit ist erreicht.", code, 429);
  }
  return new AssistantError("Der Assistent ist vorübergehend nicht verfügbar.", "quota_error", 503);
}

function quotaValues(value: unknown): { used_usd: number; limit_usd: number; remaining_requests: number } {
  if (!value || typeof value !== "object") throw new AssistantError("Nutzungsstatus nicht verfügbar.", "quota_error", 503);
  const row = value as Record<string, unknown>;
  const used = Number(row.used_usd);
  const limit = Number(row.limit_usd);
  const remaining = Number(row.remaining_requests);
  if (!Number.isFinite(used) || !Number.isFinite(limit) || !Number.isInteger(remaining)) {
    throw new AssistantError("Nutzungsstatus nicht verfügbar.", "quota_error", 503);
  }
  return { used_usd: Math.max(0, used), limit_usd: Math.max(0, limit), remaining_requests: Math.max(0, remaining) };
}

function providerRequestBody(request: AssistantRequest, model: string): Record<string, unknown> {
  const body: Record<string, unknown> = {
    model,
    input: [
      { role: "system", content: [{ type: "input_text", text: assistantSystemPrompt() }] },
      { role: "user", content: [{ type: "input_text", text: assistantUserPrompt(request) }] },
    ],
    reasoning: { effort: "low" },
    max_output_tokens: 2_000,
    store: false,
    text: {
      format: {
        type: "json_schema",
        name: "album_assistant_reply",
        strict: true,
        schema: ASSISTANT_RESPONSE_SCHEMA,
      },
    },
  };
  if (request.web_search) {
    body.tools = [{ type: "web_search" }];
    body.max_tool_calls = 2;
    body.include = ["web_search_call.action.sources"];
  }
  return body;
}

async function callProvider(request: AssistantRequest, requestSignal: AbortSignal): Promise<{ reply: ReturnType<typeof sanitizeAssistantReply>; raw: unknown }> {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) throw new AssistantError("Der Assistent ist nicht eingerichtet.", "provider_unavailable", 503);
  const model = Deno.env.get("OPENAI_MODEL") || "gpt-6-luna";
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);
  const abortFromClient = () => controller.abort();
  requestSignal.addEventListener("abort", abortFromClient, { once: true });
  try {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify(providerRequestBody(request, model)),
      signal: controller.signal,
    });
    if (!response.ok) {
      if (response.status === 429) {
        let providerCode = "";
        try {
          const errorBody = await response.clone().json();
          providerCode = typeof errorBody?.error?.code === "string" ? errorBody.error.code : "";
        } catch {
          // Provider error bodies are intentionally not surfaced or logged.
        }
        if (providerCode === "credit_balance_exhausted" || providerCode === "insufficient_quota") {
          throw new AssistantError("Der Assistent ist derzeit wegen des Anbieterbudgets nicht verfügbar.", "billing_required", 503);
        }
      }
      throw new AssistantError("Der Assistent konnte die Anfrage nicht beantworten.", "provider_error", 502);
    }
    const raw = await response.json();
    const text = extractResponseText(raw);
    if (text.length === 0 || text.length > 50_000) throw new AssistantError("Ungültige Assistentenantwort.", "provider_invalid", 502);
    let decoded: unknown;
    try {
      decoded = JSON.parse(text);
    } catch {
      throw new AssistantError("Ungültige Assistentenantwort.", "provider_invalid", 502);
    }
    const reply = sanitizeAssistantReply(decoded, request, extractActualWebSources(raw));
    return { reply, raw };
  } catch (error) {
    if (error instanceof AssistantError) throw error;
    if (error instanceof AssistantValidationError) {
      console.warn(JSON.stringify({ event: "assistant_response_rejected", code: error.code, reason: error.message }));
      throw new AssistantError("Die Rechercheantwort konnte nicht zuverlässig geprüft werden. Bitte erneut versuchen.", "provider_invalid", 502);
    }
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new AssistantError("Die Anfrage hat zu lange gedauert.", "timeout", 504);
    }
    throw new AssistantError("Der Assistent konnte die Anfrage nicht beantworten.", "provider_error", 502);
  } finally {
    clearTimeout(timer);
    requestSignal.removeEventListener("abort", abortFromClient);
  }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response(null, { status: 405, headers: jsonHeaders });
  let admin: any;
  let requestData: AssistantRequest | null = null;
  let reserved = false;
  let requestId: string | null = null;
  try {
    const auth = await clients(request);
    admin = auth.admin;
    if (Number(request.headers.get("content-length") || 0) > MAX_BODY_BYTES) {
      throw new AssistantError("Die Anfrage ist zu groß.", "request_too_large", 413);
    }
    const bytes = new Uint8Array(await request.arrayBuffer());
    if (bytes.byteLength > MAX_BODY_BYTES) throw new AssistantError("Die Anfrage ist zu groß.", "request_too_large", 413);
    let parsed: unknown;
    try {
      parsed = JSON.parse(new TextDecoder().decode(bytes));
    } catch {
      throw new AssistantValidationError("Ungültiges JSON");
    }
    requestData = parseAssistantRequest(parsed);
    requestId = requestData.request_id;
    await verifyAssistantTripContext(admin, auth.user.id, requestData);

    const reservation = await admin.rpc("assistant_reserve_usage", {
      p_user_id: auth.user.id,
      p_request_id: requestData.request_id,
      p_reservation_usd: RESERVATION_USD,
    });
    if (reservation.error) throw new AssistantError("Nutzungsstatus nicht verfügbar.", "quota_error", 503);
    const reservationData = reservation.data as Record<string, unknown>;
    if (reservationData.ok !== true) throw quotaError(String(reservationData.code || "quota_error"));
    reserved = true;

    const provider = await callProvider(requestData, request.signal);
    const cost = providerCostUsd(provider.raw);
    if (cost === null) throw new AssistantError("Ungültige Nutzungsdaten des Anbieters.", "provider_invalid", 502);
    const reconciled = await admin.rpc("assistant_reconcile_usage", {
      p_request_id: requestData.request_id,
      p_succeeded: true,
      p_actual_usd: cost,
    });
    if (reconciled.error) throw new AssistantError("Nutzungsstatus nicht verfügbar.", "quota_error", 503);
    reserved = false;
    const usage = await admin.rpc("assistant_usage_status", { p_user_id: auth.user.id });
    if (usage.error) throw new AssistantError("Nutzungsstatus nicht verfügbar.", "quota_error", 503);
    provider.reply.usage = quotaValues(usage.data);
    return new Response(JSON.stringify(provider.reply), { headers: jsonHeaders });
  } catch (error) {
    if (reserved && admin && requestId) {
      await admin.rpc("assistant_reconcile_usage", { p_request_id: requestId, p_succeeded: false, p_actual_usd: null });
    }
    return errorResponse(error);
  }
});
