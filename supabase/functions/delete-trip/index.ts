import { clients, jsonHeaders, respond } from "../_shared/album.ts";
import { handleTripLifecycle, supabaseTripStore } from "../_shared/trip_lifecycle.ts";

Deno.serve(async request => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  try {
    const { user, admin } = await clients(request);
    const { trip_id: tripID } = await request.json().catch(() => ({}));
    const result = await handleTripLifecycle("delete", String(tripID ?? ""), user.id, supabaseTripStore(admin));
    return new Response(JSON.stringify(result.body), { status: result.status, headers: jsonHeaders });
  } catch (error) { return respond(error); }
});
