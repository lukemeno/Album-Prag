import { excerptMatchesDocument, isUuid, type AssistantRequest } from "./assistant_validation.ts";

export class AssistantMembershipError extends Error {
  status: number;
  code: string;
  constructor(message: string, code: string, status: number) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

/** Service-role lookup used only after bearer auth; every shared context ID is checked against the same trip. */
export async function verifyAssistantTripContext(admin: any, userId: string, request: AssistantRequest): Promise<void> {
  if (!request.trip_id) return;
  if (!isUuid(request.trip_id)) throw new AssistantMembershipError("Ungültige Reise.", "invalid_trip", 400);
  const membership = await admin
    .from("trip_members")
    .select("trip_id")
    .eq("trip_id", request.trip_id)
    .eq("user_id", userId)
    .limit(1);
  if (membership.error) throw new AssistantMembershipError("Reisezugriff konnte nicht geprüft werden.", "membership_error", 503);
  if (!membership.data?.length) throw new AssistantMembershipError("Kein Zugriff auf diese Reise.", "forbidden_trip", 403);

  const placeIds = [...new Set(request.context.places.map((place) => place.id))];
  if (placeIds.length) {
    const result = await admin.from("places").select("id").eq("trip_id", request.trip_id).in("id", placeIds);
    if (result.error || result.data?.length !== placeIds.length) throw new AssistantMembershipError("Ungültiger Ortskontext.", "invalid_context", 403);
  }
  const documentIds = [...new Set(request.context.documents.map((document) => document.id))];
  if (documentIds.length) {
    const result = await admin.from("documents").select("id,extracted_text").eq("trip_id", request.trip_id).in("id", documentIds);
    if (result.error || result.data?.length !== documentIds.length) throw new AssistantMembershipError("Ungültiger Dokumentkontext.", "invalid_context", 403);
    const databaseDocuments = new Map<string, string>(result.data.map((document: { id: string; extracted_text: string }) => [document.id, String(document.extracted_text ?? "")]));
    for (const document of request.context.documents) {
      const extracted = databaseDocuments.get(document.id) ?? "";
      if (document.text && !excerptMatchesDocument(extracted, document.text)) {
        throw new AssistantMembershipError("Ungültiger Dokumentauszug.", "invalid_context", 403);
      }
    }
  }
  const collectionIds = [...new Set(request.context.collection.map((entry) => entry.id))];
  if (collectionIds.length) {
    const result = await admin.from("collection_entries").select("id").eq("trip_id", request.trip_id).in("id", collectionIds);
    if (result.error || result.data?.length !== collectionIds.length) throw new AssistantMembershipError("Ungültiger Sammlungskontext.", "invalid_context", 403);
  }
}
