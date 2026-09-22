import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export const jsonHeaders = { "Content-Type": "application/json" };

export async function clients(request: Request) {
  const authorization = request.headers.get("Authorization");
  if (!authorization) throw new Response(JSON.stringify({ error: "Nicht angemeldet" }), { status: 401, headers: jsonHeaders });
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const userClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) throw new Response(JSON.stringify({ error: "Ungültige Sitzung" }), { status: 401, headers: jsonHeaders });
  return { user, admin: createClient(url, serviceKey) };
}

export function randomToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export async function hashToken(token: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return Array.from(new Uint8Array(digest)).map(value => value.toString(16).padStart(2, "0")).join("");
}

export function respond(error: unknown) {
  if (error instanceof Response) return error;
  return new Response(JSON.stringify({ error: "Serverfehler" }), { status: 500, headers: jsonHeaders });
}
