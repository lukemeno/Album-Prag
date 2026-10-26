import { clients, jsonHeaders, respond } from "../_shared/album.ts";
import { isUuid } from "../_shared/assistant_validation.ts";
import { choosePlace, firstArray, validCoordinate, type PlaceCandidate } from "../_shared/place_photo.ts";
import { resolveWikimedia, WikimediaUnavailable, type WikimediaIdentityCache, type WikimediaRequestLimiter } from "../_shared/wikimedia_photos.ts";

import { createPhotoCache, publicPhotoCacheKey } from "../_shared/place_photo_cache.ts";
import { cleanPhotoRegion, photoCacheKey, supportedWikipediaLanguage } from "../_shared/photo_context.ts";

const cachedWikimedia = createPhotoCache(async key => {
  const [title, category, latitude, longitude, address, region, languageCode] = JSON.parse(key);
  return await resolveWikimedia(title, category, latitude, longitude, address, region, languageCode);
});

Deno.serve(async request => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  try {
    const { user, admin } = await clients(request);
    const contentLength = Number(request.headers.get("content-length") ?? 0);
    if (contentLength > 32 * 1024) return json({ error: "Anfrage ist zu groß" }, 413);
    const body = await request.json();
    if (JSON.stringify(body).length > 32 * 1024) return json({ error: "Anfrage ist zu groß" }, 413);
    const title = typeof body.title === "string" ? body.title.trim() : "";
    const address = typeof body.address === "string" ? body.address.trim() : "";
    const category = typeof body.category === "string" ? body.category.trim() : "Idee";
    // Ältere Clients liefern keinen Kontext: dann bleibt die Suche neutral und koordinatenbasiert.
    const region = cleanPhotoRegion(body.region);
    const languageCode = supportedWikipediaLanguage(body.language_code);
    const tripID = body.trip_id == null ? null : typeof body.trip_id === "string" ? body.trip_id : "invalid";
    const placeID = body.place_id == null ? null : typeof body.place_id === "string" ? body.place_id.trim() : "invalid";
    const automaticMode = body.mode === "automatic_photo_v1";
    const manualMode = body.mode === "manual" || body.manual === true;
    const revision = body.revision == null ? "1" : typeof body.revision === "string" ? body.revision.trim() : "invalid";
    const latitude = typeof body.latitude === "number" ? body.latitude : NaN;
    const longitude = typeof body.longitude === "number" ? body.longitude : NaN;
    if (!title || title.length > 200 || address.length > 500 || category.length > 64 || !validCoordinate(latitude, longitude) || (tripID !== null && !isUuid(tripID)) || (placeID === "invalid" || placeID && (placeID.length < 1 || placeID.length > 128)) || revision === "invalid" || revision.length > 64 || typeof body.manual !== "undefined" && typeof body.manual !== "boolean" || (body.mode !== undefined && !automaticMode && !manualMode) || (automaticMode && (!placeID || typeof body.revision !== "string" || !revision || !validCoordinate(latitude, longitude)))) return json({ error: "Ungültige Ortsdaten" }, 400);

    const resolutionID = crypto.randomUUID();
    const manualQuotaKey = manualMode && placeID ? await publicPhotoCacheKey({ protocol: "private-manual", id: [user.id, tripID ?? "", placeID, revision].join(":" ) }) : null;
    const ramKey = photoCacheKey({ title, category, latitude, longitude, address, region, languageCode });
    const limiter: WikimediaRequestLimiter = { run: async <T>(work: () => Promise<T>) => {
      const result = await admin.rpc("place_photo_reserve_upstream", { p_resolution_id: resolutionID, p_provider: "wikimedia" });
      if (result.error || !result.data?.ok) throw new WikimediaUnavailable("commons.wikimedia.org", "quota", String(result.data?.code ?? "quota_unavailable"), Number(result.data?.retry_after_seconds) || 60);
      return await work();
    } };
    let publicLease: { key: string; token: string; id: string } | null = null;
    const identityCache: WikimediaIdentityCache = {
      load: async identity => {
        const key = await publicPhotoCacheKey(identity);
        const token = crypto.randomUUID();
        const claim = await admin.rpc("place_photo_cache_claim", { p_cache_key: key, p_identity_protocol: identity.protocol, p_pipeline_version: 1, p_lease_token: token });
        if (claim.error) throw claim.error;
        if (claim.data?.state === "busy") throw new WikimediaUnavailable("place-photo", "cache", "busy", Number(claim.data.retry_after_seconds) || 10);
        if (claim.data?.state === "fresh") return claim.data.payload ?? [];
        publicLease = { key, token, id: identity.id };
        return null;
      },
      store: async (identity, photos) => {
        const key = await publicPhotoCacheKey(identity);
        const lease = publicLease;
        if (!lease || lease.key !== key || lease.id !== identity.id) return;
        const now = new Date();
        const completed = await admin.rpc("place_photo_cache_complete", { p_cache_key: key, p_lease_token: lease.token, p_payload: photos, p_fetched_at: now.toISOString(), p_expires_at: new Date(now.getTime() + (photos.length ? 30 : 7) * 86400000).toISOString(), p_stale_until: new Date(now.getTime() + 90 * 86400000).toISOString() });
        if (completed.error || completed.data !== true) throw new WikimediaUnavailable("place-photo", "cache", "lease_expired", 10);
        publicLease = null;
      },
    };
    const loadPhotos = async () => {
      const run = await admin.rpc("place_photo_reserve_run", { p_resolution_id: resolutionID, p_user_id: user.id, p_trip_id: tripID, p_cache_key: manualQuotaKey, p_manual: manualMode });
      if (run.error || !run.data?.ok) throw new WikimediaUnavailable("commons.wikimedia.org", "quota", String(run.data?.code ?? "quota_unavailable"), Number(run.data?.retry_after_seconds) || 60);
      return await cachedWikimedia(ramKey, async key => {
        const [cachedTitle, cachedCategory, cachedLatitude, cachedLongitude, cachedAddress, cachedRegion, cachedLanguage] = JSON.parse(key);
        return await resolveWikimedia(cachedTitle, cachedCategory, cachedLatitude, cachedLongitude, cachedAddress, cachedRegion, cachedLanguage, limiter, identityCache);
      });
    };
    let photos: Awaited<ReturnType<typeof resolveWikimedia>> = [];
    if (placeID) {
      const token = crypto.randomUUID();
      const claim = await admin.rpc("place_photo_private_cache_claim", { p_user_id: user.id, p_trip_id: tripID, p_place_id: placeID, p_revision: revision, p_lease_token: token });
      if (claim.error) throw claim.error;
      if (claim.data?.state === "forbidden") return json({ error: "Reisezugriff erforderlich" }, 403);
      if (claim.data?.state === "fresh") photos = (claim.data.payload ?? []) as Awaited<ReturnType<typeof resolveWikimedia>>;
      else if (claim.data?.state === "busy") return json({ image: null, candidates: [], status: "deferred", retry_after_seconds: Number(claim.data.retry_after_seconds) || 10, selection_version: 4 }, 202);
      else {
        try {
          photos = await loadPhotos();
          const now = new Date();
          const completed = await admin.rpc("place_photo_private_cache_complete", { p_user_id: user.id, p_trip_id: tripID, p_place_id: placeID, p_revision: revision, p_lease_token: token, p_payload: photos, p_expires_at: new Date(now.getTime() + (photos.length ? 30 : 7) * 86400000).toISOString() });
          if (completed.error || completed.data !== true) throw new WikimediaUnavailable("place-photo", "cache", "lease_expired", 10);
        } catch (error) {
          await admin.rpc("place_photo_private_cache_release", { p_user_id: user.id, p_trip_id: tripID, p_place_id: placeID, p_revision: revision, p_lease_token: token });
          throw error;
        }
      }
    } else photos = await loadPhotos();
    const candidates = body.selection_version >= 3 ? photos : photos.filter(photo => photo.confidence === "verified");
    const image = photos.find(photo => photo.confidence === "verified");
    if (image) return json({ image, candidates, selection_version: 4 });

    const enabled = body.mode !== "automatic_photo_v1" && Deno.env.get("TRIPADVISOR_TERRA_ENABLED")?.toLowerCase() === "true";
    const key = Deno.env.get("TRIPADVISOR_TERRA_API_KEY");
    if (enabled && key && region) {
      const tripadvisor = await resolveTripadvisor(title, address, category, latitude, longitude, key, region, languageCode).catch(() => null);
      if (tripadvisor && body.selection_version >= 3) return json({ image: null, candidates: [{ ...tripadvisor, confidence: "suggested" }, ...photos], selection_version: 4 });
    }
    return json({ image: null, candidates, selection_version: 4 });
  } catch (error) {
    if (error instanceof WikimediaUnavailable) {
      console.warn("Place photo source unavailable", error.host, error.operation, error.reason);
      return new Response(JSON.stringify({ error: "Die Bildquelle ist vorübergehend nicht verfügbar. Bitte später erneut versuchen.", code: "image_source_unavailable", retry_after_seconds: error.retryAfter }), {
        status: 503, headers: { ...jsonHeaders, "Retry-After": String(error.retryAfter) },
      });
    }
    return respond(error);
  }
});

