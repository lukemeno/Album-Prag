export const MAX_BODY_BYTES = 80_000;
export const MAX_MESSAGE_CHARS = 4_000;
export const MAX_HISTORY_ITEMS = 12;
export const MAX_HISTORY_CHARS = 16_000;
export const MAX_CONTEXT_CHARS = 40_000;
export const MAX_DOCUMENTS = 5;
export const MAX_DOCUMENT_EXCERPT_CHARS = 1_500;
export const MAX_COLLECTION_ITEMS = 100;
export const MAX_PLACES = 150;
export const MAX_PREFERENCES = 30;
export const MAX_PREFERENCE_CHARS = 200;

export type AssistantRole = "user" | "assistant";

export type AssistantHistoryItem = { role: AssistantRole; text: string };

export type AssistantContextPlace = {
  id: string;
  title: string;
  note: string;
  category: string;
  address: string;
  lat: number | null;
  lng: number | null;
  day: number | null;
  franked: boolean;
  opening_hours: string;
};

export type AssistantContextDocument = { id: string; name: string; text: string };
export type AssistantContextCollection = { id: string; text: string; url: string | null };

export type AssistantRequest = {
  request_id: string;
  trip_id: string | null;
  message: string;
  history: AssistantHistoryItem[];
  context: {
    trip: Record<string, unknown>;
    places: AssistantContextPlace[];
    documents: AssistantContextDocument[];
    collection: AssistantContextCollection[];
  };
  preferences: string[];
  location: { latitude: number; longitude: number } | null;
  web_search: boolean;
};

export type AssistantReply = {
  answer: string;
  sources: Array<{
    title: string;
    url: string | null;
    document_id: string | null;
    quote: string | null;
  }>;
  places: Array<{
    existing_id: string | null;
    title: string;
    address: string;
    query: string;
    source_url: string | null;
  }>;
  plan: Array<{ day: number; place_ids: string[]; note: string }>;
  preferences: string[];
  usage?: { used_usd: number; limit_usd: number; remaining_requests: number };
};

export type ActualWebSource = { title: string; url: string };

export class AssistantValidationError extends Error {
  code: string;
  status: number;
  constructor(message: string, code = "invalid_request", status = 400) {
    super(message);
    this.name = "AssistantValidationError";
    this.code = code;
    this.status = status;
  }
}

function objectValue(value: unknown, field: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new AssistantValidationError(`Ungültiges Feld: ${field}`);
  }
  return value as Record<string, unknown>;
}

function stringValue(value: unknown, field: string, max: number, required = true): string {
  if (typeof value !== "string" || (required && value.trim().length === 0) || value.length > max) {
    throw new AssistantValidationError(`Ungültiges Feld: ${field}`);
  }
  return value;
}

function nullableString(value: unknown, field: string, max: number): string | null {
  if (value === null || value === undefined) return null;
  return stringValue(value, field, max);
}

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

/** Accepts the UI's bounded excerpt format, which joins several exact snippets with an ellipsis. */
export function excerptMatchesDocument(documentText: string, excerpt: string): boolean {
  if (!excerpt) return true;
  const snippets = excerpt.split(/\s*…\s*/u).map((part) => part.trim()).filter(Boolean);
  let from = 0;
  for (const snippet of snippets) {
    const at = documentText.indexOf(snippet, from);
    if (at < 0) return false;
    from = at + snippet.length;
  }
  return snippets.length > 0;
}

function finiteNumber(value: unknown, field: string, min: number, max: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    throw new AssistantValidationError(`Ungültiges Feld: ${field}`);
  }
  return value;
}

function optionalCoordinate(value: unknown, field: string, min: number, max: number): number | null {
  if (value === null || value === undefined) return null;
  return finiteNumber(value, field, min, max);
}

function jsonSize(value: unknown): number {
  try {
    return new TextEncoder().encode(JSON.stringify(value)).byteLength;
  } catch {
    throw new AssistantValidationError("Ungültiger Kontext");
  }
}

