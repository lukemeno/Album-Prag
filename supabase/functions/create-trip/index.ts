import { clients, hashToken, jsonHeaders, randomToken, respond } from "../_shared/album.ts";

Deno.serve(async request => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  try {
    const { user, admin } = await clients(request);
    const inviteToken = randomToken();
    const { data, error } = await admin.rpc("create_trip_for_user", {
      target_user_id: user.id,
      token_hash: await hashToken(inviteToken),
    });
    if (error) throw error;
    return new Response(JSON.stringify({ trip_id: data, invite_token: inviteToken }), { headers: jsonHeaders });
  } catch (error) { return respond(error); }
});
