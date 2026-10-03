import * as Crypto from 'expo-crypto';

export type CollectionEntryKind = 'post' | 'comment' | 'reaction' | 'placeLink';
export type CollectionMetadataState = 'pending' | 'available' | 'unavailable' | 'cancelled';

export interface CollectionEntry {
  id: string;
  kind: CollectionEntryKind;
  postID?: string;
  authorID: string;
  authorName: string;
  createdAt: number;
  updatedAt: number;
  text?: string;
  url?: string;
  canonicalURL?: string;
  displayTitle?: string;
  caption?: string;
  thumbnailURL?: string;
  metadataState?: CollectionMetadataState;
  placeID?: string;
  active?: boolean;
  deleted: boolean;
}

export interface CollectionSyncMetadata {
  serverVersion: number | null;
  mutationToken: string;
  lastErrorCode?: string;
}

const TRACKING_PARAMETERS = new Set(['fbclid', 'gclid', 'igsh', 'igshid']);
const UNIX_EPOCH_SECONDS = 978307200;

export function nowSeconds(): number { return (Date.now() / 1000) - UNIX_EPOCH_SECONDS; }

export function parseCollectionDate(value: unknown, fallback = nowSeconds()): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value > 10_000_000_000 ? value / 1000 - UNIX_EPOCH_SECONDS : value;
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    if (Number.isFinite(parsed)) return parsed / 1000 - UNIX_EPOCH_SECONDS;
  }
  return fallback;
}

export function canonicalizeCollectionURL(raw: string): string | null {
  let parsed: URL;
  try { parsed = new URL(raw.trim()); } catch { return null; }
  const scheme = parsed.protocol.toLowerCase();
  if (scheme !== 'http:' && scheme !== 'https:') return null;
  const host = parsed.hostname.toLowerCase().replace(/^\.+|\.+$/gu, '');
  if (!host) return null;
  const port = (scheme === 'http:' && parsed.port === '80') || (scheme === 'https:' && parsed.port === '443') ? '' : parsed.port;
  let path = parsed.pathname.replace(/\/+/gu, '/');
  if (!path) path = '/';
  if (host === 'tiktok.com' || host.endsWith('.tiktok.com')) {
    const match = path.match(/^\/@[^/]+\/video\/(\d+)(?:\/.*)?$/iu);
    if (match?.[1]) return `https://www.tiktok.com/video/${match[1]}`;
  }
  if (host === 'instagram.com' || host.endsWith('.instagram.com')) {
    const match = path.match(/^\/(p|reel|tv)\/([^/]+)(?:\/.*)?$/iu);
    if (match?.[1] && match[2]) return `https://www.instagram.com/${match[1].toLowerCase()}/${match[2]}`;
  }
  if (path.length > 1) path = `/${path.replace(/^\/+|\/+$/gu, '')}`;
  const params = [...parsed.searchParams.entries()]
    .filter(([name]) => !name.toLowerCase().startsWith('utm_') && !TRACKING_PARAMETERS.has(name.toLowerCase()))
    .sort(([nameA, valueA], [nameB, valueB]) => nameA === nameB ? valueA.localeCompare(valueB) : nameA.localeCompare(nameB));
  const query = params.map(([name, value]) => `${encodeURIComponent(name)}=${encodeURIComponent(value)}`).join('&');
  return `${scheme}//${host}${port ? `:${port}` : ''}${path}${query ? `?${query}` : ''}`;
}

export function neutralCollectionTitle(url: string): string {
  try {
    const host = new URL(url).hostname.toLowerCase().replace(/^www\./u, '');
    if (host.endsWith('tiktok.com')) return 'TikTok-Link';
    if (host.endsWith('instagram.com')) return 'Instagram-Link';
    return host || 'Link';
  } catch { return 'Link'; }
}

export async function sha256(value: string): Promise<string> {
  return Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, value);
}

export async function canonicalPostID(canonicalURL: string): Promise<string> { return `post-${await sha256(canonicalURL)}`; }
export async function reactionID(postID: string, participantID: string): Promise<string> { return `reaction-${await sha256(`${postID}\u001f${participantID}`)}`; }
export async function placeLinkID(postID: string, placeID: string): Promise<string> { return `place-link-${await sha256(`${postID}\u001f${placeID}`)}`; }

export function newUUID(): string { return Crypto.randomUUID(); }

export function decodeCollectionEntry(value: unknown): CollectionEntry | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const raw = value as Record<string, unknown>;
  if (typeof raw.id !== 'string' || !raw.id || !['post', 'comment', 'reaction', 'placeLink'].includes(String(raw.kind))) return null;
  if (typeof raw.authorID !== 'string' || typeof raw.authorName !== 'string') return null;
  const kind = raw.kind as CollectionEntryKind;
  const postID = typeof raw.postID === 'string' ? raw.postID : undefined;
  if ((kind !== 'post' && !postID) || (kind === 'placeLink' && typeof raw.placeID !== 'string')) return null;
  const entry: CollectionEntry = {
    id: raw.id,
    kind,
    postID,
    authorID: raw.authorID,
    authorName: raw.authorName,
    createdAt: parseCollectionDate(raw.createdAt),
    updatedAt: parseCollectionDate(raw.updatedAt, parseCollectionDate(raw.createdAt)),
    text: typeof raw.text === 'string' ? raw.text : undefined,
    url: typeof raw.url === 'string' ? raw.url : undefined,
    canonicalURL: typeof raw.canonicalURL === 'string' ? raw.canonicalURL : undefined,
    displayTitle: typeof raw.displayTitle === 'string' ? raw.displayTitle : undefined,
    caption: typeof raw.caption === 'string' ? raw.caption : undefined,
    thumbnailURL: typeof raw.thumbnailURL === 'string' ? raw.thumbnailURL : undefined,
    metadataState: ['pending', 'available', 'unavailable', 'cancelled'].includes(String(raw.metadataState)) ? raw.metadataState as CollectionMetadataState : undefined,
    placeID: typeof raw.placeID === 'string' ? raw.placeID : undefined,
    active: typeof raw.active === 'boolean' ? raw.active : undefined,
    deleted: raw.deleted === true,
  };
  return entry;
}

export function isVisibleCollectionEntry(entry: CollectionEntry): boolean { return !entry.deleted && (entry.kind !== 'reaction' || entry.active !== false) && (entry.kind !== 'placeLink' || entry.active !== false); }
