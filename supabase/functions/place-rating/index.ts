import { clients } from "../_shared/album.ts";
import { createPlaceRatingHandler } from "../_shared/place_rating.ts";

const handler = createPlaceRatingHandler({
  authenticate: async request => {
    const { user, admin } = await clients(request);
    return { userId: user.id, admin };
  },
  reserve: async (admin, userId, requestId) => {
    const result = await admin.rpc("place_rating_reserve_call", {
      p_user_id: userId,
      p_request_id: requestId,
    });
    if (result.error) throw result.error;
    return (result.data ?? { ok: false, code: "ratings_unavailable" }) as { ok: boolean; code?: string };
  },
  isTripMember: async (admin, userId, tripId) => {
    const result = await admin.from("trip_members").select("trip_id").eq("trip_id", tripId).eq("user_id", userId).limit(1);
    if (result.error) throw result.error;
    return Boolean(result.data?.length);
  },
  getKey: () => Deno.env.get("GOOGLE_PLACES_API_KEY"),
});

Deno.serve(handler);
