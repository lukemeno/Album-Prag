import { choosePlace, distanceMeters, firstArray, rankPhotos, stripHTML, type PhotoCandidate, type PlaceCandidate } from "./place_photo.ts";

const wikimediaHeaders = { "User-Agent": Deno.env.get("WIKIMEDIA_USER_AGENT") || "Album-Prague/1.0 (private travel app)" };

/// Sammelt Fotos aus drei Quellen (Hauptbild, Commons-Kategorie, Umgebung) und gibt die typischsten zuerst zurück.
export async function resolveWikimedia(title: string, category: string, latitude: number, longitude: number, address = "") {
  let failure: unknown;
  const entities: Array<{ id: string; value: any }> = [];
  let place: PlaceCandidate | undefined;
  for (const language of ["de", "cs", "en"]) {
    try {
      const matches = await wikidataSearch(title, language);
      const ids = matches.map(item => item.id).filter(id => !entities.some(entity => entity.id === id)).slice(0, 12);
      entities.push(...await wikidataEntities(ids));
      place = choosePlace(entities.flatMap(entityCandidate), title, latitude, longitude, address);
      if (place) break;
    } catch (error) { failure = error; break; }
  }
  if (!place) {
    for (const language of ["cs", "en"] as const) {
      try {
        place = choosePlace(await wikipediaPlaces(language, latitude, longitude), title, latitude, longitude, address);
        if (place) break;
      } catch (error) { failure = error; }
    }
  }
  const names = [title, place?.name ?? title, ...entities.filter(entity => entity.id === place?.id)
    .flatMap(entity => [...Object.values(entity.value?.labels ?? {}), ...Object.values(entity.value?.aliases ?? {}).flat()].map((label: any) => label?.value))
    .filter((value): value is string => typeof value === "string")];
  const sources = new Map<string, Pick<PhotoCandidate, "source" | "meters">>();
  let infos: Awaited<ReturnType<typeof fileInfos>> = [];
  if (place?.image) {
    sources.set(`File:${place.image}`, { source: "main" });
    try { infos = await fileInfos([...sources.keys()]); } catch (error) { failure = error; }
  }
  async function optional<T>(load: () => Promise<T>, empty: T): Promise<T> {
    try { return await load(); } catch (error) {
      failure = error;
      console.warn("Optional place photo data unavailable", String(error));
      return empty;
    }
  }
  const members = place?.commonsCategory ? await optional(() => categoryFiles(place!.commonsCategory!), []) : [];
  for (const file of members) if (!sources.has(file)) sources.set(file, { source: "category" });
  if (!infos.length && !members.length) {
    const nearby = await optional(() => nearbyFiles(latitude, longitude), []);
    for (const file of nearby) if (!sources.has(file.title)) sources.set(file.title, { source: "nearby", meters: file.meters });
  }
  const extraTitles = [...sources.keys()].filter(title => !infos.some(info => info.candidate.title === title)).slice(0, 24);
  if (extraTitles.length) infos.push(...await optional(() => fileInfos(extraTitles), []));
  const mediaIDs = infos.filter(info => sources.get(info.candidate.title)?.source === "nearby").map(info => `M${info.pageID}`);
  const depicted = new Set<number>();
  if (place) {
    for (let index = 0; index < mediaIDs.length; index += 50) {
      const payload = await optional(() => commons({ action: "wbgetentities", ids: mediaIDs.slice(index, index + 50).join("|"), props: "claims" }), null);
      for (const [id, entity] of Object.entries(payload?.entities ?? {}) as Array<[string, any]>) {
        const statements = entity.statements ?? entity.claims;
        if (statements?.P180?.some((claim: any) => claim.rank !== "deprecated" && claim.mainsnak?.datavalue?.value?.id === place.id)) depicted.add(Number(id.slice(1)));
      }
    }
  }
  const ranked = rankPhotos(infos.map(info => ({ ...info.candidate, ...sources.get(info.candidate.title)!, depictsPlace: depicted.has(info.pageID) })), [...new Set(names)], category);
  if (!ranked.length && failure) throw failure;
  return ranked.map(({ photo, confidence }) => {
    const info = infos.find(value => value.candidate.title === photo.title)!;
    return {
      image_url: info.imageURL,
      source_url: info.sourceURL,
      credit: info.credit,
      provider: "wikimedia",
      provider_place_id: place?.id ?? null,
      license_name: info.licenseName,
      license_url: info.licenseURL,
      confidence,
      caption: photo.title.replace(/^File:/, "").replace(/\.[a-z]+$/i, ""),
    };
  });
}

