import { clients, hashToken, jsonHeaders, respond } from "../_shared/album.ts";

Deno.serve(async request => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  try {
    const { user, admin } = await clients(request);
    const body = await request.json();
    const token = typeof body.invite_token === "string" ? body.invite_token : "";
    if (token.length < 32) return new Response(JSON.stringify({ error: "Ungültige Einladung" }), { status: 400, headers: jsonHeaders });
    const { data, error } = await admin.rpc("join_trip_for_user", {
      target_user_id: user.id,
      token_hash: await hashToken(token),
    });
    if (error) throw error;
    if (!data) return new Response(JSON.stringify({ error: "Einladung ungültig oder abgelaufen" }), { status: 404, headers: jsonHeaders });
    return new Response(JSON.stringify({ trip_id: data }), { headers: jsonHeaders });
  } catch (error) { return respond(error); }
});
