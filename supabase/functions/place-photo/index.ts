import { clients, jsonHeaders, respond } from "../_shared/album.ts";
import { choosePlace, firstArray, stripHTML, validCoordinate, type PlaceCandidate, type WikimediaFile } from "../_shared/place_photo.ts";

const wikimediaHeaders = { "User-Agent": Deno.env.get("WIKIMEDIA_USER_AGENT") || "Album-Prague/1.0 (private travel app)" };

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

    const wikimedia = await resolveWikimedia(title, latitude, longitude);
    if (wikimedia) return json({ image: wikimedia });

    const enabled = Deno.env.get("TRIPADVISOR_TERRA_ENABLED")?.toLowerCase() === "true";
    const key = Deno.env.get("TRIPADVISOR_TERRA_API_KEY");
    if (enabled && key) {
      const tripadvisor = await resolveTripadvisor(title, address, category, latitude, longitude, key).catch(() => null);
      if (tripadvisor) return json({ image: tripadvisor });
    }
    return json({ image: null });
  } catch (error) { return respond(error); }
});

async function resolveWikimedia(title: string, latitude: number, longitude: number) {
  const searches = await Promise.all(["cs", "de", "en"].map(language => wikidataSearch(title, language)));
  const ids = [...new Set(searches.flat().map(item => item.id).filter(Boolean))].slice(0, 12);
  const entities = await Promise.all(ids.map(wikidataEntity));
  const candidates = entities.flatMap(entityCandidate);
  const place = choosePlace(candidates, title, latitude, longitude);
  if (!place?.image) return null;
  const file = await wikimediaFile(place.image);
  if (!file) return null;
  return {
    image_url: file.imageURL,
    source_url: file.sourceURL,
    credit: file.credit,
    provider: "wikimedia",
    provider_place_id: place.id,
    license_name: file.licenseName,
    license_url: file.licenseURL,
  };
}

async function wikidataSearch(title: string, language: string) {
  const url = new URL("https://www.wikidata.org/w/api.php");
  Object.entries({ action: "wbsearchentities", search: title, language, uselang: language, type: "item", limit: "6", format: "json" })
    .forEach(([key, value]) => url.searchParams.set(key, value));
  const response = await fetch(url, { headers: wikimediaHeaders });
  if (!response.ok) return [];
  return firstArray(await response.json()) as Array<{ id: string }>;
}

async function wikidataEntity(id: string) {
  const response = await fetch(`https://www.wikidata.org/wiki/Special:EntityData/${encodeURIComponent(id)}.json`, { headers: wikimediaHeaders });
  if (!response.ok) return null;
  const payload = await response.json();
  return payload?.entities?.[id] ? { id, value: payload.entities[id] } : null;
}

function entityCandidate(entity: { id: string; value: any } | null): PlaceCandidate[] {
  if (!entity) return [];
  const coordinate = entity.value?.claims?.P625?.[0]?.mainsnak?.datavalue?.value;
  const image = entity.value?.claims?.P18?.[0]?.mainsnak?.datavalue?.value;
  if (!coordinate || typeof image !== "string") return [];
  const labels = Object.values(entity.value?.labels || {}).map((label: any) => label?.value).filter((value): value is string => typeof value === "string");
  return [...new Set(labels)].map(name => ({ id: entity.id, name, latitude: Number(coordinate.latitude), longitude: Number(coordinate.longitude), image }));
}

async function wikimediaFile(filename: string): Promise<WikimediaFile | null> {
  const url = new URL("https://commons.wikimedia.org/w/api.php");
  Object.entries({ action: "query", format: "json", prop: "imageinfo", iiprop: "url|extmetadata", iiurlwidth: "1600", titles: `File:${filename}` })
    .forEach(([key, value]) => url.searchParams.set(key, value));
  const response = await fetch(url, { headers: wikimediaHeaders });
  if (!response.ok) return null;
  const payload = await response.json();
  const page = Object.values(payload?.query?.pages || {})[0] as any;
  const info = page?.imageinfo?.[0];
  if (!info?.thumburl && !info?.url) return null;
  const metadata = info.extmetadata || {};
  const artist = stripHTML(metadata.Artist?.value);
  const credit = stripHTML(metadata.Credit?.value);
  return {
    imageURL: info.thumburl || info.url,
    sourceURL: info.descriptionurl || `https://commons.wikimedia.org/wiki/File:${encodeURIComponent(filename.replace(/ /g, "_"))}`,
    credit: artist || credit || "Wikimedia Commons",
    licenseName: stripHTML(metadata.LicenseShortName?.value),
    licenseURL: metadata.LicenseUrl?.value,
  };
}

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
