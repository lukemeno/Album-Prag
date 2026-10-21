import { choosePlace, type PlaceCandidate, validCoordinate } from "./place_photo.ts";
import { isUuid } from "./assistant_validation.ts";

export const GOOGLE_PLACES_FIELD_MASK =
  "places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.googleMapsUri";
export const GOOGLE_PLACES_ENDPOINT = "https://places.googleapis.com/v1/places:searchText";
export const GOOGLE_PLACES_TIMEOUT_MS = 10_000;

export type PlaceRatingRequest = {
  request_id: string;
  trip_id: string | null;
  title: string;
  address: string;
  latitude: number;
  longitude: number;
};

export type PlaceRating = {
  rating: number;
  user_rating_count: number;
  name: string;
  address: string;
  google_maps_uri: string;
};

export class PlaceRatingError extends Error {
  status: number;
  code: string;
  constructor(message: string, code: string, status: number) {
    super(message);
    this.name = "PlaceRatingError";
    this.code = code;
    this.status = status;
  }
}

export class PlaceRatingValidationError extends PlaceRatingError {
  constructor(message: string) { super(message, "invalid_request", 400); }
}

export class PlaceRatingProviderError extends PlaceRatingError {
  constructor(message = "Die Bewertungen sind vorübergehend nicht verfügbar.", code = "ratings_unavailable", status = 503) {
    super(message, code, status);
  }
}

function recordValue(value: unknown, field: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new PlaceRatingValidationError(`Ungültiges Feld: ${field}`);
  return value as Record<string, unknown>;
}

function requiredText(value: unknown, field: string, max: number): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > max) {
    throw new PlaceRatingValidationError(`Ungültiges Feld: ${field}`);
  }
  return value.trim();
}

function optionalText(value: unknown, field: string, max: number): string {
  if (typeof value !== "string" || value.length > max) throw new PlaceRatingValidationError(`Ungültiges Feld: ${field}`);
  return value.trim();
}

function coordinate(value: unknown, field: string, minimum: number, maximum: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < minimum || value > maximum) {
    throw new PlaceRatingValidationError(`Ungültiges Feld: ${field}`);
  }
  return value;
}

export function parsePlaceRatingRequest(value: unknown): PlaceRatingRequest {
  const body = recordValue(value, "body");
  if (!isUuid(body.request_id)) throw new PlaceRatingValidationError("Ungültige Anfrage-ID");
  if (body.trip_id !== null && body.trip_id !== undefined && !isUuid(body.trip_id)) {
    throw new PlaceRatingValidationError("Ungültige Reise-ID");
  }
  return {
    request_id: body.request_id,
    trip_id: body.trip_id == null ? null : body.trip_id,
    title: requiredText(body.title, "title", 500),
    address: optionalText(body.address, "address", 500),
    latitude: coordinate(body.latitude, "latitude", -90, 90),
    longitude: coordinate(body.longitude, "longitude", -180, 180),
  };
}

export function isAllowedGoogleMapsURL(value: unknown): value is string {
  if (typeof value !== "string" || value.length > 2_000) return false;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.username || url.password || url.port) return false;
    const host = url.hostname.toLowerCase();
    const googleDomains = new Set([
      "google.com", "www.google.com", "maps.google.com",
      "google.de", "www.google.de", "maps.google.de",
      "google.cz", "www.google.cz", "maps.google.cz",
      "google.co.uk", "www.google.co.uk", "maps.google.co.uk",
      "google.fr", "www.google.fr", "maps.google.fr",
      "google.at", "www.google.at", "maps.google.at",
      "google.ch", "www.google.ch", "maps.google.ch",
    ]);
    const isGoogleMapsHost = googleDomains.has(host);
    return isGoogleMapsHost && (host.startsWith("maps.google.") || url.pathname.toLowerCase().startsWith("/maps"));
  } catch {
    return false;
  }
}

function googleCandidate(value: unknown): PlaceCandidate | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const row = value as Record<string, unknown>;
  const displayName = row.displayName && typeof row.displayName === "object" ? row.displayName as Record<string, unknown> : null;
  const location = row.location && typeof row.location === "object" ? row.location as Record<string, unknown> : null;
  const id = typeof row.id === "string" ? row.id : "";
  const name = typeof displayName?.text === "string" ? displayName.text.trim() : "";
  const address = typeof row.formattedAddress === "string" ? row.formattedAddress.trim() : "";
  const rating = typeof row.rating === "number" ? row.rating : NaN;
  const count = typeof row.userRatingCount === "number" ? row.userRatingCount : NaN;
  const latitude = typeof location?.latitude === "number" ? location.latitude : NaN;
  const longitude = typeof location?.longitude === "number" ? location.longitude : NaN;
  const googleMapsURI = row.googleMapsUri;
  if (!id || !name || !address || !validCoordinate(latitude, longitude) || !Number.isFinite(rating) || rating < 1 || rating > 5 ||
      !Number.isInteger(count) || count < 1 || !isAllowedGoogleMapsURL(googleMapsURI)) return null;
  return { id, name, address, latitude, longitude, sourceURL: googleMapsURI, rating, userRatingCount: count } as PlaceCandidate & { rating: number; userRatingCount: number };
}

