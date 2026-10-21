import { clients } from "../_shared/album.ts";
import { createPlaceEnrichmentHandler, EnrichmentError } from "../_shared/place_enrichment.ts";

const handler = createPlaceEnrichmentHandler({
  authenticate: async request => {
    const { user, admin } = await clients(request);
    return { userId: user.id, admin };
  },
  rpc: async (admin, name, args) => {
    const result = await admin.rpc(name, args);
    if (result.error?.message === "pending job limit reached") throw new EnrichmentError("pending_limit", "Zu viele offene Ortsanfragen. Bitte später erneut versuchen.", 429);
    if (result.error) throw new EnrichmentError("database_unavailable", "Jobstatus vorübergehend nicht verfügbar", 503);
    return result.data;
  },
  isTripMember: async (admin, userId, tripId) => {
    const result = await admin.from("trip_members").select("trip_id").eq("trip_id", tripId).eq("user_id", userId).limit(1);
    if (result.error) throw new EnrichmentError("membership_unavailable", "Reisezugriff konnte nicht geprüft werden", 503);
    return Boolean(result.data?.length);
  },
});
Deno.serve(handler);
