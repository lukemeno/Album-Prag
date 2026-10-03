import { supabase } from '@/storage/supabase';
import { AssistantError, type AssistantRequest, type AssistantReply, normalizeAssistantError, parseAssistantReply, utf8Bytes } from '@/domain/assistant';

const MAX_MESSAGE_CHARS = 4_000;
const MAX_HISTORY_ITEMS = 12;
const MAX_HISTORY_CHARS = 16_000;
const MAX_CONTEXT_BYTES = 40_000;
const MAX_BODY_BYTES = 80_000;

function boundRequest(request: AssistantRequest): AssistantRequest {
  let historyChars = 0;
  const history = request.history.slice(-MAX_HISTORY_ITEMS).reverse().flatMap((item) => {
    const text = item.text.slice(0, 1_300);
    if (historyChars + text.length > MAX_HISTORY_CHARS) return [];
    historyChars += text.length;
    return [{ role: item.role, text }];
  }).reverse();
  const context = request.context;
  if (utf8Bytes(context) > MAX_CONTEXT_BYTES) throw new AssistantError('Der Kontext ist zu groß. Bitte frage mit weniger Details erneut.');
  const bounded = {
    ...request,
    message: request.message.slice(0, MAX_MESSAGE_CHARS),
    history,
    context,
    preferences: request.preferences.slice(0, 20).map((preference) => preference.slice(0, 200)),
  };
  if (utf8Bytes(bounded) > MAX_BODY_BYTES) throw new AssistantError('Die Anfrage ist zu groß. Bitte frage mit weniger Details erneut.');
  return bounded;
}

function apiMessage(status: number, body: unknown): string {
  const value = body && typeof body === 'object' && !Array.isArray(body) ? body as Record<string, unknown> : null;
  const code = typeof value?.code === 'string' ? value.code : '';
  if (code === 'billing_required' || code === 'credit_balance_exhausted') return 'Für den Assistenten fehlt noch OpenAI-Guthaben.';
  if (code === 'invalid_request' || code === 'invalid_context') return 'Die Anfrage enthält zu viel oder ungültigen Kontext.';
  if (code === 'forbidden_trip') return 'Der Zugriff auf diese gemeinsame Reise ist nicht möglich.';
  if (status === 401 || status === 403) return 'Der Zugriff auf den Reise-Assistenten ist nicht möglich.';
  if (status === 429) return 'Der Reise-Assistent ist gerade ausgelastet. Bitte versuche es gleich noch einmal.';
  return 'Die Anfrage konnte nicht verarbeitet werden.';
}

export async function sendAssistantRequest(input: AssistantRequest, signal?: AbortSignal): Promise<AssistantReply> {
  if (!supabase) throw new AssistantError('Der Reise-Assistent ist in dieser Expo-Installation nicht eingerichtet.');
  if (signal?.aborted) throw new AssistantError('Anfrage abgebrochen.');
  const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
  if (sessionError) throw new AssistantError('Die Anmeldung für den Reise-Assistenten ist fehlgeschlagen.');
  if (!sessionData.session) {
    const anonymous = await supabase.auth.signInAnonymously();
    if (anonymous.error) throw new AssistantError('Die Anmeldung für den Reise-Assistenten ist fehlgeschlagen.');
  }
  if (signal?.aborted) throw new AssistantError('Anfrage abgebrochen.');
  const { data: freshSession, error: freshError } = await supabase.auth.getSession();
  if (freshError || !freshSession.session) throw new AssistantError('Die Anmeldung für den Reise-Assistenten ist fehlgeschlagen.');
  const endpoint = process.env.EXPO_PUBLIC_SUPABASE_URL;
  if (!endpoint) throw new AssistantError('Der Reise-Assistent ist in dieser Expo-Installation nicht eingerichtet.');

  const controller = new AbortController();
  if (signal?.aborted) controller.abort();
  const timer = setTimeout(() => controller.abort(), 60_000);
  const onAbort = () => controller.abort();
  signal?.addEventListener('abort', onAbort, { once: true });
  try {
    const response = await fetch(`${endpoint.replace(/\/$/u, '')}/functions/v1/assistant-chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${freshSession.session.access_token}` },
      body: JSON.stringify(boundRequest(input)),
      signal: controller.signal,
    });
    const body: unknown = await response.json().catch(() => null);
    if (!response.ok) throw new AssistantError(apiMessage(response.status, body));
    try {
      return parseAssistantReply(body);
    } catch (error) {
      throw error instanceof AssistantError ? error : new AssistantError('Die Antwort konnte nicht gelesen werden.');
    }
  } catch (error) {
    if (error instanceof AssistantError) throw error;
    if (error instanceof Error && error.name === 'AbortError') throw new AssistantError(signal?.aborted ? 'Anfrage abgebrochen.' : 'Zeitüberschreitung beim Reise-Assistenten.');
    throw new AssistantError(normalizeAssistantError(error));
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener('abort', onAbort);
  }
}
