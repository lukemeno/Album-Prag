export function createPhotoCache<T>(
  load: (key: string) => Promise<T[]>,
  now = Date.now,
) {
  const cached = new Map<string, { photos: T[]; expires: number }>();
  const pending = new Map<string, Promise<T[]>>();
  return async (key: string): Promise<T[]> => {
    const hit = cached.get(key);
    if (hit && hit.expires > now()) return hit.photos;
    cached.delete(key);
    const active = pending.get(key);
    if (active) return active;
    const request = load(key).then((photos) => {
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
