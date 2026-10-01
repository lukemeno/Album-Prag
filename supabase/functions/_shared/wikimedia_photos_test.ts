import { assert, assertEquals, assertRejects } from "jsr:@std/assert";
import { resolveWikimedia } from "./wikimedia_photos.ts";

Deno.test("Wikidata aliases and Commons depicts flow into ranked image choices", async () => {
  const original = globalThis.fetch;
  const calls: URL[] = [];
  globalThis.fetch = async (input) => {
    const url = new URL(String(input));
    calls.push(url);
    const action = url.searchParams.get("action");
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
          pages: Object.fromEntries([
            [10, "File:Café Louvre exterior.jpg"],
            [11, "File:Kavárna Louvre interior.jpg"],
            [12, "File:Vltava panorama.jpg"],
          ].map(([id, title]) => [id, {
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
          }])),
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
    assertEquals(images.length, 2);
    assertEquals(images[0].caption, "Kavárna Louvre interior");
    assertEquals(images[0].confidence, "verified");
    assertEquals(images[0].provider_place_id, "Q123");
    assertEquals(images[0].credit, "Anna");
    assert(
      calls.some((url) =>
        url.hostname === "commons.wikimedia.org" &&
        url.searchParams.get("ids")?.includes("M11")
      ),
    );
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
