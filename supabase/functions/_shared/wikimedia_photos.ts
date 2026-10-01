import { choosePlace, distanceMeters, firstArray, rankPhotos, stripHTML, type PhotoCandidate, type PlaceCandidate } from "./place_photo.ts";

const wikimediaHeaders = { "User-Agent": Deno.env.get("WIKIMEDIA_USER_AGENT") || "Album-Prague/1.0 (private travel app)" };

/// Sammelt Fotos aus drei Quellen (Hauptbild, Commons-Kategorie, Umgebung) und gibt die typischsten zuerst zurück.
export async function resolveWikimedia(title: string, category: string, latitude: number, longitude: number, address = "") {
  // Nacheinander statt gleichzeitig: Wikimedia drosselt Schwälle von Anfragen (HTTP 429).
  const searches = [];
  for (const language of ["cs", "de", "en"]) searches.push(await wikidataSearch(title, language));
  const ids = [...new Set(searches.flat().map(item => item.id).filter(Boolean))].slice(0, 12);
  const entities = await wikidataEntities(ids);
  const place = choosePlace(entities.flatMap(entityCandidate), title, latitude, longitude, address);

  const members = place?.commonsCategory ? await categoryFiles(place.commonsCategory) : [];
  const nearby = await nearbyFiles(latitude, longitude);
  const sources = new Map<string, Pick<PhotoCandidate, "source" | "meters">>();
  for (const file of nearby) sources.set(file.title, { source: "nearby", meters: file.meters });
  for (const file of members) sources.set(file, { source: "category" });
  if (place?.image) sources.set(`File:${place.image}`, { source: "main" });

  const infos = await fileInfos([...sources.keys()]);
  // Alle Namen des Orts, damit auch „Karlův most“ und „Charles Bridge“ im Dateinamen zählen.
  const names = [title, ...entities.filter(entity => entity.id === place?.id)
    .flatMap(entity => [...Object.values(entity.value?.labels ?? {}), ...Object.values(entity.value?.aliases ?? {}).flat()].map((label: any) => label?.value))
    .filter((value): value is string => typeof value === "string")];
  const mediaIDs = infos.map(info => `M${info.pageID}`);
  const depicted = new Set<number>();
  if (place) {
    for (let index = 0; index < mediaIDs.length; index += 50) {
      const payload = await commons({ action: "wbgetentities", ids: mediaIDs.slice(index, index + 50).join("|"), props: "claims" });
      for (const [id, entity] of Object.entries(payload?.entities ?? {}) as Array<[string, any]>) {
        const statements = entity.statements ?? entity.claims;
        if (statements?.P180?.some((claim: any) => claim.rank !== "deprecated" && claim.mainsnak?.datavalue?.value?.id === place.id)) depicted.add(Number(id.slice(1)));
      }
    }
  }
  const ranked = rankPhotos(infos.map(info => ({ ...info.candidate, ...sources.get(info.candidate.title)!, depictsPlace: depicted.has(info.pageID) })), [...new Set(names)], category);
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
async function wikimedia(host: "www.wikidata.org" | "commons.wikimedia.org", params: Record<string, string>) {
  const url = new URL(`https://${host}/w/api.php`);
  Object.entries({ format: "json", ...params }).forEach(([key, value]) => url.searchParams.set(key, value));
  for (let attempt = 0; attempt < 2; attempt++) {
    const response = await fetch(url, { headers: wikimediaHeaders });
    if (response.ok) {
      const payload = await response.json();
      if (payload.error) throw new Error(`Wikimedia: ${payload.error.code}`);
      return payload;
    }
    if (response.status !== 429 || attempt === 1) throw new Error(`Wikimedia antwortet mit ${response.status}`);
    await response.body?.cancel();
    const wait = Math.min(Number(response.headers.get("retry-after")) || 2, 5);
    await new Promise(resolve => setTimeout(resolve, wait * 1000));
  }
}

const commons = (params: Record<string, string>) => wikimedia("commons.wikimedia.org", params);

async function categoryFiles(category: string): Promise<string[]> {
  const payload = await commons({ action: "query", list: "categorymembers", cmtitle: `Category:${category}`, cmtype: "file", cmlimit: "50" });
  return (payload?.query?.categorymembers ?? []).map((member: any) => member.title);
}

/// Fotos, die im Umkreis von 400 m aufgenommen wurden.
async function nearbyFiles(latitude: number, longitude: number): Promise<Array<{ title: string; meters: number }>> {
  const payload = await commons({ action: "query", list: "geosearch", gscoord: `${latitude}|${longitude}`, gsradius: "400", gsnamespace: "6", gslimit: "50" });
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
    iiprop: "url|size|extmetadata", iiurlwidth: "1600",
    iiextmetadatafilter: "Artist|Credit|LicenseShortName|LicenseUrl|Assessments",
    gulimit: "500", gunamespace: "0",
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
