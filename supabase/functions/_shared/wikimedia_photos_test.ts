import { assert, assertEquals, assertRejects } from "jsr:@std/assert";
import { fetchWikimediaP18Images, resolveWikimedia, wikimediaLanguages } from "./wikimedia_photos.ts";

Deno.test("exact P18 discovery lookup requests File namespace and keeps QID binding through normalization", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async input => {
    const url = new URL(String(input));
    assertEquals(url.hostname, "commons.wikimedia.org");
    assertEquals(url.searchParams.get("titles"), "File:Tour_Eiffel.jpg");
    assertEquals(url.searchParams.get("redirects"), "1");
    return Response.json({ query: {
      normalized: [{ from: "File:Tour_Eiffel.jpg", to: "File:Tour Eiffel.jpg" }],
      pages: { 123: { title: "File:Tour Eiffel.jpg", imageinfo: [{
        thumburl: "https://upload.wikimedia.org/eiffel.jpg",
        descriptionurl: "https://commons.wikimedia.org/wiki/File:Tour_Eiffel.jpg",
        extmetadata: {
          Artist: { value: "Example Author" },
          LicenseShortName: { value: "CC BY-SA 4.0" },
          LicenseUrl: { value: "https://creativecommons.org/licenses/by-sa/4.0/" },
        },
      }] } },
    } });
  };
  try {
    const images = await fetchWikimediaP18Images(
      [{ qid: "Q243", title: "Tour_Eiffel.jpg" }],
      new AbortController().signal,
      { run: async (_signal, work) => await work() },
    );
    assertEquals(images.get("Q243")?.provider_place_id, "Q243");
    assertEquals(images.get("Q243")?.confidence, "verified");
    assertEquals(images.get("Q243")?.license_name, "CC BY-SA 4.0");
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("exact P18 discovery lookup rejects HTTP 200 API errors", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = () => Promise.resolve(Response.json({ error: { code: "maxlag", lag: 30 } }));
  try {
    await assertRejects(
      () => fetchWikimediaP18Images(
        [{ qid: "Q243", title: "Tour_Eiffel.jpg" }],
        new AbortController().signal,
        { run: async (_signal, work) => await work() },
      ),
      Error,
      "maxlag",
    );
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("exact P18 discovery lookup keeps case-distinct Commons files bound to their own QIDs", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async input => {
    const url = new URL(String(input));
    assertEquals(url.searchParams.get("titles"), "File:AbC.jpg|File:Abc.jpg");
    const image = (title: string, suffix: string) => ({ title, imageinfo: [{
      thumburl: `https://upload.wikimedia.org/${suffix}.jpg`,
      descriptionurl: `https://commons.wikimedia.org/wiki/${title}`,
      extmetadata: {
        Artist: { value: `Author ${suffix}` },
        LicenseShortName: { value: "CC BY 4.0" },
        LicenseUrl: { value: "https://creativecommons.org/licenses/by/4.0/" },
      },
    }] });
    return Response.json({ query: { pages: {
      1: image("File:AbC.jpg", "upper"),
      2: image("File:Abc.jpg", "lower"),
    } } });
  };
  try {
    const images = await fetchWikimediaP18Images(
      [{ qid: "Q1001", title: "AbC.jpg" }, { qid: "Q1002", title: "Abc.jpg" }],
      new AbortController().signal,
      { run: async (_signal, work) => await work() },
    );
    assertEquals(images.get("Q1001")?.image_url, "https://upload.wikimedia.org/upper.jpg");
    assertEquals(images.get("Q1002")?.image_url, "https://upload.wikimedia.org/lower.jpg");
  } finally {
    globalThis.fetch = original;
  }
});

async function aliasFixture(optionalFailure: string | null = null, query = "Café Louvre", automaticMainOnly = false) {
  const original = globalThis.fetch;
  const calls: URL[] = [];
  globalThis.fetch = async (input) => {
    const url = new URL(String(input));
    calls.push(url);
    const action = url.searchParams.get("action");
    if (
      optionalFailure === "category" &&
      url.searchParams.get("list") === "categorymembers"
    ) return Response.json({ error: { code: "maxlag" } });
    if (
      optionalFailure === "depicts" && action === "wbgetentities" &&
      url.hostname === "commons.wikimedia.org"
    ) return Response.json({ error: { code: "maxlag" } });
    let body: unknown;
    if (action === "wbsearchentities") {
      body = { search: [{ id: "Q123" }] };
    } else if (
      action === "wbgetentities" && url.hostname === "www.wikidata.org"
    ) {
      body = {
        entities: {
          Q123: {
            labels: { en: { value: "Café Louvre" } },
            aliases: { cs: [{ value: "Kavárna Louvre" }] },
            claims: {
              P625: [{
                mainsnak: {
                  datavalue: {
                    value: { latitude: 50.0819, longitude: 14.4185 },
                  },
                },
              }],
              P18: [{
                mainsnak: { datavalue: { value: "Café Louvre exterior.jpg" } },
              }],
              P373: [{ mainsnak: { datavalue: { value: "Café Louvre" } } }],
            },
          },
        },
      };
    } else if (action === "wbgetentities") {
      body = {
        entities: {
          M11: {
            statements: {
              P180: [{
                rank: "normal",
                mainsnak: { datavalue: { value: { id: "Q123" } } },
              }],
            },
          },
        },
      };
    } else if (url.searchParams.get("list") === "categorymembers") {
      body = {
        query: {
          categorymembers: [{ title: "File:Kavárna Louvre interior.jpg" }],
        },
      };
    } else if (url.searchParams.get("list") === "geosearch") {
      body = {
        query: { geosearch: [{ title: "File:Vltava panorama.jpg", dist: 30 }] },
      };
    } else {
      body = {
        query: {
          pages: Object.fromEntries(
            [
              [10, "File:Café Louvre exterior.jpg"],
              [11, "File:Kavárna Louvre interior.jpg"],
              [12, "File:Vltava panorama.jpg"],
            ].filter(([, title]) =>
              url.searchParams.get("titles")?.split("|").includes(String(title))
            ).map(([id, title]) => [id, {
              pageid: id,
              title,
              globalusage: [],
              imageinfo: [{
                thumburl: `https://example.com/${id}.jpg`,
                descriptionurl: `https://example.com/file/${id}`,
                width: 3000,
                height: 2000,
                extmetadata: {
                  Artist: { value: "<b>Anna</b>" },
                  LicenseShortName: { value: "CC BY-SA 4.0" },
                  LicenseUrl: {
                    value: "https://creativecommons.org/licenses/by-sa/4.0/",
                  },
                },
              }],
            }]),
          ),
        },
      };
    }
    return Response.json(body);
  };
  try {
    const images = await resolveWikimedia(
      query,
      "Essen & Trinken",
      50.0819,
      14.4185,
      "",
      "",
      undefined,
      undefined,
      undefined,
      automaticMainOnly,
    );
    assertEquals(images.length, automaticMainOnly ? 1 : optionalFailure === "category" ? 1 : 2);
    assertEquals(
      images[0].caption,
      automaticMainOnly
        ? "Café Louvre exterior"
        : optionalFailure === "category"
        ? "Café Louvre exterior"
        : "Kavárna Louvre interior",
    );
    assertEquals(images[0].confidence, "verified");
    assertEquals(images[0].provider_place_id, "Q123");
    assertEquals(images[0].credit, "Anna");
    assert(
      calls.filter((url) =>
        url.searchParams.get("action") === "wbsearchentities"
      ).length === 1,
    );
    if (automaticMainOnly) {
      assertEquals(images.length, 1);
      assertEquals(calls.some(url => url.searchParams.get("list") === "categorymembers" || url.searchParams.get("list") === "geosearch"), false);
    }
  } finally {
    globalThis.fetch = original;
  }
}

Deno.test("Wikidata aliases and Commons depicts flow into ranked image choices", () =>
  aliasFixture());

Deno.test("a single entity can be resolved by its localized alias", () =>
  aliasFixture(null, "Kavárna Louvre"));
Deno.test("optional category failure preserves the verified main image", () =>
  aliasFixture("category"));
Deno.test("verified source-bound photos need no optional depicts lookup", () =>
  aliasFixture("depicts"));
Deno.test("automatic main-image mode keeps the verified P18 and avoids gallery calls", () =>
  aliasFixture(null, "Café Louvre", true));

async function automaticRejectFixture(fileTitle: string, category: string) {
  const original = globalThis.fetch;
  const calls: URL[] = [];
  globalThis.fetch = async input => {
    const url = new URL(String(input)); calls.push(url);
    const action = url.searchParams.get("action");
    if (url.hostname === "www.wikidata.org" && action === "wbsearchentities") return Response.json({ search: [{ id: "Q123" }] });
    if (url.hostname === "www.wikidata.org" && action === "wbgetentities") return Response.json({ entities: { Q123: { labels: { en: { value: category === "Aussicht" ? "Viewpoint" : "Museum" } }, claims: { P625: [{ mainsnak: { datavalue: { value: { latitude: 50, longitude: 14 } } } }], P18: [{ mainsnak: { datavalue: { value: fileTitle } } }] } } } });
    return Response.json({ query: { pages: { 10: { pageid: 10, title: `File:${fileTitle}`, imageinfo: [{ thumburl: "https://example.com/photo.jpg", descriptionurl: "https://example.com/file", width: 2000, height: 1200, extmetadata: { Artist: { value: "Author" }, LicenseShortName: { value: "CC BY 4.0" }, LicenseUrl: { value: "https://creativecommons.org/licenses/by/4.0/" } } }] } } } });
  };
  try {
    const images = await resolveWikimedia(category === "Aussicht" ? "Viewpoint" : "Museum", category, 50, 14, "", "", undefined, undefined, undefined, true);
    assertEquals(images, []);
    assertEquals(calls.some(url => url.searchParams.get("list") === "categorymembers" || url.searchParams.get("list") === "geosearch"), false);
  } finally { globalThis.fetch = original; }
}
Deno.test("automatic mode rejects an SVG P18 without gallery fallback", () => automaticRejectFixture("Museum.svg", "Sehenswert"));
Deno.test("automatic mode rejects a logo P18 without gallery fallback", () => automaticRejectFixture("Museum logo.jpg", "Sehenswert"));
Deno.test("automatic mode rejects an unqualified Aussicht P18 without gallery fallback", () => automaticRejectFixture("Building facade.jpg", "Aussicht"));

Deno.test("verified QID cache skips the second Commons/media sequence", async () => {
  const original = globalThis.fetch;
  let commonsCalls = 0;
  let stored: Awaited<ReturnType<typeof resolveWikimedia>> | null = null;
  globalThis.fetch = async input => {
    const url = new URL(String(input));
    const action = url.searchParams.get("action");
    if (url.hostname === "www.wikidata.org" && action === "wbsearchentities") return Response.json({ search: [{ id: "Q123" }] });
    if (url.hostname === "www.wikidata.org" && action === "wbgetentities") return Response.json({ entities: { Q123: { labels: { en: { value: "Museum" } }, claims: { P625: [{ mainsnak: { datavalue: { value: { latitude: 50, longitude: 14 } } } }] } } } });
    commonsCalls++;
    if (url.searchParams.get("list") === "geosearch") return Response.json({ query: { geosearch: [] } });
    if (url.searchParams.get("list") === "categorymembers") return Response.json({ query: { categorymembers: [] } });
    return Response.json({ query: { pages: {} } });
  };
  const cache = {
    load: async (_identity: { protocol: "wikidata"; id: string }) => stored,
    store: async (_identity: { protocol: "wikidata"; id: string }, photos: Awaited<ReturnType<typeof resolveWikimedia>>) => { stored = photos; },
  };
  try {
    await resolveWikimedia("Museum", "Sehenswert", 50, 14, "", "", undefined, undefined, cache);
    const afterFirst = commonsCalls;
    await resolveWikimedia("Museum", "Sehenswert", 50, 14, "", "", undefined, undefined, cache);
    assertEquals(commonsCalls, afterFirst);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("a Wikimedia API error is not a successful empty search", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async () => Response.json({ error: { code: "maxlag" } });
  try {
    await assertRejects(
      () =>
        resolveWikimedia("Café Louvre", "Essen & Trinken", 50.0819, 14.4185),
      Error,
      "maxlag",
    );
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("Wikipedia falls back with exact name and coordinates when Wikidata is unavailable", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = new URL(String(input));
    if (url.hostname === "www.wikidata.org") {
      return Response.json({ error: { code: "maxlag" } });
    }
    if (url.hostname === "cs.wikipedia.org") {
      return Response.json({
        query: {
          pages: {
            10: {
              pageid: 10,
              title: "Café Louvre",
              coordinates: [{ lat: 50.0819, lon: 14.4185 }],
              pageimage: "Café Louvre exterior.jpg",
              pageprops: { wikibase_item: "Q12879009" },
            },
          },
        },
      });
    }
    if (url.searchParams.get("list")) {
      return Response.json({ error: { code: "maxlag" } });
    }
    return Response.json({
      query: {
        pages: {
          11: {
            pageid: 11,
            title: "File:Café Louvre exterior.jpg",
            imageinfo: [{
              thumburl: "https://example.com/photo.jpg",
              descriptionurl: "https://example.com/source",
              width: 3000,
              height: 2000,
              extmetadata: {
                Artist: { value: "Anna" },
                LicenseShortName: { value: "CC BY-SA 4.0" },
              },
            }],
          },
        },
      },
    });
  };
  try {
    const images = await resolveWikimedia(
      "Café Louvre",
      "Essen & Trinken",
      50.0819,
      14.4185,
      "",
      "Prag",
    );
    assertEquals(images[0].confidence, "verified");
    assertEquals(images[0].provider_place_id, "Q12879009");
    assertEquals(images[0].credit, "Anna");
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("Wikipedia never auto-selects a nearby differently named venue", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = new URL(String(input));
    if (url.hostname.endsWith("wikipedia.org")) {
      return Response.json({
        query: {
          pages: {
            10: {
              pageid: 10,
              title: "Café Savoy",
              coordinates: [{ lat: 50.0819, lon: 14.4185 }],
              pageimage: "Café Savoy.jpg",
            },
          },
        },
      });
    }
    if (url.searchParams.get("action") === "wbsearchentities") {
      return Response.json({ search: [] });
    }
    return Response.json({ query: { geosearch: [] } });
  };
  try {
    assertEquals(
      await resolveWikimedia(
        "Café Louvre",
        "Essen & Trinken",
        50.0819,
        14.4185,
      ),
      [],
    );
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("same-name Cristo Redentor station and monument remain unresolved across languages", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = new URL(String(input));
    const action = url.searchParams.get("action");
    if (action === "wbsearchentities") {
      return Response.json({ search: [{ id: url.searchParams.get("language") === "pt" ? "Q79961" : "Q120648408" }] });
    }
    if (action === "wbgetentities" && url.hostname === "www.wikidata.org") {
      return Response.json({
        entities: {
          Q120648408: {
            labels: {
              en: { value: "Cristo Redentor train station" },
              pt: { value: "Cristo Redentor" },
            },
            claims: {
              P625: [{ mainsnak: { datavalue: { value: { latitude: -22.9520, longitude: -43.2104 } } } }],
              P18: [{ mainsnak: { datavalue: { value: "Station Cristo Redentor.jpg" } } }],
              P373: [{ mainsnak: { datavalue: { value: "Corcovado Rack Railway station" } } }],
              P31: [{ mainsnak: { datavalue: { value: { id: "Q55488" } } } }],
            },
          },
          Q79961: {
            labels: { en: { value: "Christ the Redeemer" }, pt: { value: "Cristo Redentor" } },
            claims: {
              P625: [{ mainsnak: { datavalue: { value: { latitude: -22.9519, longitude: -43.2105 } } } }],
              P31: [{ mainsnak: { datavalue: { value: { id: "Q29168169" } } } }],
            },
          },
        },
      });
    }
    if (url.hostname.endsWith("wikipedia.org")) {
      return Response.json({ query: { pages: {} } });
    }
    if (url.searchParams.get("list") === "geosearch") {
      return Response.json({
        query: { geosearch: [{ title: "File:Trem do Corcovado Estação Cristo Redentor exterior.jpg", dist: 20 }] },
      });
    }
    if (url.searchParams.get("list") === "categorymembers") {
      return Response.json({ query: { categorymembers: [] } });
    }
    return Response.json({
      query: {
        pages: {
          120: {
            pageid: 120,
            title: "File:Trem do Corcovado Estação Cristo Redentor exterior.jpg",
            globalusage: [],
            imageinfo: [{
              thumburl: "https://example.com/station.jpg",
              descriptionurl: "https://example.com/station-source",
              width: 2400,
              height: 1600,
              extmetadata: {
                Artist: { value: "Photographer" },
                LicenseShortName: { value: "CC BY 4.0" },
                LicenseUrl: { value: "https://creativecommons.org/licenses/by/4.0/" },
              },
            }],
          },
        },
      },
    });
  };
  try {
    const images = await resolveWikimedia(
      "Cristo Redentor",
      "Sehenswert",
      -22.9519,
      -43.2105,
      "",
      "Rio de Janeiro, Brasil",
    );
    assertEquals(images.some((image) => image.provider_place_id === "Q120648408"), false);
    assertEquals(images.some((image) => image.provider_place_id === "Q79961"), false);
    assertEquals(images.some((image) => image.confidence === "verified"), false);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("Wikipedia matching keeps exact-name pages without a page image in ambiguity checks", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = new URL(String(input));
    if (url.searchParams.get("action") === "wbsearchentities") return Response.json({ search: [] });
    if (url.hostname.endsWith("wikipedia.org")) {
      const english = url.hostname.startsWith("en.");
      return Response.json({ query: { pages: {
        [english ? "10" : "20"]: {
          pageid: english ? 10 : 20,
          title: "Cristo Redentor",
          coordinates: [{ lat: -22.9519, lon: -43.2105 }],
          ...(english ? { pageimage: "Cristo Redentor.jpg" } : {}),
          pageprops: { wikibase_item: english ? "Q120648408" : "Q79961" },
        },
      } } });
    }
    if (url.searchParams.get("list") === "geosearch") return Response.json({ query: { geosearch: [] } });
    return Response.json({ query: { pages: {} } });
  };
  try {
    const images = await resolveWikimedia("Cristo Redentor", "Sehenswert", -22.9519, -43.2105, "", "Rio de Janeiro, Brasil");
    assertEquals(images.some(image => image.provider_place_id === "Q120648408" || image.provider_place_id === "Q79961"), false);
    assertEquals(images.some(image => image.confidence === "verified"), false);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("Wikipedia-Sprache folgt globalem Ortskontext; Englisch bleibt Fallback", () => {
  assertEquals(wikimediaLanguages("Prag"), ["en", "cs"]);
  assertEquals(wikimediaLanguages("Lissabon, Portugal"), ["en", "pt"]);
  assertEquals(wikimediaLanguages("Tokyo, Japan"), ["en", "ja"]);
  assertEquals(wikimediaLanguages("Kyoto, Japan"), ["en", "ja"]);
  assertEquals(wikimediaLanguages("São Paulo, Brazil"), ["en", "pt"]);
  assertEquals(wikimediaLanguages("Cairo, Egypt"), ["en", "ar"]);
  assertEquals(wikimediaLanguages("Seoul, South Korea"), ["en", "ko"]);
  assertEquals(wikimediaLanguages("Mumbai, India"), ["en", "hi"]);
  assertEquals(wikimediaLanguages("京都, 日本"), ["en", "ja"]);
  assertEquals(wikimediaLanguages("東京, 日本", "ja-JP"), ["en", "ja"]);
  assertEquals(wikimediaLanguages("Tokyo, Japan", "de-DE"), ["en", "de", "ja"]);
  assertEquals(wikimediaLanguages("Paris, France", "de-DE"), ["en", "de", "fr"]);
  assertEquals(wikimediaLanguages("Seoul", "xx-IGNORE.invalid"), ["en", "ko"]);
  assertEquals(wikimediaLanguages(""), ["en"]);
  assertEquals(wikimediaLanguages("", "en-US"), ["en"]);
  assertEquals(wikimediaLanguages("", "https://evil.example/x"), ["en"]);
});
