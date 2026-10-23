const wikipediaLanguages = new Set([
  "ar",
  "bn",
  "cs",
  "da",
  "de",
  "el",
  "en",
  "es",
  "fa",
  "fi",
  "fr",
  "he",
  "hi",
  "hr",
  "hu",
  "id",
  "it",
  "ja",
  "ko",
  "ms",
  "nl",
  "no",
  "pl",
  "pt",
  "ro",
  "ru",
  "sv",
  "th",
  "tr",
  "uk",
  "ur",
  "vi",
  "zh",
]);

/** Return a canonical BCP 47 tag only when it maps to an available Wikipedia language. */
export function supportedWikipediaLanguage(value: unknown): string | undefined {
  if (
    typeof value !== "string" || value.length > 35 ||
    !/^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$/.test(value)
  ) return;
  try {
    const [canonical] = Intl.getCanonicalLocales(value);
    const primary = canonical.split("-")[0].toLowerCase();
    return wikipediaLanguages.has(primary) ? canonical : undefined;
  } catch {
    return;
  }
}

export function cleanPhotoRegion(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, 200);
}

export function photoCacheKey(input: {
  title: string;
  category: string;
  latitude: number;
  longitude: number;
  address: string;
  region: string;
  languageCode?: string;
}): string {
  return JSON.stringify([
    input.title,
    input.category,
    input.latitude,
    input.longitude,
    input.address,
    input.region,
    supportedWikipediaLanguage(input.languageCode) ?? "",
  ]);
}
