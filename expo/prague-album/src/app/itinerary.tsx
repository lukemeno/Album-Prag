import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Switch, Text, View } from 'react-native';
import { Stack } from 'expo-router';
import { colors, space } from '@/domain/theme';
import { ITINERARY_DAYS, routeLength, visitMinutes, walkingMinutes } from '@/domain/itinerary';
import { applyItineraryPlan, ItineraryActionError, readItineraryPreview, undoItineraryPlan, type ItineraryPreview, type ItineraryUndoRecord } from '@/storage/itinerary-actions';
import { useSQLiteContext } from 'expo-sqlite';
import { usePlaceStore } from '@/storage/place-store';
import { useTripSync } from '@/storage/trip-sync';
import { refreshOpeningHours } from '@/storage/opening-hours-service';

const leftOverText: Record<string, string> = { missing_coordinates: 'ohne Kartenposition', closed: 'an keinem Reisetag geöffnet', capacity: 'passt wegen Zeit oder Kapazität nicht mehr hinein' };

export default function ItineraryScreen() {
  const db = useSQLiteContext();
  const { reload } = usePlaceStore();
  const { tripID, syncNow } = useTripSync();
  const [keepAssigned, setKeepAssigned] = useState(true);
  const [preview, setPreview] = useState<ItineraryPreview | null>(null);
  const [undo, setUndo] = useState<ItineraryUndoRecord | null>(null);
  const [applied, setApplied] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [hoursBusy, setHoursBusy] = useState(false);
  const [hoursStatus, setHoursStatus] = useState<string | null>(null);
  const mounted = useRef(true);
  const busyRef = useRef(false);
  const hoursBusyRef = useRef(false);
  const openingController = useRef<AbortController | null>(null);
  useEffect(() => { mounted.current = true; return () => { mounted.current = false; openingController.current?.abort(); }; }, []);
  const startBusy = () => { if (busyRef.current || hoursBusyRef.current || !mounted.current) return false; busyRef.current = true; setBusy(true); return true; };
  const finishBusy = () => { busyRef.current = false; if (mounted.current) setBusy(false); };

  const createPreview = async () => {
    if (!startBusy()) return;
    if (mounted.current) { setError(null); setMessage(null); setUndo(null); setApplied(false); }
    try {
      const next = await readItineraryPreview(db, keepAssigned);
      if (mounted.current) setPreview(next);
    } catch (reason) {
      if (mounted.current) { setPreview(null); setError(reason instanceof Error ? reason.message : 'Die Vorschau konnte nicht erstellt werden.'); }
    } finally { finishBusy(); }
  };

  const loadOpeningHours = async () => {
    if (hoursBusyRef.current || busyRef.current || !mounted.current) return;
    const controller = new AbortController();
    openingController.current = controller;
    hoursBusyRef.current = true;
    setHoursBusy(true); setHoursStatus(null); setError(null); setUndo(null); setApplied(false); setMessage(null);
    try {
      const result = await refreshOpeningHours(db, tripID, controller.signal);
      if (!mounted.current) return;
      const next = await readItineraryPreview(db, keepAssigned);
      if (!mounted.current) return;
      await reload();
      if (!mounted.current) return;
      setPreview(next);
      setHoursStatus(`${result.cancelled ? 'Abgebrochen · ' : ''}${result.updated} Öffnungszeiten geladen · ${result.unknown} ohne Eintrag · ${result.errors} Fehler`);
    } catch (reason) {
      if (mounted.current && !controller.signal.aborted) setError(reason instanceof Error ? reason.message : 'Öffnungszeiten konnten nicht geladen werden.');
    } finally {
      if (openingController.current === controller) openingController.current = null;
      hoursBusyRef.current = false;
      if (mounted.current) setHoursBusy(false);
    }
  };

  const apply = async () => {
    if (!preview || applied || !startBusy()) return;
    if (mounted.current) { setError(null); setMessage(null); }
    try {
      if (tripID && !(await syncNow())) throw new ItineraryActionError('Die gemeinsame Reise konnte vor dem Anwenden nicht abgeglichen werden.');
      if (!mounted.current) return;
      const record = await applyItineraryPlan(db, preview);
      if (!mounted.current) return;
      setUndo(record); setApplied(true); await reload();
      if (tripID && mounted.current) void syncNow();
      if (mounted.current) setMessage(record.assignments.length ? 'Tagesplan übernommen.' : 'Der Tagesplan war bereits aktuell.');
    } catch (reason) { if (mounted.current) setError(reason instanceof Error ? reason.message : 'Der Tagesplan konnte nicht übernommen werden.'); }
    finally { finishBusy(); }
  };

  const undoPlan = async () => {
    if (!undo || !startBusy()) return;
    if (mounted.current) { setError(null); setMessage(null); }
    try {
      if (tripID && !(await syncNow())) throw new ItineraryActionError('Die gemeinsame Reise konnte vor der Rücknahme nicht abgeglichen werden.');
      if (!mounted.current) return;
      await undoItineraryPlan(db, undo);
      if (!mounted.current) return;
      setUndo(null); setApplied(false); await reload();
      if (tripID && mounted.current) void syncNow();
      if (mounted.current) setMessage('Die geänderten Tageszuweisungen wurden zurückgenommen.');
    } catch (reason) { if (mounted.current) setError(reason instanceof Error ? reason.message : 'Die Rücknahme ist nicht mehr möglich.'); }
    finally { finishBusy(); }
  };

  return <View style={styles.root}>
    <Stack.Screen options={{ title: 'Tagesplan', headerLargeTitle: false }} />
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
      <Text style={styles.eyebrow}>REISEPLANUNG</Text>
      <Text style={styles.title}>Tage aus euren bestätigten Orten</Text>
      <Text style={styles.body}>Die Vorschau berücksichtigt 4.–9. Oktober 2026, An- und Abreise, Wege, Öffnungszeiten und maximal 85 % Tagesauslastung. Unklare Öffnungszeiten bleiben sichtbar.</Text>
      <View style={styles.card}><View style={styles.switchRow}><Text style={styles.label}>Bereits geplante Orte behalten</Text><Switch disabled={busy || hoursBusy} value={keepAssigned} onValueChange={(value) => { if (busyRef.current || hoursBusyRef.current) return; setKeepAssigned(value); setPreview(null); setUndo(null); setApplied(false); setMessage(null); }} /></View><Text style={styles.helper}>Wenn ausgeschaltet, werden alle bestätigten Orte neu verteilt.</Text></View>
      <Pressable accessibilityRole="button" disabled={busy || hoursBusy} onPress={() => void createPreview()} style={[styles.primaryButton, (busy || hoursBusy) && styles.disabled]}>{busy ? <ActivityIndicator color={colors.card} /> : <Text style={styles.primaryText}>{preview ? 'Neue Vorschau berechnen' : 'Vorschau erstellen'}</Text>}</Pressable>
      <Pressable accessibilityRole="button" disabled={busy || hoursBusy} onPress={() => void loadOpeningHours()} style={[styles.secondaryButton, (busy || hoursBusy) && styles.disabled]}><Text style={styles.secondaryText}>{hoursBusy ? 'Öffnungszeiten werden geladen …' : 'Fehlende Öffnungszeiten laden'}</Text></Pressable>
      {hoursBusy && <Pressable accessibilityRole="button" onPress={() => openingController.current?.abort()} style={styles.secondaryButton}><Text style={styles.secondaryText}>Laden abbrechen</Text></Pressable>}
      {!!hoursStatus && <Text style={styles.success}>{hoursStatus}</Text>}
      {!!error && <View style={styles.error}><Text style={styles.body}>{error}</Text></View>}
      {!!message && <Text style={styles.success}>{message}</Text>}
      {preview && <>
        {ITINERARY_DAYS.map((day) => {
          const stops = preview.proposal.days[day] ?? [];
          const window = preview.proposal.windows[day];
          const exceedsBudget = stops.length > 0 && stops.reduce((sum, stop) => sum + visitMinutes(stop.place), 0) + walkingMinutes(routeLength(stops.map((stop) => stop.place), preview.proposal.hotel)) > window.minutes * 0.85;
          return <View style={styles.dayCard} key={day}><View style={styles.dayHeader}><Text style={styles.dayTitle}>{day}. Oktober</Text><Text style={styles.window}>{window.minutes ? `${formatMinute(window.start)}–${formatMinute(window.end)}` : 'keine freie Zeit'}</Text></View>{exceedsBudget && <Text style={styles.warning}>Bereits zugewiesene Orte überschreiten das Zeitbudget. Du kannst sie im Tagesplan verschieben.</Text>}{stops.length ? stops.map((stop, index) => <View style={styles.stop} key={`${stop.place.id}-${index}`}><View style={styles.stopIndex}><Text style={styles.stopIndexText}>{index + 1}</Text></View><View style={styles.stopCopy}><Text style={styles.stopTitle}>{stop.place.title}</Text><Text style={styles.helper}>{stop.place.category} · {stop.slot}</Text>{!!stop.note && <Text style={styles.warning}>⚠ {stop.note}</Text>}</View></View>) : <Text style={styles.helper}>Frei</Text>}</View>;
        })}
        {!!preview.proposal.leftOver.length && <View style={styles.card}><Text style={styles.section}>Restliste</Text>{preview.proposal.leftOver.map((item) => <Text style={styles.rest} key={item.place.id}>• {item.place.title} · {leftOverText[item.reason]}{item.place.day != null ? ` · bisher ${item.place.day}. Oktober (bleibt erhalten)` : ''}</Text>)}</View>}
        {!applied ? <Pressable accessibilityRole="button" disabled={busy || hoursBusy || !Object.values(preview.proposal.days).some((stops) => stops.length > 0)} onPress={() => void apply()} style={[styles.primaryButton, busy && styles.disabled]}><Text style={styles.primaryText}>Vorschau übernehmen</Text></Pressable> : undo && <Pressable accessibilityRole="button" disabled={busy || hoursBusy} onPress={() => void undoPlan()} style={styles.secondaryButton}><Text style={styles.secondaryText}>Änderungen zurücknehmen</Text></Pressable>}
      </>}
    </ScrollView>
  </View>;
}

