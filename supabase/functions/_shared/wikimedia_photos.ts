import { choosePlace, distanceMeters, firstArray, hasAmbiguousExactPlaces, normalize, rankPhotos, stripHTML, type PhotoCandidate, type PlaceCandidate } from "./place_photo.ts";
import { supportedWikipediaLanguage } from "./photo_context.ts";

const wikimediaHeaders = { "User-Agent": Deno.env.get("WIKIMEDIA_USER_AGENT") || "Album/1.0 (private travel app)" };

export type WikimediaDiscoveryLimiter = { run<T>(signal: AbortSignal, work: () => Promise<T>): Promise<T> };
export type WikimediaRequestLimiter = { run<T>(work: () => Promise<T>): Promise<T> };
export type WikimediaPhoto = { image_url: string; source_url: string; credit: string; provider: "wikimedia"; provider_place_id?: string | null; license_name?: string; license_url?: string; confidence: "verified" | "suggested"; caption?: string };
export type WikimediaIdentityCache = {
  load: (identity: { protocol: "wikidata"; id: string }) => Promise<WikimediaPhoto[] | null>;
  store: (identity: { protocol: "wikidata"; id: string }, photos: WikimediaPhoto[]) => Promise<void>;
};
export type WikimediaDiscoveryImageEntry = { qid: string; title: string };