/// Eine Anfrage an Wikidata oder Commons. Bei 429 (zu viele Anfragen) einmal kurz warten, dann ehrlich scheitern,
/// statt still „kein Bild“ zu melden.
export class WikimediaUnavailable extends Error {
  constructor(readonly host: string, readonly operation: string, readonly reason: string, readonly retryAfter = 30) {
    super(`Wikimedia ${host}/${operation}: ${reason}`);
  }
}

async function wikimedia(host: "www.wikidata.org" | "commons.wikimedia.org" | "cs.wikipedia.org" | "en.wikipedia.org", params: Record<string, string>) {
  const url = new URL(`https://${host}/w/api.php`);
  Object.entries({ format: "json", ...params }).forEach(([key, value]) => url.searchParams.set(key, value));
  for (let attempt = 0; attempt < 2; attempt++) {
    const operation = params.list ?? params.action;
    let response: Response;
    try { response = await fetch(url, { headers: wikimediaHeaders, signal: AbortSignal.timeout(8000) }); }
    catch { throw new WikimediaUnavailable(host, operation, "timeout_or_network"); }
    if (response.ok) {
      const payload = await response.json();
      if (payload.error) throw new WikimediaUnavailable(host, operation, String(payload.error.code));
      return payload;
    }
    const wait = Math.max(Number(response.headers.get("retry-after")) || 2, 1);
    await response.body?.cancel();
    if (response.status !== 429 || attempt === 1 || wait > 2) throw new WikimediaUnavailable(host, operation, `HTTP ${response.status}`, wait);
    await new Promise(resolve => setTimeout(resolve, wait * 1000));
  }
}

const commons = (params: Record<string, string>) => wikimedia("commons.wikimedia.org", params);

async function categoryFiles(category: string): Promise<string[]> {
  const payload = await commons({ action: "query", list: "categorymembers", cmtitle: `Category:${category}`, cmtype: "file", cmlimit: "20" });
  return (payload?.query?.categorymembers ?? []).map((member: any) => member.title);
}

/// Fotos, die im Umkreis von 400 m aufgenommen wurden.
async function nearbyFiles(latitude: number, longitude: number): Promise<Array<{ title: string; meters: number }>> {
  const payload = await commons({ action: "query", list: "geosearch", gscoord: `${latitude}|${longitude}`, gsradius: "400", gsnamespace: "6", gslimit: "20" });
  return (payload?.query?.geosearch ?? []).map((item: any) => ({
    title: item.title,
    meters: typeof item.dist === "number" ? item.dist : distanceMeters(item.lat, item.lon, latitude, longitude),
  }));
}