function formatMinute(value: number): string { return `${String(Math.floor(value / 60) % 24).padStart(2, '0')}:${String(value % 60).padStart(2, '0')}`; }

const styles = StyleSheet.create({ root: { backgroundColor: colors.paper, flex: 1 }, content: { gap: 14, padding: space.page, paddingBottom: 48 }, eyebrow: { color: colors.red, fontSize: 12, fontWeight: '700', letterSpacing: 1.4 }, title: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 30, lineHeight: 36 }, body: { color: colors.inkSoft, fontSize: 14, lineHeight: 21 }, card: { backgroundColor: colors.paperDeep, borderRadius: 17, gap: 9, padding: 15 }, switchRow: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between', gap: 10 }, label: { color: colors.ink, flex: 1, fontSize: 14, fontWeight: '700' }, helper: { color: colors.inkSoft, fontSize: 12, lineHeight: 18 }, primaryButton: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 24, justifyContent: 'center', minHeight: 48 }, primaryText: { color: colors.card, fontSize: 15, fontWeight: '700' }, disabled: { opacity: 0.55 }, error: { backgroundColor: colors.card, borderColor: colors.red, borderRadius: 12, borderWidth: 1, padding: 12 }, success: { color: colors.teal, fontSize: 14, fontWeight: '700' }, dayCard: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 17, borderWidth: 1, gap: 10, padding: 15 }, dayHeader: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between' }, dayTitle: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 22 }, window: { color: colors.inkSoft, fontSize: 12 }, stop: { alignItems: 'flex-start', flexDirection: 'row', gap: 10 }, stopIndex: { alignItems: 'center', backgroundColor: colors.teal, borderRadius: 15, height: 29, justifyContent: 'center', width: 29 }, stopIndexText: { color: colors.card, fontWeight: '800' }, stopCopy: { flex: 1, gap: 2 }, stopTitle: { color: colors.ink, fontSize: 15, fontWeight: '700' }, warning: { color: colors.red, fontSize: 12, lineHeight: 18 }, section: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 22 }, rest: { color: colors.inkSoft, fontSize: 14, lineHeight: 20 }, secondaryButton: { alignItems: 'center', borderColor: colors.red, borderRadius: 24, borderWidth: 1, justifyContent: 'center', minHeight: 46 }, secondaryText: { color: colors.red, fontSize: 15, fontWeight: '700' }, });
