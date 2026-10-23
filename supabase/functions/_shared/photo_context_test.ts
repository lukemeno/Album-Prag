import { assertEquals, assertNotEquals } from "jsr:@std/assert";
import {
  cleanPhotoRegion,
  photoCacheKey,
  supportedWikipediaLanguage,
} from "./photo_context.ts";

Deno.test("language input accepts supported BCP 47 tags and rejects injection/unsupported codes", () => {
  assertEquals(supportedWikipediaLanguage("ja-JP"), "ja-JP");
  assertEquals(supportedWikipediaLanguage("ko-KR"), "ko-KR");
  assertEquals(supportedWikipediaLanguage("xx"), undefined);
  assertEquals(supportedWikipediaLanguage("en.wikipedia.org"), undefined);
  assertEquals(supportedWikipediaLanguage("https://evil.example"), undefined);
  assertEquals(supportedWikipediaLanguage("ja;evil=1"), undefined);
});

Deno.test("region input is bounded and strips control characters", () => {
  assertEquals(cleanPhotoRegion("  Tokyo\u0000, Japan  "), "Tokyo , Japan");
  assertEquals(cleanPhotoRegion("x".repeat(250)).length, 200);
  assertEquals(cleanPhotoRegion(undefined), "");
});

Deno.test("photo cache key partitions by region and validated language", () => {
  const base = {
    title: "Museum",
    category: "Culture",
    latitude: 1,
    longitude: 2,
    address: "",
  };
  const first = photoCacheKey({
    ...base,
    region: "Tokyo",
    languageCode: "ja-JP",
  });
  assertNotEquals(
    first,
    photoCacheKey({ ...base, region: "Kyoto", languageCode: "ja-JP" }),
  );
  assertNotEquals(
    first,
    photoCacheKey({ ...base, region: "Tokyo", languageCode: "en-US" }),
  );
  assertEquals(
    photoCacheKey({ ...base, region: "", languageCode: "invalid" }),
    photoCacheKey({ ...base, region: "" }),
  );
});