/// Größe, Auszeichnungen, Verwendung in Wikipedia-Artikeln und Lizenz, in Gruppen zu 50 Dateien.
async function fileInfos(titles: string[]) {
  const batches = [];
  for (let index = 0; index < titles.length; index += 50) batches.push(titles.slice(index, index + 50));
  const payloads = [];
  for (const batch of batches) payloads.push(await commons({
    action: "query", titles: batch.join("|"), prop: "imageinfo|globalusage",
    iiprop: "url|size|extmetadata", iiurlwidth: "1280", // feste Wikimedia-Breite; 1600 wird abgelehnt
    iiextmetadatafilter: "Artist|Credit|LicenseShortName|LicenseUrl|Assessments",
    gulimit: "50", gunamespace: "0",
  }));
  const pages = payloads.flatMap(payload => Object.values(payload?.query?.pages ?? {})) as any[];
  return pages.flatMap(page => {
    const info = page?.imageinfo?.[0];
    if (!info?.thumburl && !info?.url) return [];
    const metadata = info.extmetadata || {};
    return [{
      pageID: page.pageid as number,
      candidate: {
        title: page.title as string, source: "category" as const, uses: (page.globalusage ?? []).length,
        assessments: metadata.Assessments?.value ?? "", width: info.width ?? 0, height: info.height ?? 0,
      },
      imageURL: info.thumburl || info.url,
      sourceURL: info.descriptionurl || `https://commons.wikimedia.org/wiki/${encodeURIComponent(page.title.replace(/ /g, "_"))}`,
      credit: stripHTML(metadata.Artist?.value) || stripHTML(metadata.Credit?.value) || "Wikimedia Commons",
      licenseName: stripHTML(metadata.LicenseShortName?.value),
      licenseURL: metadata.LicenseUrl?.value,
    }];
  });
}

async function wikidataSearch(title: string, language: string) {
  const payload = await wikimedia("www.wikidata.org", { action: "wbsearchentities", search: title, language, uselang: language, type: "item", limit: "6" });
  return firstArray(payload) as Array<{ id: string }>;
}

/// Alle Einträge in einer Anfrage (statt einer pro Eintrag).
async function wikidataEntities(ids: string[]) {
  if (!ids.length) return [];
  const payload = await wikimedia("www.wikidata.org", { action: "wbgetentities", ids: ids.join("|"), props: "claims|labels|aliases", languages: "cs|de|en" });
  return ids.flatMap(id => payload?.entities?.[id]?.claims ? [{ id, value: payload.entities[id] }] : []);
}

function entityCandidate(entity: { id: string; value: any } | null): PlaceCandidate[] {
  if (!entity) return [];
  const coordinate = entity.value?.claims?.P625?.[0]?.mainsnak?.datavalue?.value;
  const image = entity.value?.claims?.P18?.[0]?.mainsnak?.datavalue?.value;
  const commonsCategory = entity.value?.claims?.P373?.[0]?.mainsnak?.datavalue?.value;
  const address = entity.value?.claims?.P6375?.[0]?.mainsnak?.datavalue?.value?.text;
  if (!coordinate || (typeof image !== "string" && typeof commonsCategory !== "string")) return [];
  const labels = [...Object.values(entity.value?.labels || {}), ...Object.values(entity.value?.aliases || {}).flat()].map((label: any) => label?.value).filter((value): value is string => typeof value === "string");
  return [...new Set(labels)].map(name => ({ id: entity.id, name, latitude: Number(coordinate.latitude), longitude: Number(coordinate.longitude),
    address: typeof address === "string" ? address : undefined,
    image: typeof image === "string" ? image : undefined, commonsCategory: typeof commonsCategory === "string" ? commonsCategory : undefined }));
}

async function wikipediaPlaces(language: "cs" | "en", latitude: number, longitude: number): Promise<PlaceCandidate[]> {
  const payload = await wikimedia(`${language}.wikipedia.org`, {
    action: "query", generator: "geosearch", ggscoord: `${latitude}|${longitude}`,
    ggsradius: "350", ggsnamespace: "0", ggslimit: "10",
    prop: "coordinates|pageimages|pageprops", piprop: "name", ppprop: "wikibase_item", colimit: "1",
  });
  return Object.values(payload?.query?.pages ?? {}).flatMap((page: any) => {
    const coordinate = page.coordinates?.[0];
    if (!coordinate || !page.pageimage) return [];
    return [{ id: page.pageprops?.wikibase_item ?? `${language}wiki:${page.pageid}`, name: page.title,
      latitude: coordinate.lat, longitude: coordinate.lon, image: page.pageimage }];
  });
}