export function parseAssistantRequest(value: unknown): AssistantRequest {
  const body = objectValue(value, "body");
  if (!isUuid(body.request_id)) throw new AssistantValidationError("Ungültige Anfrage-ID");
  if (body.trip_id !== null && body.trip_id !== undefined && !isUuid(body.trip_id)) {
    throw new AssistantValidationError("Ungültige Reise-ID");
  }
  const message = stringValue(body.message, "message", MAX_MESSAGE_CHARS);

  if (!Array.isArray(body.history) || body.history.length > MAX_HISTORY_ITEMS) {
    throw new AssistantValidationError("Zu viel Nachrichtenverlauf");
  }
  let historyChars = 0;
  const history = body.history.map((item, index) => {
    const row = objectValue(item, `history[${index}]`);
    if (row.role !== "user" && row.role !== "assistant") {
      throw new AssistantValidationError(`Ungültige Rolle: history[${index}]`);
    }
    const text = stringValue(row.text, `history[${index}].text`, MAX_MESSAGE_CHARS);
    historyChars += text.length;
    return { role: row.role, text } as AssistantHistoryItem;
  });
  if (historyChars > MAX_HISTORY_CHARS) throw new AssistantValidationError("Zu viel Nachrichtenverlauf");

  const contextInput = objectValue(body.context, "context");
  const tripValue = objectValue(contextInput.trip, "context.trip");
  if (!Array.isArray(contextInput.places) || contextInput.places.length > MAX_PLACES) {
    throw new AssistantValidationError("Ungültige Orte");
  }
  const places = contextInput.places.map((item, index) => {
    const row = objectValue(item, `context.places[${index}]`);
    const id = stringValue(row.id, `context.places[${index}].id`, 200);
    return {
      id,
      title: stringValue(row.title ?? "", `context.places[${index}].title`, 500, false),
      note: stringValue(row.note ?? "", `context.places[${index}].note`, 1_000, false),
      category: stringValue(row.category ?? "", `context.places[${index}].category`, 200, false),
      address: stringValue(row.address ?? "", `context.places[${index}].address`, 500, false),
      lat: optionalCoordinate(row.lat, `context.places[${index}].lat`, -90, 90),
      lng: optionalCoordinate(row.lng, `context.places[${index}].lng`, -180, 180),
      day: row.day === null || row.day === undefined ? null : finiteNumber(row.day, `context.places[${index}].day`, 1, 31),
      franked: row.franked === undefined ? false : row.franked === true,
      opening_hours: stringValue(row.opening_hours ?? "", `context.places[${index}].opening_hours`, 1_000, false),
    };
  });

  if (!Array.isArray(contextInput.documents) || contextInput.documents.length > MAX_DOCUMENTS) {
    throw new AssistantValidationError("Zu viele Dokumente");
  }
  const documents = contextInput.documents.map((item, index) => {
    const row = objectValue(item, `context.documents[${index}]`);
    return {
      id: stringValue(row.id, `context.documents[${index}].id`, 200),
      name: stringValue(row.name, `context.documents[${index}].name`, 500),
      text: stringValue(row.text ?? "", `context.documents[${index}].text`, MAX_DOCUMENT_EXCERPT_CHARS, false),
    };
  });

  if (!Array.isArray(contextInput.collection) || contextInput.collection.length > MAX_COLLECTION_ITEMS) {
    throw new AssistantValidationError("Zu viele Sammlungseinträge");
  }
  const collection = contextInput.collection.map((item, index) => {
    const row = objectValue(item, `context.collection[${index}]`);
    return {
      id: stringValue(row.id, `context.collection[${index}].id`, 200),
      text: stringValue(row.text, `context.collection[${index}].text`, 1_000),
      url: nullableString(row.url, `context.collection[${index}].url`, 2_000),
    };
  });
  const context = { trip: tripValue, places, documents, collection };
  if (jsonSize(context) > MAX_CONTEXT_CHARS) throw new AssistantValidationError("Kontext ist zu groß");

  if (!Array.isArray(body.preferences) || body.preferences.length > MAX_PREFERENCES) {
    throw new AssistantValidationError("Ungültige Vorlieben");
  }
  const preferences = body.preferences.map((item, index) => stringValue(item, `preferences[${index}]`, MAX_PREFERENCE_CHARS));
  let location: AssistantRequest["location"] = null;
  if (body.location !== null && body.location !== undefined) {
    const row = objectValue(body.location, "location");
    location = {
      latitude: finiteNumber(row.latitude, "location.latitude", -90, 90),
      longitude: finiteNumber(row.longitude, "location.longitude", -180, 180),
    };
  }
  if (typeof body.web_search !== "boolean") throw new AssistantValidationError("Ungültige Websuche");
  return {
    request_id: body.request_id,
    trip_id: (body.trip_id as string | null | undefined) ?? null,
    message,
    history,
    context,
    preferences,
    location,
    web_search: body.web_search,
  };
}

