import { clients, jsonHeaders, respond } from "../_shared/album.ts";
import { choosePlace, firstArray, validCoordinate, type PlaceCandidate } from "../_shared/place_photo.ts";
import { resolveWikimedia } from "../_shared/wikimedia_photos.ts";

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

    const photos = await resolveWikimedia(title, category, latitude, longitude);
    if (photos.length) return json({ image: photos[0], candidates: photos });

    const enabled = Deno.env.get("TRIPADVISOR_TERRA_ENABLED")?.toLowerCase() === "true";
    const key = Deno.env.get("TRIPADVISOR_TERRA_API_KEY");
    if (enabled && key) {
      const tripadvisor = await resolveTripadvisor(title, address, category, latitude, longitude, key).catch(() => null);
      if (tripadvisor) return json({ image: tripadvisor });
    }
    return json({ image: null });
  } catch (error) { return respond(error); }
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
