import type { Place } from '@/domain/place';
import * as Crypto from 'expo-crypto';

export type AssistantRole = 'user' | 'assistant';

export interface AssistantMessage {
  id: string;
  role: AssistantRole;
  text: string;
  reply?: AssistantReply;
  createdAt: number;
}

export interface AssistantSource {
  title: string;
  url: string | null;
  document_id: string | null;
  quote: string | null;
}

export interface AssistantSuggestion {
  existing_id: string | null;
  title: string;
  address: string;
  query: string;
  source_url: string | null;
}

export interface AssistantDay {
  day: number;
  place_ids: string[];
  note: string;
}

export interface AssistantReply {
  answer: string;
  sources: AssistantSource[];
  places: AssistantSuggestion[];
  plan: AssistantDay[];
  preferences: string[];
  usage?: { used_usd: number; limit_usd: number; remaining_requests: number };
}

export interface AssistantContextPlace {
  id: string;
  title: string;
  note: string;
  category: string;
  address: string;
  lat: number | null;
  lng: number | null;
  day: number | null;
  franked: boolean;
  opening_hours: string;
}

export interface AssistantContext {
  trip: Record<string, unknown>;
  places: AssistantContextPlace[];
  documents: { id: string; name: string; text: string }[];
  collection: { id: string; text: string; url: string | null }[];
}

export interface AssistantRequest {
  request_id: string;
  trip_id: string | null;
  message: string;
  history: { role: AssistantRole; text: string }[];
  context: AssistantContext;
  preferences: string[];
  location: { latitude: number; longitude: number } | null;
  web_search: boolean;
}

export function createUUID(): string {
  return Crypto.randomUUID();
}

export function isHTTPURL(value: string | null | undefined): value is string {
  if (!value) return false;
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
}

export function utf8Bytes(value: unknown): number {
  const serialized = JSON.stringify(value);
  if (typeof TextEncoder !== 'undefined') return new TextEncoder().encode(serialized).byteLength;
  return encodeURIComponent(serialized).replace(/%[0-9A-F]{2}|./gu, 'x').length;
}

export function normalizeAssistantError(error: unknown): string {
  if (error instanceof AssistantError) return error.message;
  if (error instanceof Error && error.name === 'AbortError') return 'Anfrage abgebrochen.';
  return 'Der Reise-Assistent ist gerade nicht erreichbar.';
}

export class AssistantError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AssistantError';
  }
}

function objectValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

/** Strict enough to keep malformed provider output out of the rendered UI. */
export function parseAssistantReply(value: unknown): AssistantReply {
  const root = objectValue(value);
  if (!root || typeof root.answer !== 'string' || !Array.isArray(root.sources) || !Array.isArray(root.places) || !Array.isArray(root.plan) || !Array.isArray(root.preferences)) {
    throw new AssistantError('Die Antwort konnte nicht gelesen werden.');
  }
  const sources: AssistantSource[] = [];
  for (const item of root.sources) {
    const row = objectValue(item);
    if (!row || typeof row.title !== 'string' || (row.url !== null && typeof row.url !== 'string') || (row.document_id !== null && typeof row.document_id !== 'string') || (row.quote !== null && typeof row.quote !== 'string')) {
      throw new AssistantError('Die Antwort konnte nicht gelesen werden.');
    }
    const url = row.url === null ? null : (isHTTPURL(row.url) ? row.url : null);
    sources.push({ title: row.title, url, document_id: row.document_id as string | null, quote: row.quote as string | null });
  }
  const places: AssistantSuggestion[] = [];
  for (const item of root.places) {
    const row = objectValue(item);
    if (!row || typeof row.title !== 'string' || typeof row.address !== 'string' || typeof row.query !== 'string' || (row.existing_id !== null && typeof row.existing_id !== 'string') || (row.source_url !== null && typeof row.source_url !== 'string')) {
      throw new AssistantError('Die Antwort konnte nicht gelesen werden.');
    }
    places.push({ existing_id: row.existing_id as string | null, title: row.title, address: row.address, query: row.query, source_url: isHTTPURL(row.source_url as string | null) ? row.source_url as string : null });
  }
  const plan: AssistantDay[] = [];
  for (const item of root.plan) {
    const row = objectValue(item);
    if (!row || typeof row.day !== 'number' || !Number.isInteger(row.day) || !Array.isArray(row.place_ids) || !row.place_ids.every((id) => typeof id === 'string') || typeof row.note !== 'string') {
      throw new AssistantError('Die Antwort konnte nicht gelesen werden.');
    }
    plan.push({ day: row.day, place_ids: row.place_ids as string[], note: row.note });
  }
  if (!root.preferences.every((item) => typeof item === 'string')) throw new AssistantError('Die Antwort konnte nicht gelesen werden.');
  let usage: AssistantReply['usage'];
  if (root.usage !== undefined) {
    const row = objectValue(root.usage);
    if (!row || typeof row.used_usd !== 'number' || typeof row.limit_usd !== 'number' || typeof row.remaining_requests !== 'number') throw new AssistantError('Die Antwort konnte nicht gelesen werden.');
    usage = { used_usd: row.used_usd, limit_usd: row.limit_usd, remaining_requests: row.remaining_requests };
  }
  return { answer: root.answer, sources, places, plan, preferences: root.preferences as string[], usage };
}

export function relevantDocumentExcerpt(text: string, message: string): string {
  const clean = text.trim();
  if (!clean) return '';
  const keywords = message.toLocaleLowerCase('de-DE').split(/[^\p{L}\p{N}]+/u).filter((word) => word.length > 3);
  const hit = keywords.find((word) => clean.toLocaleLowerCase('de-DE').includes(word));
  if (!hit) return clean.slice(0, 1500);
  const lower = clean.toLocaleLowerCase('de-DE');
  const at = lower.indexOf(hit);
  const start = Math.max(0, at - 700);
  const end = Math.min(clean.length, at + hit.length + 800);
  return clean.slice(start, end).slice(0, 1500);
}

export function placeFingerprint(place: Pick<Place, 'id' | 'title' | 'address' | 'lat' | 'lng' | 'franked' | 'deleted' | 'day' | 'dayOrder' | 'updatedAt'>): string {
  return JSON.stringify({ id: place.id, title: place.title, address: place.address, lat: place.lat ?? null, lng: place.lng ?? null, franked: place.franked, deleted: place.deleted, day: place.day, dayOrder: place.dayOrder, updatedAt: place.updatedAt });
}
