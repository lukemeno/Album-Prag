import { useCallback, useEffect, useRef, useState } from 'react';
import * as Location from 'expo-location';
import { useSQLiteContext } from 'expo-sqlite';
import type { AssistantDay, AssistantMessage, AssistantReply } from '@/domain/assistant';
import { AssistantError, createUUID, normalizeAssistantError, parseAssistantReply, placeFingerprint } from '@/domain/assistant';
import { buildAssistantContext } from '@/storage/assistant-context';
import { applyAssistantPlan, saveAssistantSuggestion, undoAssistantPlan, type AssistantRequestFingerprint, type AssistantUndoRecord } from '@/storage/assistant-actions';
import { sendAssistantRequest } from '@/storage/assistant-service';
import { usePlaceStore } from '@/storage/place-store';
import { useTripSync } from '@/storage/trip-sync';

interface PersistedAssistantState { messages: AssistantMessage[]; preferences: string[]; webSearch?: boolean; }
interface ActionState { fingerprint: AssistantRequestFingerprint; undo?: AssistantUndoRecord; applied: boolean; }

export function useAssistant() {
  const db = useSQLiteContext();
  const { memberName, reload } = usePlaceStore();
  const { tripID, syncNow } = useTripSync();
  const [albumKey, setAlbumKey] = useState<string | null>(null);
  const [messages, setMessages] = useState<AssistantMessage[]>([]);
  const [preferences, setPreferences] = useState<string[]>([]);
  const [webSearch, setWebSearch] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [lastError, setLastError] = useState<string | null>(null);
  const [lastUserText, setLastUserText] = useState('');
  const [location, setLocation] = useState<{ latitude: number; longitude: number } | null>(null);
  const [locationStatus, setLocationStatus] = useState<string | null>(null);
  const [actionRevision, setActionRevision] = useState(0);
  const mounted = useRef(true);
  const messagesRef = useRef(messages);
  const preferencesRef = useRef(preferences);
  const webSearchRef = useRef(webSearch);
  const requestRef = useRef<{ token: string; controller: AbortController } | null>(null);
  const locationRequest = useRef(0);
  const writeQueue = useRef(Promise.resolve());
  const actions = useRef(new Map<string, ActionState>());
  useEffect(() => { messagesRef.current = messages; }, [messages]);
  useEffect(() => { preferencesRef.current = preferences; }, [preferences]);
  useEffect(() => { webSearchRef.current = webSearch; }, [webSearch]);

  const persist = useCallback((nextMessages: AssistantMessage[], nextPreferences: string[], nextWebSearch: boolean) => {
    if (!albumKey) return;
    const payload: PersistedAssistantState = { messages: nextMessages.slice(-100), preferences: nextPreferences.slice(0, 20), webSearch: nextWebSearch };
    writeQueue.current = writeQueue.current.catch(() => undefined).then(() => db.runAsync('INSERT OR REPLACE INTO album_settings (key,value) VALUES (?,?)', [albumKey, JSON.stringify(payload)])).then(() => undefined).catch(() => { if (mounted.current) setLastError('Der lokale Verlauf konnte nicht gespeichert werden.'); });
  }, [albumKey, db]);

  useEffect(() => {
    let active = true;
    mounted.current = true;
    void (async () => {
      const settings = await db.getAllAsync<{ key: string; value: string }>("SELECT key,value FROM album_settings WHERE key IN ('albumID','tripID')");
      const values = Object.fromEntries(settings.map((setting) => [setting.key, setting.value]));
      const id = (values.albumID || values.tripID || 'default').replace(/[^a-zA-Z0-9_-]/gu, '_');
      const key = `assistant:${id}`;
      const saved = await db.getFirstAsync<{ value: string }>('SELECT value FROM album_settings WHERE key = ?', [key]);
      if (!active) return;
      if (saved?.value) {
        try {
          const parsed = JSON.parse(saved.value) as PersistedAssistantState;
          const loadedMessages = Array.isArray(parsed.messages) ? parsed.messages.flatMap((item): AssistantMessage[] => {
            if (!item || typeof item !== 'object') return [];
            const candidate = item as Partial<AssistantMessage> & { reply?: unknown };
            if ((candidate.role !== 'user' && candidate.role !== 'assistant') || typeof candidate.text !== 'string' || typeof candidate.id !== 'string') return [];
            let reply: AssistantReply | undefined;
            if (candidate.reply !== undefined) { try { reply = parseAssistantReply(candidate.reply); } catch { return []; } }
            return [{ id: candidate.id, role: candidate.role, text: candidate.text.slice(0, 4_000), createdAt: typeof candidate.createdAt === 'number' ? candidate.createdAt : Date.now(), ...(reply ? { reply } : {}) }];
          }).slice(-100) : [];
          const loadedPreferences = Array.isArray(parsed.preferences) ? parsed.preferences.filter((item): item is string => typeof item === 'string').slice(0, 20) : [];
          messagesRef.current = loadedMessages;
          preferencesRef.current = loadedPreferences;
          webSearchRef.current = parsed.webSearch === true;
          setMessages(loadedMessages); setPreferences(loadedPreferences); setWebSearch(parsed.webSearch === true);
        } catch { /* A corrupt local enhancement must not block the trip. */ }
      }
      setAlbumKey(key);
    })().catch(() => { if (active) setAlbumKey('assistant:default'); });
    return () => { active = false; mounted.current = false; requestRef.current?.controller.abort(); requestRef.current = null; };
  }, [db]);

  const send = useCallback(async (rawText: string) => {
    const text = rawText.trim();
    if (!text || isLoading || requestRef.current || !albumKey) return;
    const userMessage: AssistantMessage = { id: createUUID(), role: 'user', text: text.slice(0, 4_000), createdAt: Date.now() };
    const nextMessages = [...messagesRef.current, userMessage].slice(-100);
    messagesRef.current = nextMessages;
    setMessages(nextMessages); setLastUserText(text); setLastError(null); setIsLoading(true);
    persist(nextMessages, preferencesRef.current, webSearchRef.current);
    const token = createUUID();
    const controller = new AbortController();
    requestRef.current = { token, controller };
    try {
      // A shared trip is refreshed before its IDs are allowed into assistant context.
      if (tripID) { const synced = await syncNow(); if (synced === false) throw new AssistantError('Die gemeinsame Reise konnte vor der Anfrage nicht abgeglichen werden.'); }
      const contextResult = await buildAssistantContext(db, text, tripID);
      if (!mounted.current || requestRef.current?.token !== token) return;
      const history = messagesRef.current.slice(0, -1).slice(-12).map((message) => ({ role: message.role, text: message.text.slice(0, 1_300) }));
      const reply = await sendAssistantRequest({ request_id: token, trip_id: tripID, message: text.slice(0, 4_000), history, context: contextResult.context, preferences: preferencesRef.current, location, web_search: webSearchRef.current }, controller.signal);
      if (!mounted.current || requestRef.current?.token !== token) return;
      const assistantMessage: AssistantMessage = { id: createUUID(), role: 'assistant', text: reply.answer, reply, createdAt: Date.now() };
      const withReply = [...messagesRef.current, assistantMessage].slice(-100);
      messagesRef.current = withReply;
      actions.current.set(assistantMessage.id, { fingerprint: { trip: contextResult.tripFingerprint, albumID: contextResult.albumID, tripID: contextResult.tripID, places: Object.fromEntries(contextResult.fingerprintPlaces.map((place) => [place.id, placeFingerprint(place)])) }, applied: false });
      setMessages(withReply); setLastError(null); persist(withReply, preferencesRef.current, webSearchRef.current);
    } catch (error) {
      if (!mounted.current || requestRef.current?.token !== token) return;
      setLastError(normalizeAssistantError(error));
    } finally {
      if (mounted.current && requestRef.current?.token === token) { requestRef.current = null; setIsLoading(false); }
    }
  }, [albumKey, db, isLoading, location, persist, syncNow, tripID]);

  const cancel = useCallback(() => {
    requestRef.current?.controller.abort(); requestRef.current = null;
    setIsLoading(false); setLastError('Anfrage abgebrochen.');
  }, []);

  const retry = useCallback(() => { if (lastUserText && !isLoading) void send(lastUserText); }, [isLoading, lastUserText, send]);

  const clear = useCallback(() => {
    cancel(); messagesRef.current = []; preferencesRef.current = []; actions.current.clear();
    webSearchRef.current = false; setMessages([]); setPreferences([]); setLastUserText(''); setLastError(null); setWebSearch(false); persist([], [], false);
  }, [cancel, persist]);

  const remember = useCallback((value: string) => {
    const preference = value.trim();
    if (!preference || preferencesRef.current.includes(preference)) return;
    const next = [...preferencesRef.current, preference].slice(0, 20); preferencesRef.current = next; setPreferences(next); persist(messagesRef.current, next, webSearchRef.current);
  }, [persist]);

  const forget = useCallback((value: string) => {
    const next = preferencesRef.current.filter((item) => item !== value); preferencesRef.current = next; setPreferences(next); persist(messagesRef.current, next, webSearchRef.current);
  }, [persist]);

  const requestLocation = useCallback(async () => {
    const requestID = ++locationRequest.current;
    setLocationStatus(null);
    try {
      const permission = await Location.requestForegroundPermissionsAsync();
      if (!mounted.current || locationRequest.current !== requestID) return;
      if (permission.status !== Location.PermissionStatus.GRANTED) { setLocation(null); setLocationStatus('Standortzugriff wurde abgelehnt.'); return; }
      const timeout = new Promise<never>((_, reject) => { setTimeout(() => reject(new Error('timeout')), 9_000); });
      const current = await Promise.race([Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced }), timeout]);
      if (!mounted.current || locationRequest.current !== requestID) return;
      setLocation({ latitude: current.coords.latitude, longitude: current.coords.longitude }); setLocationStatus('Standort für die nächste Anfrage bereit.');
    } catch {
      if (!mounted.current || locationRequest.current !== requestID) return;
      setLocation(null); setLocationStatus('Der aktuelle Standort konnte nicht gelesen werden.');
    }
  }, []);

  const saveSuggestion = useCallback(async (suggestion: AssistantReply['places'][number]) => {
    const result = await saveAssistantSuggestion(db, suggestion, memberName);
    await reload();
    if (tripID) void syncNow();
    return result;
  }, [db, memberName, reload, syncNow, tripID]);

  const applyPlan = useCallback(async (messageID: string, plan: AssistantDay[]) => {
    const action = actions.current.get(messageID);
    if (!action) throw new AssistantError('Für diese Antwort gibt es keinen überprüfbaren Plan.');
    if (action.applied) throw new AssistantError('Diesen Plan hast du bereits übernommen. Nutze zuerst Rückgängig.');
    if (tripID) { const synced = await syncNow(); if (synced === false) throw new AssistantError('Die gemeinsame Reise konnte vor dem Anwenden nicht abgeglichen werden.'); }
    action.undo = await applyAssistantPlan(db, plan, action.fingerprint);
    action.applied = true;
    if (!action.undo.assignments.length) action.undo = undefined;
    await reload();
    if (tripID) void syncNow();
    setActionRevision((revision) => revision + 1);
  }, [db, reload, syncNow, tripID]);

  const canUndo = (messageID: string) => Boolean(actions.current.get(messageID)?.undo);
  const undo = useCallback(async (messageID: string) => {
    const action = actions.current.get(messageID);
    if (!action?.undo) throw new AssistantError('Für diese Antwort gibt es keine Rücknahme.');
    if (tripID) { const synced = await syncNow(); if (synced === false) throw new AssistantError('Die gemeinsame Reise konnte vor der Rücknahme nicht abgeglichen werden.'); }
    await undoAssistantPlan(db, action.undo); action.undo = undefined; action.applied = false; await reload(); if (tripID) void syncNow(); setActionRevision((revision) => revision + 1);
  }, [db, reload, syncNow, tripID]);

  const setWebSearchAndPersist = useCallback((enabled: boolean) => {
    webSearchRef.current = enabled;
    setWebSearch(enabled);
    persist(messagesRef.current, preferencesRef.current, enabled);
  }, [persist]);

  return { messages, preferences, webSearch, setWebSearch: setWebSearchAndPersist, isLoading, lastError, location, locationStatus, revision: actionRevision, send, retry, cancel, clear, remember, forget, requestLocation, saveSuggestion, applyPlan, canUndo, undo };
}