async function resolveTripadvisor(title: string, address: string, category: string, latitude: number, longitude: number, key: string, region: string, languageCode?: string) {
  const search = new URL("https://terra.tripadvisor.com/api/locations/search");
  search.searchParams.set("query", [title, address, region].filter(Boolean).join(", "));
  if (languageCode) search.searchParams.set("locale", languageCode);
  search.searchParams.set("size", "10");
  search.searchParams.set("category", category === "Essen & Trinken" ? "RESTAURANT" : category === "Unterkunft" ? "HOTEL" : "ATTRACTION");
  const response = await terra(search, key);
  if (!response) return null;
  const place = choosePlace(firstArray(response).flatMap(tripadvisorCandidate), title, latitude, longitude);
  if (!place) return null;
  const photosURL = new URL(`https://terra.tripadvisor.com/api/locations/${encodeURIComponent(place.id)}/photos`);
  photosURL.searchParams.set("size", "5");
  if (languageCode) photosURL.searchParams.set("locale", languageCode);
  const photos = await terra(photosURL, key);
  const photo = firstImageURL(photos);
  if (!photo) return null;
  return {
    image_url: photo,
    source_url: place.sourceURL || `https://www.tripadvisor.com/Search?q=${encodeURIComponent(title)}`,
    credit: "Tripadvisor",
    provider: "tripadvisor",
    provider_place_id: place.id,
  };
}