export const ASSISTANT_RESPONSE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    answer: { type: "string" },
    sources: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          title: { type: "string" },
          url: { type: ["string", "null"] },
          document_id: { type: ["string", "null"] },
          quote: { type: ["string", "null"] },
        },
        required: ["title", "url", "document_id", "quote"],
      },
    },
    places: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          existing_id: { type: ["string", "null"] },
          title: { type: "string" },
          address: { type: "string" },
          query: { type: "string" },
          source_url: { type: ["string", "null"] },
        },
        required: ["existing_id", "title", "address", "query", "source_url"],
      },
    },
    plan: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          day: { type: "integer", minimum: 4, maximum: 9 },
          place_ids: { type: "array", items: { type: "string" } },
          note: { type: "string" },
        },
        required: ["day", "place_ids", "note"],
      },
    },
    preferences: { type: "array", items: { type: "string" } },
    usage: {
      type: "object",
      additionalProperties: false,
      properties: {
        used_usd: { type: "number" },
        limit_usd: { type: "number" },
        remaining_requests: { type: "integer" },
      },
      required: ["used_usd", "limit_usd", "remaining_requests"],
    },
  },
  required: ["answer", "sources", "places", "plan", "preferences", "usage"],
} as const;

function outputString(value: unknown, field: string, max: number, required = true): string {
  return stringValue(value, field, max, required);
}

function outputNullableString(value: unknown, field: string, max: number): string | null {
  return nullableString(value, field, max);
}

export function sanitizeAssistantReply(value: unknown, request: AssistantRequest, actualWebSources: ActualWebSource[] = []): AssistantReply {
  const body = objectValue(value, "reply");
  const placeIds = new Set(request.context.places.map((place) => place.id));
  const documents = new Map(request.context.documents.map((document) => [document.id, document]));
  const webSources = new Map(actualWebSources.map((source) => [source.url, source]));
  const answer = outputString(body.answer, "answer", 12_000);
  if (!Array.isArray(body.sources) || body.sources.length > 30) throw new AssistantValidationError("Ungültige Quellen", "provider_invalid", 502);
  const sources = body.sources.map((item, index) => {
    const row = objectValue(item, `sources[${index}]`);
    const title = outputString(row.title, `sources[${index}].title`, 500);
    const url = outputNullableString(row.url, `sources[${index}].url`, 2_000);
    const documentId = outputNullableString(row.document_id, `sources[${index}].document_id`, 200);
    const quote = outputNullableString(row.quote, `sources[${index}].quote`, MAX_DOCUMENT_EXCERPT_CHARS);
    if (documentId !== null) {
      const document = documents.get(documentId);
      if (!document || quote === null || quote.length === 0 || !excerptMatchesDocument(document.text, quote)) {
        throw new AssistantValidationError("Ungültiger Dokumentbeleg", "provider_invalid", 502);
      }
      if (url !== null) throw new AssistantValidationError("Ungültige Quelle", "provider_invalid", 502);
      return { title, url: null, document_id: documentId, quote };
    }
    if (quote !== null || url === null || !webSources.has(url)) {
      throw new AssistantValidationError("Ungültige Webquelle", "provider_invalid", 502);
    }
    const actual = webSources.get(url)!;
    return { title: actual.title || title, url: actual.url, document_id: null, quote: null };
  });

  if (!Array.isArray(body.places) || body.places.length > 30) throw new AssistantValidationError("Ungültige Ortsvorschläge", "provider_invalid", 502);
  const places = body.places.map((item, index) => {
    const row = objectValue(item, `places[${index}]`);
    const existingId = outputNullableString(row.existing_id, `places[${index}].existing_id`, 200);
    if (existingId !== null && !placeIds.has(existingId)) throw new AssistantValidationError("Unbekannter Ort", "provider_invalid", 502);
    const sourceURL = outputNullableString(row.source_url, `places[${index}].source_url`, 2_000);
    if (sourceURL !== null && !webSources.has(sourceURL)) throw new AssistantValidationError("Ungültige Ortsquelle", "provider_invalid", 502);
    return {
      existing_id: existingId,
      title: outputString(row.title, `places[${index}].title`, 500),
      address: outputString(row.address, `places[${index}].address`, 500, false),
      query: outputString(row.query, `places[${index}].query`, 500),
      source_url: sourceURL,
    };
  });

  if (!Array.isArray(body.plan) || body.plan.length > 30) throw new AssistantValidationError("Ungültiger Tagesplan", "provider_invalid", 502);
  const plan = body.plan.map((item, index) => {
    const row = objectValue(item, `plan[${index}]`);
    const day = finiteNumber(row.day, `plan[${index}].day`, 4, 9);
    if (!Number.isInteger(day)) throw new AssistantValidationError("Ungültiger Tag", "provider_invalid", 502);
    if (!Array.isArray(row.place_ids)) throw new AssistantValidationError("Ungültige Ortsliste", "provider_invalid", 502);
    const uniqueIds: string[] = [];
    for (const [placeIndex, id] of row.place_ids.entries()) {
      const placeId = outputString(id, `plan[${index}].place_ids[${placeIndex}]`, 200);
      if (!placeIds.has(placeId)) throw new AssistantValidationError("Unbekannter Ort im Plan", "provider_invalid", 502);
      if (!uniqueIds.includes(placeId)) uniqueIds.push(placeId);
    }
    return { day, place_ids: uniqueIds, note: outputString(row.note, `plan[${index}].note`, 1_000, false) };
  });
  if (!Array.isArray(body.preferences) || body.preferences.length > MAX_PREFERENCES) throw new AssistantValidationError("Ungültige Vorlieben", "provider_invalid", 502);
  const preferences = body.preferences.map((item, index) => outputString(item, `preferences[${index}]`, MAX_PREFERENCE_CHARS));
  return { answer, sources, places, plan, preferences };
}

