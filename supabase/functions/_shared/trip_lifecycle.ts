import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

/// Every bucket that keeps trip files under `<trip-id>/…`.
export const TRIP_BUCKETS = ["trip-files", "trip-images", "trip-album"] as const;

export type TripAction = "delete" | "leave";
export type TripRole = "owner" | "member";

export interface TripLifecycleStore {
  tripExists(tripID: string): Promise<boolean>;
  role(tripID: string, userID: string): Promise<TripRole | null>;
  memberCount(tripID: string): Promise<number>;
  deleteTrip(tripID: string): Promise<void>;
  removeMember(tripID: string, userID: string): Promise<void>;
  listFiles(bucket: string, prefix: string): Promise<string[]>;
  removeFiles(bucket: string, paths: string[]): Promise<void>;
}

export interface TripLifecycleResult {
  status: number;
  body: Record<string, unknown>;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/// Owners delete a trip for everyone; members leave it. The database row goes
/// first, so a storage hiccup can only leave orphaned files, never a trip that
/// looks alive but has lost its files.
export async function handleTripLifecycle(action: TripAction, tripID: string, userID: string,
                                          store: TripLifecycleStore): Promise<TripLifecycleResult> {
  if (!UUID.test(tripID)) return { status: 400, body: { error: "Ungültige Reise" } };
  if (!(await store.tripExists(tripID))) return { status: 200, body: { status: "gone" } };
  const role = await store.role(tripID, userID);
  if (!role) return { status: 403, body: { error: "Kein Mitglied dieser Reise" } };

  if (action === "leave") {
    if (role === "member") {
      await store.removeMember(tripID, userID);
      return { status: 200, body: { status: "left" } };
    }
    if (await store.memberCount(tripID) > 1) {
      return { status: 409, body: { error: "Als Besitzer kannst du die Reise nur löschen" } };
    }
  } else if (role !== "owner") {
    return { status: 403, body: { error: "Nur der Besitzer kann die Reise löschen" } };
  }

  await store.deleteTrip(tripID);
  const storageCleanup = await removeTripFiles(tripID, store);
  return { status: 200, body: { status: "deleted", storageCleanup } };
}

async function removeTripFiles(tripID: string, store: TripLifecycleStore): Promise<"complete" | "incomplete"> {
  let complete = true;
  for (const bucket of TRIP_BUCKETS) {
    try {
      const paths = await store.listFiles(bucket, `${tripID}/`);
      for (let start = 0; start < paths.length; start += 100) {
        await store.removeFiles(bucket, paths.slice(start, start + 100));
      }
    } catch (error) {
      complete = false;
      console.error(`trip ${tripID}: cleanup of ${bucket} failed`, error);
    }
  }
  return complete ? "complete" : "incomplete";
}

/// Production store on the service-role client. Listing walks folders because
/// Storage only lists one level at a time.
export function supabaseTripStore(admin: SupabaseClient): TripLifecycleStore {
  return {
    async tripExists(tripID) {
      const { data, error } = await admin.from("trips").select("id").eq("id", tripID).maybeSingle();
      if (error) throw error;
      return data !== null;
    },
    async role(tripID, userID) {
      const { data, error } = await admin.from("trip_members").select("role")
        .eq("trip_id", tripID).eq("user_id", userID).maybeSingle();
      if (error) throw error;
      return (data?.role as TripRole | undefined) ?? null;
    },
    async memberCount(tripID) {
      const { count, error } = await admin.from("trip_members").select("user_id", { count: "exact", head: true })
        .eq("trip_id", tripID);
      if (error) throw error;
      return count ?? 0;
    },
    async deleteTrip(tripID) {
      const { error } = await admin.from("trips").delete().eq("id", tripID);
      if (error) throw error;
    },
    async removeMember(tripID, userID) {
      const { error } = await admin.from("trip_members").delete().eq("trip_id", tripID).eq("user_id", userID);
      if (error) throw error;
    },
    async listFiles(bucket, prefix) {
      const found: string[] = [];
      const folders = [prefix.replace(/\/$/, "")];
      while (folders.length > 0) {
        const folder = folders.pop()!;
        for (let offset = 0; ; offset += 1000) {
          const { data, error } = await admin.storage.from(bucket).list(folder, { limit: 1000, offset });
          if (error) throw error;
          for (const item of data ?? []) {
            // Folders come back without an id.
            if (item.id === null) folders.push(`${folder}/${item.name}`);
            else found.push(`${folder}/${item.name}`);
          }
          if ((data ?? []).length < 1000) break;
        }
      }
      return found;
    },
    async removeFiles(bucket, paths) {
      const { error } = await admin.storage.from(bucket).remove(paths);
      if (error) throw error;
    },
  };
}
