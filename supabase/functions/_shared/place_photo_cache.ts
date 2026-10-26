export function createPhotoCache<T>(
  load: (key: string) => Promise<T[]>,
  now = Date.now,
) {
  const cached = new Map<string, { photos: T[]; expires: number }>();
  const pending = new Map<string, Promise<T[]>>();
  return async (key: string, overrideLoad?: (key: string) => Promise<T[]>): Promise<T[]> => {
    const hit = cached.get(key);
    if (hit && hit.expires > now()) return hit.photos;
    cached.delete(key);
    const active = pending.get(key);
    if (active) return active;
    const request = (overrideLoad ? overrideLoad(key) : load(key)).then((photos) => {
      if (cached.size >= 128) cached.delete(cached.keys().next().value!);
      cached.set(key, {
        photos,
        expires: now() + (photos.length ? 3_600_000 : 60_000),
      });
      return photos;
    }).finally(() => pending.delete(key));
    pending.set(key, request);
    return request;
  };
}

export type PublicPhotoIdentity = { id: string; protocol: string };

/** A stable, privacy-safe key.  Only a provider identity and non-sensitive
 * place facts participate; trip/user/title context is intentionally absent. */
export async function publicPhotoCacheKey(identity: PublicPhotoIdentity, pipelineVersion = 1) {
  const value = [identity.protocol.trim().toLowerCase(), identity.id.trim(), pipelineVersion].join("\u001f");
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, "0")).join("");
}

export type DistributedPhotoCacheClaim<T> = { state: "fresh" | "claimed" | "busy"; payload: T[] };

/** Coordinates the durable cache without putting payloads or private context
 * into the client. The RPC implementation owns locking and lease expiry. */
export function createDistributedPhotoCache<T>(deps: {
  claim: (key: string, token: string) => Promise<DistributedPhotoCacheClaim<T>>;
  complete: (key: string, token: string, payload: T[]) => Promise<void>;
  release: (key: string, token: string) => Promise<void>;
}) {
  return async (key: string, load: () => Promise<T[]>): Promise<T[]> => {
    const token = crypto.randomUUID();
    const claim = await deps.claim(key, token);
    if (claim.state !== "claimed") return claim.payload;
    try {
      const payload = await load();
      await deps.complete(key, token, payload);
      return payload;
    } catch (error) {
      await deps.release(key, token).catch(() => undefined);
      throw error;
    }
  };
}
