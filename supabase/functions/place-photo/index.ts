import { clients, jsonHeaders, respond } from "../_shared/album.ts";
import { choosePlace, firstArray, validCoordinate, type PlaceCandidate } from "../_shared/place_photo.ts";
import { resolveWikimedia, WikimediaUnavailable } from "../_shared/wikimedia_photos.ts";

import { createPhotoCache } from "../_shared/place_photo_cache.ts";

const cachedWikimedia = createPhotoCache(async key => {
  const [title, category, latitude, longitude, address] = JSON.parse(key);
  return await resolveWikimedia(title, category, latitude, longitude, address);
});

Deno.serve(async request => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  try {
    await clients(request);
    const body = await request.json();
    const title = typeof body.title === "string" ? body.title.trim() : "";
    const address = typeof body.address === "string" ? body.address.trim() : "";
    const category = typeof body.category === "string" ? body.category : "Idee";
    const latitude = Number(body.latitude);
    const longitude = Number(body.longitude);
    if (!title || !validCoordinate(latitude, longitude)) return json({ error: "Ort oder Koordinaten fehlen" }, 400);

    const photos = await cachedWikimedia(JSON.stringify([title, category, latitude, longitude, address]));
    const candidates = body.selection_version >= 3 ? photos : photos.filter(photo => photo.confidence === "verified");
    const image = photos.find(photo => photo.confidence === "verified");
    if (image) return json({ image, candidates, selection_version: 3 });

    const enabled = Deno.env.get("TRIPADVISOR_TERRA_ENABLED")?.toLowerCase() === "true";
    const key = Deno.env.get("TRIPADVISOR_TERRA_API_KEY");
    if (enabled && key) {
      const tripadvisor = await resolveTripadvisor(title, address, category, latitude, longitude, key).catch(() => null);
      if (tripadvisor && body.selection_version >= 3) return json({ image: null, candidates: [{ ...tripadvisor, confidence: "suggested" }, ...photos], selection_version: 3 });
    }
    return json({ image: null, candidates, selection_version: 3 });
  } catch (error) {
    if (error instanceof WikimediaUnavailable) {
      console.warn("Place photo source unavailable", error.host, error.operation, error.reason);
      return new Response(JSON.stringify({ error: "Die Bildquelle ist vorübergehend nicht verfügbar. Bitte später erneut versuchen.", code: "image_source_unavailable" }), {
        status: 503, headers: { ...jsonHeaders, "Retry-After": String(error.retryAfter) },
      });
    }
    return respond(error);
  }
});

async function resolveTripadvisor(title: string, address: string, category: string, latitude: number, longitude: number, key: string) {
  const search = new URL("https://terra.tripadvisor.com/api/locations/search");
  search.searchParams.set("query", address ? `${title}, ${address}` : title);
  search.searchParams.set("country_code", "CZ");
  search.searchParams.set("geo_name", "Prague");
  search.searchParams.set("locale", "de-DE");
  search.searchParams.set("size", "10");
  search.searchParams.set("category", category === "Essen & Trinken" ? "RESTAURANT" : category === "Unterkunft" ? "HOTEL" : "ATTRACTION");
  const response = await terra(search, key);
  if (!response) return null;
  const place = choosePlace(firstArray(response).flatMap(tripadvisorCandidate), title, latitude, longitude);
  if (!place) return null;
  const photos = await terra(new URL(`https://terra.tripadvisor.com/api/locations/${encodeURIComponent(place.id)}/photos?locale=de-DE&size=5`), key);
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
