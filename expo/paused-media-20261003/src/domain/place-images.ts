import type { Place } from '@/domain/place';

export type GeneratedSource = 'lookAround' | 'mapSnapshot';
export type ImageProvider = 'sourcePreview' | 'wikimedia' | 'tripadvisor' | 'legacy';

export interface ResolvedPlaceIdentity { title: string; latitude: number; longitude: number; category?: string; address?: string; }
export interface ExternalPlaceImage { imageURL: string; sourceURL: string; credit: string; provider: ImageProvider; licenseName?: string; licenseURL?: string; providerPlaceID?: string; resolvedFor?: ResolvedPlaceIdentity; ranking?: number; userSelected?: boolean; }
export interface UploadedPlaceImage { id: string; storagePath?: string | null; pixelWidth: number; pixelHeight: number; resolvedFor?: ResolvedPlaceIdentity; generatedSource?: GeneratedSource; }
export interface LinkPreviewImage { pageURL: string; thumbnailURL?: string | null; credit?: string | null; }
export type PlaceImageAsset = { uploaded: UploadedPlaceImage } | { external: ExternalPlaceImage } | { linkPreview: LinkPreviewImage } | { bundled: { name: string } };

export function imageAsset(value: Record<string, unknown> | null): PlaceImageAsset | null {
  if (!value || typeof value !== 'object') return null;
  if (value.uploaded && typeof value.uploaded === 'object') return { uploaded: value.uploaded as UploadedPlaceImage };
  if (value.external && typeof value.external === 'object') return { external: value.external as ExternalPlaceImage };
  if (value.linkPreview && typeof value.linkPreview === 'object') return { linkPreview: value.linkPreview as LinkPreviewImage };
  if (value.bundled && typeof value.bundled === 'object') return { bundled: value.bundled as { name: string } };
  return null;
}

export function assetJSON(asset: PlaceImageAsset | null): Record<string, unknown> | null { return asset as unknown as Record<string, unknown> | null; }
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
export function shouldDiscardOnMove(value: Place['image']): boolean { const asset = imageAsset(value); return Boolean(asset && ('external' in asset || ('uploaded' in asset && asset.uploaded.resolvedFor))); }
export function sourceURL(value: Place['image']): string | null { const asset = imageAsset(value); return asset && ('external' in asset ? asset.external.sourceURL : 'linkPreview' in asset ? asset.linkPreview.pageURL : null); }
export function imageRemoteURL(value: Place['image']): string | null { const asset = imageAsset(value); return asset && ('external' in asset ? asset.external.imageURL : 'linkPreview' in asset ? asset.linkPreview.thumbnailURL ?? null : null); }
