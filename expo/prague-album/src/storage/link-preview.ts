export interface LinkPreview { title: string; thumbnailURL: string | null; author: string | null; description: string | null; canonicalURL: string; }
export class LinkPreviewError extends Error { constructor(message = 'Die Link-Vorschau ist gerade nicht verfügbar.') { super(message); this.name = 'LinkPreviewError'; } }

function clean(value: string | null | undefined): string | null { const text = value?.replace(/<[^>]+>/gu, '').replace(/\s+/gu, ' ').trim(); return text ? text.slice(0, 500) : null; }
function decode(value: string): string { return value.replace(/&amp;/gu, '&').replace(/&quot;/gu, '"').replace(/&#39;/gu, "'").replace(/&lt;/gu, '<').replace(/&gt;/gu, '>'); }
function validURL(value: string | null, base?: string): string | null { if (!value) return null; try { const url = new URL(value, base); return url.protocol === 'http:' || url.protocol === 'https:' ? url.toString() : null; } catch { return null; } }
function meta(html: string, key: string): string | null {
  for (const tag of html.match(/<meta\b[^>]*>/giu) ?? []) {
    const attributes: Record<string, string> = {};
    for (const match of tag.matchAll(/([\w:-]+)\s*=\s*(["'])(.*?)\2/gsu)) attributes[match[1].toLowerCase()] = match[3];
    const name = attributes.property ?? attributes.name ?? attributes.itemprop;
    if (name?.toLowerCase() === key.toLowerCase()) return clean(decode(attributes.content ?? ''));
  }
  return null;
}
function parseHTML(html: string, canonicalURL: string): LinkPreview | null { const title = meta(html, 'og:title') ?? meta(html, 'twitter:title') ?? clean(html.match(/<title[^>]*>(.*?)<\/title>/isu)?.[1]); const image = validURL(meta(html, 'og:image') ?? meta(html, 'twitter:image'), canonicalURL); const description = meta(html, 'og:description') ?? meta(html, 'description'); const author = meta(html, 'author') ?? meta(html, 'twitter:creator'); if (!title && !image && !description) return null; return { title: title ?? '', thumbnailURL: image, author, description, canonicalURL }; }
function shortTitle(value: string): string { const first = value.split(/[.!?]/u)[0].trim(); return first.slice(0, 100).trim(); }

async function readBounded(response: Response, maxBytes: number): Promise<Uint8Array> {
  const length = Number(response.headers.get('content-length') ?? '');
  if (Number.isFinite(length) && length > maxBytes) throw new LinkPreviewError();
  const reader = response.body?.getReader();
  if (!reader) {
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.byteLength > maxBytes) throw new LinkPreviewError();
    return bytes;
  }
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const next = await reader.read();
    if (next.done) break;
    total += next.value.byteLength;
    if (total > maxBytes) { await reader.cancel(); throw new LinkPreviewError(); }
    chunks.push(next.value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return bytes;
}

async function fetchBounded(url: string, signal?: AbortSignal): Promise<{ text: string; url: string }> {
  if (signal?.aborted) throw new LinkPreviewError('Link-Vorschau abgebrochen.');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12_000);
  const abort = () => controller.abort(); signal?.addEventListener('abort', abort, { once: true });
  try {
    const response = await fetch(url, { headers: { Accept: 'text/html,application/xhtml+xml,application/json', 'User-Agent': 'PragueAlbum/1.0' }, signal: controller.signal });
    if (!response.ok) throw new LinkPreviewError();
    const bytes = await readBounded(response, 2_000_000);
    return { text: new TextDecoder().decode(bytes), url: response.url || url };
  } catch (error) { if (error instanceof LinkPreviewError) throw error; if (error instanceof Error && error.name === 'AbortError') throw new LinkPreviewError('Die Link-Vorschau hat zu lange gedauert.'); throw new LinkPreviewError(); }
  finally { clearTimeout(timer); signal?.removeEventListener('abort', abort); }
}

function blockedTitle(value: string | null | undefined): boolean { return /(?:video|page|content)\s+(?:is\s+)?(?:unavailable|not\s+available|not\s+found|blocked)|this\s+video\s+is\s+unavailable|just\s+a\s+moment|access\s+denied|verify\s+you\s+are\s+human/iu.test(value ?? ''); }
async function tiktokOEmbed(url: string, signal?: AbortSignal): Promise<LinkPreview | null> {
  try {
    const response = await fetchBounded(`https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`, signal);
    const json = JSON.parse(response.text) as { title?: string; thumbnail_url?: string; author_name?: string };
    if (blockedTitle(json.title)) return null;
    if (json.title || json.thumbnail_url) return { title: shortTitle(json.title ?? ''), thumbnailURL: validURL(json.thumbnail_url ?? null), author: clean(json.author_name), description: clean(json.title), canonicalURL: url };
  } catch { /* HTML fallback below */ }
  return null;
}

export async function previewLink(rawURL: string, signal?: AbortSignal): Promise<LinkPreview> {
  const original = validURL(rawURL.trim());
  if (!original) throw new LinkPreviewError('Der Link muss mit http:// oder https:// beginnen.');
  if (signal?.aborted) throw new LinkPreviewError('Link-Vorschau abgebrochen.');
  const host = new URL(original).hostname.toLowerCase();
  const isTikTok = host === 'tiktok.com' || host.endsWith('.tiktok.com');
  if (isTikTok) {
    const embedded = await tiktokOEmbed(original, signal);
    if (embedded) return embedded;
  }
  const response = await fetchBounded(original, signal);
  if (isTikTok && response.url !== original) {
    const redirectedHost = new URL(response.url).hostname.toLowerCase();
    if (redirectedHost === 'tiktok.com' || redirectedHost.endsWith('.tiktok.com')) {
      const embedded = await tiktokOEmbed(response.url, signal);
      if (embedded) return embedded;
    }
  }
  const result = parseHTML(response.text, response.url);
  if (!result || blockedTitle(result.title)) throw new LinkPreviewError();
  return { ...result, title: shortTitle(result.title), canonicalURL: result.canonicalURL || original };
}

export function applyLinkPreview(preview: LinkPreview, draft: { title: string; note: string; sourceURL: string; image: Record<string, unknown> | null }): void {
  const title = draft.title.trim();
  if (!title && preview.title) draft.title = preview.title;
  if (!draft.note.trim() && preview.description) draft.note = preview.author ? `${preview.author}: ${preview.description}` : preview.description;
  if (!draft.image && preview.thumbnailURL) draft.image = { linkPreview: { pageURL: preview.canonicalURL || draft.sourceURL, thumbnailURL: preview.thumbnailURL, credit: preview.author } };
}
