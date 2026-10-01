import { assert, assertEquals, assertRejects } from "jsr:@std/assert";
import { resolveWikimedia } from "./wikimedia_photos.ts";

async function aliasFixture(optionalFailure: string | null = null) {
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
      "Café Louvre",
      "Essen & Trinken",
      50.0819,
      14.4185,
    );
    assertEquals(images.length, optionalFailure === "category" ? 1 : 2);
    assertEquals(
      images[0].caption,
      optionalFailure === "category"
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
  } finally {
    globalThis.fetch = original;
  }
}

Deno.test("Wikidata aliases and Commons depicts flow into ranked image choices", () =>
  aliasFixture());
Deno.test("optional category failure preserves the verified main image", () =>
  aliasFixture("category"));
Deno.test("verified source-bound photos need no optional depicts lookup", () =>
  aliasFixture("depicts"));

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