export function extractResponseText(response: unknown): string {
  const body = response as Record<string, unknown>;
  if (typeof body.output_text === "string") return body.output_text;
  const output = Array.isArray(body.output) ? body.output : [];
  const chunks: string[] = [];
  for (const item of output) {
    if (!item || typeof item !== "object") continue;
    const content = (item as Record<string, unknown>).content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      if (part && typeof part === "object" && typeof (part as Record<string, unknown>).text === "string") {
        chunks.push((part as Record<string, unknown>).text as string);
      }
    }
  }
  return chunks.join("");
}

export function extractActualWebSources(response: unknown): ActualWebSource[] {
  const found: ActualWebSource[] = [];
  const seen = new Set<string>();
  const visit = (value: unknown, inWebSourceField = false): void => {
    if (!value || typeof value !== "object") return;
    if (Array.isArray(value)) {
      for (const item of value) visit(item, inWebSourceField);
      return;
    }
    const row = value as Record<string, unknown>;
    const type = typeof row.type === "string" ? row.type : "";
    const url = typeof row.url === "string" ? row.url : typeof row.href === "string" ? row.href : null;
    const title = typeof row.title === "string" ? row.title : "Webquelle";
    if ((type === "url_citation" || inWebSourceField) && url && /^https?:\/\//i.test(url)) {
      if (!seen.has(url)) {
        seen.add(url);
        found.push({ title, url });
      }
    }
    if (type === "web_search_call" && row.action && typeof row.action === "object") {
      const action = row.action as Record<string, unknown>;
      if (Array.isArray(action.sources)) visit(action.sources, true);
    }
    for (const [key, child] of Object.entries(row)) visit(child, inWebSourceField || key === "web_search_sources");
  };
  visit(response);
  return found;
}

export function countWebSearchCalls(response: unknown): number {
  let count = 0;
  const visit = (value: unknown): void => {
    if (!value || typeof value !== "object") return;
    if (Array.isArray(value)) return value.forEach(visit);
    const row = value as Record<string, unknown>;
    if (row.type === "web_search_call") count += 1;
    Object.values(row).forEach(visit);
  };
  visit(response);
  return Math.min(count, 2);
}

export function providerCostUsd(response: unknown): number | null {
  if (!response || typeof response !== "object") return null;
  const usage = (response as Record<string, unknown>).usage;
  if (!usage || typeof usage !== "object") return null;
  const row = usage as Record<string, unknown>;
  const input = typeof row.input_tokens === "number" ? row.input_tokens : 0;
  const output = typeof row.output_tokens === "number" ? row.output_tokens : 0;
  if (!Number.isFinite(input) || !Number.isFinite(output) || input < 0 || output < 0) return null;
  return input * 0.10 / 1_000_000 + output * 0.50 / 1_000_000 + countWebSearchCalls(response) * 0.01;
}
