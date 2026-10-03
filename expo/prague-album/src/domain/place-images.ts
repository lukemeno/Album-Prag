import type { Place } from '@/domain/place';

export type GeneratedSource = 'lookAround' | 'mapSnapshot';
export type ImageProvider = 'sourcePreview' | 'wikimedia' | 'tripadvisor' | 'legacy';

export interface ResolvedPlaceIdentity { title: string; latitude: number; longitude: number; category?: string; address?: string; }
export interface ExternalPlaceImage { imageURL: string; sourceURL: string; credit: string; provider: ImageProvider; licenseName?: string; licenseURL?: string; providerPlaceID?: string; resolvedFor?: ResolvedPlaceIdentity; ranking?: number; userSelected?: boolean; }
export interface UploadedPlaceImage { id: string; storagePath?: string | null; pixelWidth: number; pixelHeight: number; resolvedFor?: ResolvedPlaceIdentity; generatedSource?: GeneratedSource; }
export interface LinkPreviewImage { pageURL: string; thumbnailURL?: string | null; credit?: string | null; }
export type PlaceImageAsset = { uploaded: UploadedPlaceImage } | { external: ExternalPlaceImage } | { linkPreview: LinkPreviewImage } | { bundled: { name: string } };

function associated(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  if (record._0 && typeof record._0 === 'object' && !Array.isArray(record._0)) return record._0 as Record<string, unknown>;
  return record;
}
function imageProvider(value: unknown): ImageProvider { return value === 'sourcePreview' || value === 'wikimedia' || value === 'tripadvisor' || value === 'legacy' ? value : 'legacy'; }
export function imageAsset(value: Record<string, unknown> | null): PlaceImageAsset | null {
  if (!value || typeof value !== 'object') return null;
  if (value.uploaded && typeof value.uploaded === 'object') {
    const raw = associated(value.uploaded);
    if (!raw || typeof raw.id !== 'string' || !raw.id.trim()) return null;
    return { uploaded: raw as unknown as UploadedPlaceImage };
  }
  if (value.external && typeof value.external === 'object') {
    const raw = associated(value.external);
    if (!raw || typeof raw.imageURL !== 'string' || !raw.imageURL || typeof raw.sourceURL !== 'string' || !raw.sourceURL) return null;
    return { external: { ...raw, credit: typeof raw.credit === 'string' ? raw.credit : 'Bildquelle', provider: imageProvider(raw.provider) } as unknown as ExternalPlaceImage };
  }
  if (value.linkPreview && typeof value.linkPreview === 'object') {
    const raw = value.linkPreview as Record<string, unknown>;
    if (typeof raw.pageURL !== 'string' || !raw.pageURL) return null;
    return { linkPreview: raw as unknown as LinkPreviewImage };
  }
  if (value.bundled && typeof value.bundled === 'object') {
    const raw = associated(value.bundled);
    if (!raw || typeof raw.name !== 'string' || !raw.name) return null;
    return { bundled: { name: raw.name } };
  }
  return null;
}

export function assetJSON(asset: PlaceImageAsset | null): Record<string, unknown> | null {
  if (!asset) return null;
  if ('uploaded' in asset) return { uploaded: { _0: asset.uploaded } };
  if ('external' in asset) return { external: { _0: asset.external } };
  if ('bundled' in asset) return { bundled: asset.bundled };
  return { linkPreview: asset.linkPreview };
}
export function uploadedAsset(value: Place['image']): UploadedPlaceImage | null { const asset = imageAsset(value); return asset && 'uploaded' in asset ? asset.uploaded : null; }
export function externalAsset(value: Place['image']): ExternalPlaceImage | null { const asset = imageAsset(value); return asset && 'external' in asset ? asset.external : null; }
export function isUserSelected(value: Place['image']): boolean {
  const asset = imageAsset(value);
  return Boolean(asset && ('external' in asset ? asset.external.userSelected : 'uploaded' in asset ? !asset.uploaded.generatedSource && !asset.uploaded.resolvedFor : false));
}
export function resolvedMatches(asset: PlaceImageAsset | null, place: Pick<Place, 'title' | 'category' | 'address' | 'lat' | 'lng'>): boolean {
  const resolved = asset && ('external' in asset ? asset.external.resolvedFor : 'uploaded' in asset ? asset.uploaded.resolvedFor : undefined);
  if (!resolved || typeof place.lat !== 'number' || typeof place.lng !== 'number') return false;
  return resolved.title.localeCompare(place.title, 'de', { sensitivity: 'base' }) === 0 && Math.abs(resolved.latitude - place.lat) < 0.0001 && Math.abs(resolved.longitude - place.lng) < 0.0001 && (!resolved.category || resolved.category === place.category) && (!resolved.address || resolved.address === place.address);
}
export function locationMoved(oldLat: number | null | undefined, oldLng: number | null | undefined, lat: number, lng: number): boolean { return typeof oldLat === 'number' && typeof oldLng === 'number' && (Math.abs(oldLat - lat) > 0.0001 || Math.abs(oldLng - lng) > 0.0001); }
export function shouldDiscardOnMove(value: Place['image']): boolean { const asset = imageAsset(value); return Boolean(asset && ('external' in asset ? asset.external.userSelected !== true : 'uploaded' in asset && asset.uploaded.resolvedFor)); }
export function sourceURL(value: Place['image']): string | null { const asset = imageAsset(value); return asset && ('external' in asset ? asset.external.sourceURL : 'linkPreview' in asset ? asset.linkPreview.pageURL : null); }
export function imageRemoteURL(value: Place['image']): string | null { const asset = imageAsset(value); return asset && ('external' in asset ? asset.external.imageURL : 'linkPreview' in asset ? asset.linkPreview.thumbnailURL ?? null : null); }