export function selectGooglePlace(payload: unknown, request: PlaceRatingRequest): PlaceRating | null {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return null;
  const placesValue = (payload as Record<string, unknown>).places;
  const places: unknown[] = Array.isArray(placesValue) ? placesValue : [];
  const candidates = places.map(googleCandidate).filter((candidate): candidate is PlaceCandidate & { rating: number; userRatingCount: number } => candidate !== null);
  const selected = choosePlace(candidates, request.title, request.latitude, request.longitude, request.address) as (PlaceCandidate & { rating: number; userRatingCount: number }) | undefined;
  if (!selected || !selected.sourceURL || !isAllowedGoogleMapsURL(selected.sourceURL)) return null;
  return {
    rating: selected.rating,
    user_rating_count: selected.userRatingCount,
    name: selected.name,
    address: selected.address ?? "",
    google_maps_uri: selected.sourceURL,
  };
}

export function googleSearchBody(request: PlaceRatingRequest): Record<string, unknown> {
  return {
    textQuery: request.address ? `${request.title}, ${request.address}` : request.title,
    maxResultCount: 5,
    locationBias: { circle: { center: { latitude: request.latitude, longitude: request.longitude }, radius: 500 } },
  };
}

export async function fetchGooglePlaceRating(
  request: PlaceRatingRequest,
  key: string,
  fetchImpl: typeof fetch = fetch,
  requestSignal?: AbortSignal,
): Promise<PlaceRating> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), GOOGLE_PLACES_TIMEOUT_MS);
  const abortFromClient = () => controller.abort();
  requestSignal?.addEventListener("abort", abortFromClient, { once: true });
  try {
    const response = await fetchImpl(GOOGLE_PLACES_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": key,
        "X-Goog-FieldMask": GOOGLE_PLACES_FIELD_MASK,
      },
      body: JSON.stringify(googleSearchBody(request)),
      signal: controller.signal,
    });
    if (!response.ok) throw new PlaceRatingProviderError();
    const selected = selectGooglePlace(await response.json(), request);
    if (!selected) throw new PlaceRatingProviderError();
    return selected;
  } catch (error) {
    if (error instanceof PlaceRatingError) throw error;
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new PlaceRatingProviderError("Die Bewertungssuche hat zu lange gedauert.", "ratings_timeout", 504);
    }
    throw new PlaceRatingProviderError();
  } finally {
    clearTimeout(timer);
    requestSignal?.removeEventListener("abort", abortFromClient);
  }
}

export type PlaceRatingAuth = { userId: string; admin: any };
export type PlaceRatingHandlerDependencies = {
  authenticate: (request: Request) => Promise<PlaceRatingAuth>;
  reserve: (admin: any, userId: string, requestId: string) => Promise<{ ok: boolean; code?: string }>;
  isTripMember: (admin: any, userId: string, tripId: string) => Promise<boolean>;
  getKey: () => string | undefined;
  fetchRating?: typeof fetchGooglePlaceRating;
};

function json(value: unknown, status = 200, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store", ...headers } });
}

function errorResponse(error: unknown): Response {
  if (error instanceof PlaceRatingError) return json({ error: error.message, code: error.code }, error.status);
  if (error instanceof Response) {
    const status = error.status || 500;
    return json({ error: status === 401 ? "Nicht angemeldet" : "Anfrage nicht zulässig.", code: status === 401 ? "unauthorized" : "request_error" }, status);
  }
  return json({ error: "Google-Bewertungen sind vorübergehend nicht verfügbar.", code: "ratings_unavailable" }, 503);
}

function quotaError(code: string): PlaceRatingError {
  if (code === "duplicate_request") return new PlaceRatingError("Diese Anfrage wurde bereits verarbeitet.", code, 409);
  if (code === "rate_limit") return new PlaceRatingError("Zu viele Bewertungsanfragen in kurzer Zeit.", code, 429);
  if (code === "monthly_limit") return new PlaceRatingError("Das monatliche Kontingent für Google-Bewertungen ist erreicht.", code, 429);
  return new PlaceRatingProviderError();
}

export function createPlaceRatingHandler(deps: PlaceRatingHandlerDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") return new Response(null, { status: 405, headers: { "Cache-Control": "no-store" } });
    try {
      const auth = await deps.authenticate(request);
      let body: unknown;
      try { body = JSON.parse(new TextDecoder().decode(new Uint8Array(await request.arrayBuffer()))); }
      catch { throw new PlaceRatingValidationError("Ungültiges JSON"); }
      const input = parsePlaceRatingRequest(body);
      const key = deps.getKey();
      if (!key) throw new PlaceRatingProviderError("Google-Bewertungen sind noch nicht eingerichtet.", "ratings_not_configured");
      if (input.trip_id) {
        let member = false;
        try { member = await deps.isTripMember(auth.admin, auth.userId, input.trip_id); }
        catch { throw new PlaceRatingError("Reisezugriff konnte nicht geprüft werden.", "membership_error", 503); }
        if (!member) throw new PlaceRatingError("Kein Zugriff auf diese Reise.", "forbidden_trip", 403);
      }
      let reservation: { ok: boolean; code?: string };
      try { reservation = await deps.reserve(auth.admin, auth.userId, input.request_id); }
      catch { throw new PlaceRatingProviderError(); }
      if (!reservation.ok) throw quotaError(String(reservation.code || "ratings_unavailable"));
      const fetchRating = deps.fetchRating ?? fetchGooglePlaceRating;
      const rating = await fetchRating(input, key, fetch, request.signal);
      return json(rating);
    } catch (error) { return errorResponse(error); }
  };
}
