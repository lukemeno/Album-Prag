import { assertEquals, assertMatch } from "jsr:@std/assert";
import { hashToken, randomToken } from "./album.ts";

Deno.test("invitation tokens have enough entropy and URL-safe characters", () => {
  const token = randomToken();
  assertEquals(token.length, 43);
  assertMatch(token, /^[A-Za-z0-9_-]+$/);
});

Deno.test("invitation token hashing is stable", async () => {
  assertEquals(await hashToken("album-test-token"), "543f08b046000897290af868a8ef50d9d3577f99a7581d5ddccacbf0ad8985ee");
});