/// Exact-QID P18 metadata in batches; unlike resolveWikimedia this never searches or ranks by name.
export async function fetchWikimediaP18Images(entries: WikimediaDiscoveryImageEntry[], signal: AbortSignal, limiter: WikimediaDiscoveryLimiter) {
  const result = new Map<string, { image_url: string; source_url: string; credit: string; provider: "wikimedia"; license_name: string; license_url: string; provider_place_id: string; confidence: "verified"; caption?: string }>();
  const unique = new Map<string, string>();
  for (const entry of entries) if (/^Q[1-9][0-9]*$/.test(entry.qid) && entry.title.trim()) {
    unique.set(entry.qid, `File:${entry.title.trim().replace(/^File:/i, "")}`);
  }
  const values = [...unique];
  for (let offset = 0; offset < values.length; offset += 50) {
    const batch = values.slice(offset, offset + 50);
    const titleToQIDs = new Map<string, string[]>();
    const titleKey = (title: string) => title.trim().replace(/^File:/i, "").replaceAll("_", " ").replace(/\s+/g, " ");
    for (const [qid, title] of batch) {
      const key = titleKey(title);
      titleToQIDs.set(key, [...(titleToQIDs.get(key) ?? []), qid]);
    }
    const url = new URL("https://commons.wikimedia.org/w/api.php");
    for (const [key, value] of Object.entries({ format: "json", action: "query", titles: batch.map(([, title]) => title).join("|"), redirects: "1", prop: "imageinfo", iiprop: "url|extmetadata", iiurlwidth: "1600", iiextmetadatafilter: "Artist|Credit|LicenseShortName|LicenseUrl" })) url.searchParams.set(key, value);
    const payload = await limiter.run(signal, async () => {
      const response = await fetch(url, { redirect: "error", headers: wikimediaHeaders, signal });
      if (!response.ok) throw new WikimediaUnavailable("commons.wikimedia.org", "query", `HTTP ${response.status}`, Math.max(1, Number(response.headers.get("retry-after")) || 30));
      const payload = await response.json();
      if (payload?.error) throw new WikimediaUnavailable("commons.wikimedia.org", "query", String(payload.error.code ?? "api_error"), Math.max(1, Number(response.headers.get("retry-after")) || Number(payload.error.lag) || 30));
      return payload;
    });
    for (const mapping of [...(payload?.query?.normalized ?? []), ...(payload?.query?.redirects ?? [])]) {
      const source = titleToQIDs.get(titleKey(String(mapping.from ?? ""))) ?? [];
      if (source.length) {
        const target = titleKey(String(mapping.to ?? ""));
        titleToQIDs.set(target, [...new Set([...(titleToQIDs.get(target) ?? []), ...source])]);
      }
    }
    for (const page of Object.values(payload?.query?.pages ?? {}) as any[]) {
      const info = page?.imageinfo?.[0], metadata = info?.extmetadata ?? {};
      const imageURL = info?.thumburl || info?.url;
      const sourceURL = info?.descriptionurl;
      const credit = stripHTML(metadata.Artist?.value) || stripHTML(metadata.Credit?.value);
      const licenseName = stripHTML(metadata.LicenseShortName?.value);
      const licenseURL = metadata.LicenseUrl?.value;
      if (typeof imageURL !== "string" || typeof sourceURL !== "string" || !credit || !licenseName || typeof licenseURL !== "string" || !/^https:\/\//i.test(licenseURL)) continue;
      const qids = titleToQIDs.get(titleKey(String(page.title ?? ""))) ?? [];
      for (const qid of qids) result.set(qid, { image_url: imageURL, source_url: sourceURL, credit, provider: "wikimedia", license_name: licenseName, license_url: licenseURL, provider_place_id: qid, confidence: "verified", caption: String(page.title).replace(/^File:/, "").replace(/\.[a-z0-9]+$/i, "") });
    }
  }
  return result;
}

/// Sammelt Fotos aus drei Quellen (Hauptbild, Commons-Kategorie, Umgebung) und gibt die typischsten zuerst zurück.
export async function resolveWikimedia(title: string, category: string, latitude: number, longitude: number, address = "", regionName = "", languageCode?: string, limiter?: WikimediaRequestLimiter, identityCache?: WikimediaIdentityCache, automaticMainOnly = false): Promise<WikimediaPhoto[]> {
  let failure: unknown;
  const entities: Array<{ id: string; value: any }> = [];
  let place: PlaceCandidate | undefined;
  const languages = wikimediaLanguages(regionName, languageCode);
  const ids = new Set<string>();
  for (const language of languages) {
    try {
      const matches = await wikidataSearch(title, language, limiter);
      for (const item of matches.slice(0, 6)) if (item.id) ids.add(item.id);
    } catch (error) { failure = error; break; }
  }
  if (ids.size) {
    try {
      entities.push(...await wikidataEntities([...ids].slice(0, 12), languages, limiter));
    } catch (error) { failure = error; }
  }
  const wikidataPlaces = entities.flatMap(entityCandidate);
  const ambiguousWikidata = hasAmbiguousExactPlaces(wikidataPlaces, title, latitude, longitude, address);
  if (!ambiguousWikidata) place = choosePlace(wikidataPlaces, title, latitude, longitude, address);
  if (!place && !ambiguousWikidata) {
    const wikipediaCandidates: PlaceCandidate[] = [];
    for (const language of languages) {
      try {
        wikipediaCandidates.push(...await wikipediaPlaces(language, latitude, longitude, limiter));
      } catch (error) { failure = error; }
    }
    place = choosePlace(wikipediaCandidates, title, latitude, longitude, address);
  }
  const identity = place?.id && /^Q[1-9][0-9]*$/.test(place.id) ? { protocol: "wikidata" as const, id: place.id } : null;
  if (automaticMainOnly && !identity) return [];
  if (identity && identityCache) {
    const cached = await identityCache.load(identity);
    if (cached) return cached;
  }
  const names = [title, place?.name ?? title, ...entities.filter(entity => entity.id === place?.id)
    .flatMap(entity => [...Object.values(entity.value?.labels ?? {}), ...Object.values(entity.value?.aliases ?? {}).flat()].map((label: any) => label?.value))
    .filter((value): value is string => typeof value === "string")];
  const sources = new Map<string, Pick<PhotoCandidate, "source" | "meters">>();
  let infos: Awaited<ReturnType<typeof fileInfos>> = [];
  if (place?.image) {
    sources.set(`File:${place.image}`, { source: "main" });
    try { infos = await fileInfos([...sources.keys()], limiter); } catch (error) { failure = error; }
  }
  if (automaticMainOnly && identity) {
    const info = infos[0];
    if (!infos.length && failure) throw failure;
    const checked = info ? rankPhotos([{ ...info.candidate, source: "main" }], [...new Set(names)], category, 1)[0] : null;
    const publicDomain = Boolean(info?.licenseName && /public\s+domain/i.test(info.licenseName));
    if (checked?.confidence === "verified" && info.imageURL && info.sourceURL && info.credit && info.licenseName && (info.licenseURL || publicDomain)) {
      const main: WikimediaPhoto[] = [{ image_url: info.imageURL, source_url: info.sourceURL, credit: info.credit, provider: "wikimedia", provider_place_id: identity.id, license_name: info.licenseName, ...(info.licenseURL ? { license_url: info.licenseURL } : {}), confidence: "verified", caption: info.candidate.title.replace(/^File:/, "").replace(/\.[a-z]+$/i, "") }];
      if (identityCache) await identityCache.store(identity, main);
      return main;
    }
    if (identityCache) await identityCache.store(identity, []);
    return [];
  }
  async function optional<T>(load: () => Promise<T>, empty: T): Promise<T> {
    try { return await load(); } catch (error) {
      failure = error;
      console.warn("Optional place photo data unavailable", String(error));
      return empty;
    }
  }
  const members = place?.commonsCategory ? await optional(() => categoryFiles(place!.commonsCategory!, limiter), []) : [];
  for (const file of members) if (!sources.has(file)) sources.set(file, { source: "category" });
  if (!infos.length && !members.length) {
    const nearby = await optional(() => nearbyFiles(latitude, longitude, limiter), []);
    for (const file of nearby) if (!sources.has(file.title)) sources.set(file.title, { source: "nearby", meters: file.meters });
  }
  const extraTitles = [...sources.keys()].filter(title => !infos.some(info => info.candidate.title === title)).slice(0, 24);
  if (extraTitles.length) infos.push(...await optional(() => fileInfos(extraTitles, limiter), []));
  const mediaIDs = infos.filter(info => sources.get(info.candidate.title)?.source === "nearby").map(info => `M${info.pageID}`);
  const depicted = new Set<number>();
  if (place) {
    for (let index = 0; index < mediaIDs.length; index += 50) {
      const payload = await optional(() => commons({ action: "wbgetentities", ids: mediaIDs.slice(index, index + 50).join("|"), props: "claims" }, limiter), null);
      for (const [id, entity] of Object.entries(payload?.entities ?? {}) as Array<[string, any]>) {
        const statements = entity.statements ?? entity.claims;
        if (statements?.P180?.some((claim: any) => claim.rank !== "deprecated" && claim.mainsnak?.datavalue?.value?.id === place.id)) depicted.add(Number(id.slice(1)));
      }
    }
  }
  const ranked = rankPhotos(infos.map(info => ({ ...info.candidate, ...sources.get(info.candidate.title)!, depictsPlace: depicted.has(info.pageID) })), [...new Set(names)], category);
  if (!ranked.length && failure) throw failure;
  const resolved = ranked.map(({ photo, confidence }) => {
    const info = infos.find(value => value.candidate.title === photo.title)!;
    return {
      image_url: info.imageURL,
      source_url: info.sourceURL,
      credit: info.credit,
      provider: "wikimedia" as const,
      provider_place_id: place?.id ?? null,
      license_name: info.licenseName,
      license_url: info.licenseURL,
      confidence,
      caption: photo.title.replace(/^File:/, "").replace(/\.[a-z]+$/i, ""),
    };
  });
  if (identity && identityCache) await identityCache.store(identity, resolved.filter(photo => photo.confidence === "verified" && photo.provider_place_id === identity.id));
  return resolved;
}

/// English, device language and a context-derived language keep global lookups bounded.
export function wikimediaLanguages(regionName: string, languageCode?: string): string[] {
  const explicitLanguage = supportedWikipediaLanguage(languageCode)?.split("-")[0].toLowerCase();
  const region = normalize(regionName);
  const hints: Array<[string, string[]]> = [
    ["ja", ["japan", "tokyo", "kyoto", "osaka", "日本", "東京", "京都"]],
    ["pt", ["brazil", "brasil", "portugal", "rio de janeiro", "sao paulo", "lisbon", "lisboa", "brasilia"]],
    ["ar", ["egypt", "cairo", "masr", "القاهرة", "مصر", "morocco", "maroc", "tunisia", "algeria", "saudi arabia", "amman", "jordan"]],
    ["ko", ["south korea", "republic of korea", "seoul", "busan", "korea", "한국", "서울", "부산"]],
    ["zh", ["china", "taiwan", "hong kong", "beijing", "shanghai", "中国", "台灣", "台湾", "香港"]],
    ["hi", ["india", "mumbai", "delhi", "new delhi", "भारत"]],
    ["bn", ["bangladesh", "dhaka", "বাংলাদেশ", "ঢাকা"]],
    ["ru", ["russia", "россия", "moscow", "москва", "ukraine", "kyiv"]],
    ["de", ["germany", "deutschland", "berlin", "austria", "osterreich", "wien", "vienna", "switzerland", "schweiz"]],
    ["cs", ["czech", "cesko", "prague", "praha", "prag"]],
    ["es", ["spain", "espana", "mexico", "argentina", "madrid", "buenos aires", "peru", "colombia", "chile"]],
    ["fr", ["france", "paris", "belgium", "bruxelles", "brussels", "senegal", "cote d ivoire"]],
    ["it", ["italy", "italia", "rome", "roma"]],
    ["tr", ["turkey", "turkiye", "istanbul", "ankara", "türkiye"]],
    ["th", ["thailand", "bangkok", "ประเทศไทย", "กรุงเทพ"]],
    ["vi", ["vietnam", "viet nam", "hanoi", "ho chi minh", "việt nam"]],
    ["id", ["indonesia", "jakarta", "bali"]],
    ["nl", ["netherlands", "nederland", "amsterdam", "belgium"]],
  ];
  const regionalLanguage = hints.find(([, values]) => values.some(value => region.includes(normalize(value))))?.[0];
  return [...new Set(["en", explicitLanguage, regionalLanguage].filter((value): value is string => !!value))].slice(0, 3);
}

/// Eine Anfrage an Wikidata oder Commons. Bei 429 (zu viele Anfragen) einmal kurz warten, dann ehrlich scheitern,
/// statt still „kein Bild“ zu melden.
export class WikimediaUnavailable extends Error {
  constructor(readonly host: string, readonly operation: string, readonly reason: string, readonly retryAfter = 30) {
    super(`Wikimedia ${host}/${operation}: ${reason}`);
  }
}

async function wikimedia(host: string, params: Record<string, string>, limiter?: WikimediaRequestLimiter) {
  const url = new URL(`https://${host}/w/api.php`);
  Object.entries({ format: "json", ...params }).forEach(([key, value]) => url.searchParams.set(key, value));
  for (let attempt = 0; attempt < 2; attempt++) {
    const operation = params.list ?? params.action;
    let response: Response;
    try {
      const request = () => fetch(url, { redirect: "error", headers: wikimediaHeaders, signal: AbortSignal.timeout(8000) });
      response = limiter ? await limiter.run(request) : await request();
    } catch (error) {
      // Quota/defer errors from the distributed limiter must retain their
      // original code and retry-after; only network failures become 503s.
      const isQuotaError = error instanceof WikimediaUnavailable || (typeof error === "object" && error !== null && "retryAfterSeconds" in error && "code" in error);
      if (limiter && isQuotaError) throw error;
      throw new WikimediaUnavailable(host, operation, "timeout_or_network");
    }
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

const commons = (params: Record<string, string>, limiter?: WikimediaRequestLimiter) => wikimedia("commons.wikimedia.org", params, limiter);

async function categoryFiles(category: string, limiter?: WikimediaRequestLimiter): Promise<string[]> {
  const payload = await commons({ action: "query", list: "categorymembers", cmtitle: `Category:${category}`, cmtype: "file", cmlimit: "20" }, limiter);
  return (payload?.query?.categorymembers ?? []).map((member: any) => member.title);
}

/// Fotos, die im Umkreis von 400 m aufgenommen wurden.
async function nearbyFiles(latitude: number, longitude: number, limiter?: WikimediaRequestLimiter): Promise<Array<{ title: string; meters: number }>> {
  const payload = await commons({ action: "query", list: "geosearch", gscoord: `${latitude}|${longitude}`, gsradius: "400", gsnamespace: "6", gslimit: "20" }, limiter);
  return (payload?.query?.geosearch ?? []).map((item: any) => ({
    title: item.title,
    meters: typeof item.dist === "number" ? item.dist : distanceMeters(item.lat, item.lon, latitude, longitude),
  }));
}

/// Größe, Auszeichnungen, Verwendung in Wikipedia-Artikeln und Lizenz, in Gruppen zu 50 Dateien.
async function fileInfos(titles: string[], limiter?: WikimediaRequestLimiter) {
  const batches = [];
  for (let index = 0; index < titles.length; index += 50) batches.push(titles.slice(index, index + 50));
  const payloads = [];
  for (const batch of batches) payloads.push(await commons({
    action: "query", titles: batch.join("|"), prop: "imageinfo|globalusage",
    iiprop: "url|size|extmetadata", iiurlwidth: "1600",
    iiextmetadatafilter: "Artist|Credit|LicenseShortName|LicenseUrl|Assessments",
    gulimit: "50", gunamespace: "0",
  }, limiter));
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

async function wikidataSearch(title: string, language: string, limiter?: WikimediaRequestLimiter) {
  const payload = await wikimedia("www.wikidata.org", { action: "wbsearchentities", search: title, language, uselang: language, type: "item", limit: "6" }, limiter);
  return firstArray(payload) as Array<{ id: string }>;
}

/// Alle Einträge in einer Anfrage (statt einer pro Eintrag).
async function wikidataEntities(ids: string[], languages: string[], limiter?: WikimediaRequestLimiter) {
  if (!ids.length) return [];
  const payload = await wikimedia("www.wikidata.org", { action: "wbgetentities", ids: ids.join("|"), props: "claims|labels|aliases", languages: [...new Set([...languages, "en"])].join("|") }, limiter);
  return ids.flatMap(id => payload?.entities?.[id]?.claims ? [{ id, value: payload.entities[id] }] : []);
}

function entityCandidate(entity: { id: string; value: any } | null): PlaceCandidate[] {
  if (!entity) return [];
  const coordinate = entity.value?.claims?.P625?.[0]?.mainsnak?.datavalue?.value;
  const image = entity.value?.claims?.P18?.[0]?.mainsnak?.datavalue?.value;
  const commonsCategory = entity.value?.claims?.P373?.[0]?.mainsnak?.datavalue?.value;
  const address = entity.value?.claims?.P6375?.[0]?.mainsnak?.datavalue?.value?.text;
  if (!coordinate) return [];
  const labels = Object.values(entity.value?.labels || {}).map((label: any) => label?.value)
    .filter((value): value is string => typeof value === "string").map(name => ({ name, nameKind: "label" as const }));
  const aliases = Object.values(entity.value?.aliases || {}).flat().map((label: any) => label?.value)
    .filter((value): value is string => typeof value === "string").map(name => ({ name, nameKind: "alias" as const }));
  const names = new Map<string, "label" | "alias">();
  for (const entry of [...aliases, ...labels]) names.set(normalize(entry.name), entry.nameKind);
  return [...names].map(([normalized, nameKind]) => {
    const name = [...labels, ...aliases].find(entry => normalize(entry.name) === normalized)!.name;
    return { id: entity.id, name, nameKind, latitude: Number(coordinate.latitude), longitude: Number(coordinate.longitude),
    address: typeof address === "string" ? address : undefined,
    image: typeof image === "string" ? image : undefined, commonsCategory: typeof commonsCategory === "string" ? commonsCategory : undefined };
  });
}

async function wikipediaPlaces(language: string, latitude: number, longitude: number, limiter?: WikimediaRequestLimiter): Promise<PlaceCandidate[]> {
  const payload = await wikimedia(`${language}.wikipedia.org`, {
    action: "query", generator: "geosearch", ggscoord: `${latitude}|${longitude}`,
    ggsradius: "350", ggsnamespace: "0", ggslimit: "10",
    prop: "coordinates|pageimages|pageprops", piprop: "name", ppprop: "wikibase_item", colimit: "1",
  }, limiter);
  return Object.values(payload?.query?.pages ?? {}).flatMap((page: any) => {
    const coordinate = page.coordinates?.[0];
    if (!coordinate || !page.title) return [];
    return [{ id: page.pageprops?.wikibase_item ?? `${language}wiki:${page.pageid}`, name: page.title,
      latitude: coordinate.lat, longitude: coordinate.lon, image: page.pageimage }];
  });
}