async function terra(url: URL, key: string) {
  const response = await fetch(url, { headers: { Accept: "application/json", "X-API-Key": key } });
  if (!response.ok) return null;
  return await response.json();
}

function tripadvisorCandidate(value: unknown): PlaceCandidate[] {
  if (!value || typeof value !== "object") return [];
  const item = value as any;
  const id = item.tripadvisor_id ?? item.id;
  const name = item.name ?? item.names?.find((entry: any) => entry.primary)?.value ?? item.names?.[0]?.value;
  const coordinates = item.coordinates ?? item.coordinate ?? {};
  const sourceURL = item.web_url ?? item.urls?.find((entry: any) => entry.type === "WEB")?.url ?? item.urls?.[0]?.url;
  if (id == null || typeof name !== "string") return [];
  return [{ id: String(id), name, latitude: Number(coordinates.latitude ?? item.latitude), longitude: Number(coordinates.longitude ?? item.longitude), sourceURL, raw: value }];
}

function firstImageURL(value: unknown): string | null {
  if (!value) return null;
  if (typeof value === "string" && /^https:\/\//.test(value) && /\.(jpe?g|png|webp)(\?|$)/i.test(value)) return value;
  if (Array.isArray(value)) for (const item of value) { const found = firstImageURL(item); if (found) return found; }
  if (typeof value === "object") {
    const record = value as Record<string, unknown>;
    for (const key of ["large", "original", "image_url", "url", "images", "photos", "data", "content"]) {
      const found = firstImageURL(record[key]);
      if (found) return found;
    }
  }
  return null;
}

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: jsonHeaders });
}

