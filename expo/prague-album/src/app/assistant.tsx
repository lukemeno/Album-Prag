import { useState } from 'react';
import { Alert, KeyboardAvoidingView, Linking, Platform, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import { Stack } from 'expo-router';
import { colors, space } from '@/domain/theme';
import { isHTTPURL, type AssistantDay, type AssistantReply } from '@/domain/assistant';
import { useAssistant } from '@/hooks/use-assistant';
import { usePlaceStore } from '@/storage/place-store';

const dayTitles: Record<number, string> = { 4: 'Sonntag, 4. Oktober', 5: 'Montag, 5. Oktober', 6: 'Dienstag, 6. Oktober', 7: 'Mittwoch, 7. Oktober', 8: 'Donnerstag, 8. Oktober', 9: 'Freitag, 9. Oktober' };

export default function AssistantScreen() {
  const { places } = usePlaceStore();
  const assistant = useAssistant();
  const [draft, setDraft] = useState('');
  const [saved, setSaved] = useState<Record<string, string>>({});

  const send = (value = draft) => {
    const text = value.trim();
    if (!text || assistant.isLoading) return;
    setDraft(''); void assistant.send(text);
  };

  const savePlace = async (place: AssistantReply['places'][number]) => {
    try {
      const result = await assistant.saveSuggestion(place);
      setSaved((current) => ({ ...current, [suggestionKey(place)]: result === 'added' ? 'Als Idee gespeichert' : result === 'reused' ? 'Idee wieder geöffnet' : 'Schon in euren Ideen' }));
    } catch (error) {
      setSaved((current) => ({ ...current, [suggestionKey(place)]: error instanceof Error ? error.message : 'Speichern fehlgeschlagen.' }));
    }
  };

  const apply = (messageID: string, plan: AssistantDay[]) => {
    Alert.alert('Plan übernehmen?', 'Nur abgestimmte aktive Orte werden den vorgeschlagenen Tagen zugeordnet.', [
      { text: 'Abbrechen', style: 'cancel' },
      { text: 'Übernehmen', onPress: () => void assistant.applyPlan(messageID, plan).catch((error: unknown) => Alert.alert('Plan nicht übernommen', error instanceof Error ? error.message : 'Bitte versuche es erneut.')) },
    ]);
  };

  return (
    <KeyboardAvoidingView style={styles.root} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={Platform.OS === 'ios' ? 96 : 0}>
      <Stack.Screen options={{ title: 'Reise-Assistent', headerLargeTitle: false }} />
      <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        {assistant.messages.length === 0 && <View style={styles.welcome}>
          <Text style={styles.eyebrow}>EURE REISE IN PRAG</Text>
          <Text style={styles.title}>Womit soll ich helfen?</Text>
          <Text style={styles.body}>Ich kenne eure abgestimmten Orte, Reiseunterlagen und Sammlung. Änderungen erscheinen zuerst als Vorschlag.</Text>
          <View style={styles.suggestions}>
            {['Plane den morgigen Tag', 'Was passt jetzt?', 'Fragen zu Unterlagen'].map((suggestion) => <Pressable key={suggestion} onPress={() => send(suggestion)} style={styles.chip}><Text style={styles.chipText}>{suggestion}</Text></Pressable>)}
          </View>
        </View>}
        {!!assistant.preferences.length && <View style={styles.replySection}><Text style={styles.sectionLabel}>Gemerkte Vorlieben</Text>{assistant.preferences.map((value) => <View key={value} style={styles.preference}><Text style={[styles.body, { flex: 1 }]}>{value}</Text><Pressable accessibilityLabel={`Vorliebe entfernen: ${value}`} onPress={() => assistant.forget(value)}><Text style={styles.actionText}>Entfernen</Text></Pressable></View>)}</View>}
        {!!assistant.messages.length && <Pressable onPress={() => Alert.alert('Verlauf leeren?', 'Der lokale Chatverlauf und die gemerkten Vorlieben werden entfernt.', [{ text: 'Abbrechen', style: 'cancel' }, { text: 'Leeren', style: 'destructive', onPress: assistant.clear }])}><Text style={styles.actionText}>Verlauf leeren</Text></Pressable>}
        {assistant.messages.map((message) => <View key={message.id} style={[styles.messageRow, message.role === 'user' && styles.userRow]}>
          <View style={[styles.message, message.role === 'user' ? styles.userMessage : styles.assistantMessage]}>
            <Text selectable style={[styles.messageText, message.role === 'user' && styles.userText]}>{message.text}</Text>
          </View>
          {message.role === 'assistant' && message.reply && <ReplyCards reply={message.reply} messageID={message.id} places={places} saved={saved} onSave={savePlace} onApply={apply} canUndo={assistant.canUndo(message.id)} onUndo={() => void assistant.undo(message.id).catch((error: unknown) => Alert.alert('Rücknahme nicht möglich', error instanceof Error ? error.message : 'Bitte versuche es erneut.'))} onRemember={assistant.remember} />}
        </View>)}
        {assistant.isLoading && <View style={styles.loading}><Text style={styles.loadingText}>Ich sehe kurz nach …</Text><Pressable onPress={assistant.cancel}><Text style={styles.actionText}>Abbrechen</Text></Pressable></View>}
        {!!assistant.lastError && !assistant.isLoading && <View style={styles.error}><Text style={styles.body}>{assistant.lastError}</Text><Pressable onPress={assistant.retry}><Text style={styles.actionText}>Erneut versuchen</Text></Pressable></View>}
      </ScrollView>
      <View style={styles.composer}>
        <View style={styles.inputRow}>
        <TextInput accessibilityLabel="Nachricht an den Reise-Assistenten" editable={!assistant.isLoading} multiline maxLength={4_000} onChangeText={setDraft} onSubmitEditing={() => send()} placeholder="Nachricht …" placeholderTextColor={colors.inkSoft} style={styles.input} value={draft} />
        <Pressable accessibilityLabel="Senden" disabled={!draft.trim() || assistant.isLoading} onPress={() => send()} style={[styles.sendButton, (!draft.trim() || assistant.isLoading) && styles.disabled]}><Text style={styles.sendText}>↑</Text></Pressable>
        </View>
        <View style={styles.options}>
          <Pressable onPress={() => void assistant.requestLocation()} style={styles.optionButton}><Text style={styles.optionText}>⌖ {assistant.location ? 'Standort bereit' : 'Standort verwenden'}</Text></Pressable>
          <View style={styles.webOption}><Text style={styles.optionText}>Web-Recherche</Text><Switch accessibilityLabel="Web-Recherche" onValueChange={assistant.setWebSearch} thumbColor={assistant.webSearch ? colors.red : colors.rule} trackColor={{ false: colors.rule, true: colors.paperDeep }} value={assistant.webSearch} /></View>
        </View>
        {!!assistant.locationStatus && <Text style={styles.helper}>{assistant.locationStatus}</Text>}
      </View>
    </KeyboardAvoidingView>
  );
}

function suggestionKey(place: AssistantReply['places'][number]): string { return `${place.existing_id ?? ''}|${place.title}|${place.address}`; }

function ReplyCards({ reply, messageID, places, saved, onSave, onApply, canUndo, onUndo, onRemember }: { reply: AssistantReply; messageID: string; places: ReturnType<typeof usePlaceStore>['places']; saved: Record<string, string>; onSave: (place: AssistantReply['places'][number]) => Promise<void>; onApply: (messageID: string, plan: AssistantDay[]) => void; canUndo: boolean; onUndo: () => void; onRemember: (preference: string) => void }) {
  return <View style={styles.replyCards}>
    {!!reply.sources.length && <View style={styles.replySection}><Text style={styles.sectionLabel}>Quellen</Text>{reply.sources.map((source, index) => <Pressable disabled={!source.url && !source.document_id} key={`${source.title}-${index}`} onPress={() => { if (source.url && isHTTPURL(source.url)) void Linking.openURL(source.url); }} style={styles.source}><Text style={styles.sourceTitle}>{source.document_id ? `▧ ${source.title}` : `↗ ${source.title}`}</Text>{source.document_id && <Text selectable style={styles.quote}>{source.quote || 'Lokaler Dokumentauszug'}</Text>}</Pressable>)}</View>}
    {!!reply.places.length && <View style={styles.replySection}><Text style={styles.sectionLabel}>Orte zum Prüfen</Text>{reply.places.map((place) => <View key={suggestionKey(place)} style={styles.placeCard}><View style={styles.placeCopy}><Text style={styles.placeTitle}>{place.title}</Text>{!!place.address && <Text style={styles.helper}>{place.address}</Text>}</View><Pressable onPress={() => void onSave(place)}><Text style={styles.actionText}>{saved[suggestionKey(place)] ? 'Gespeichert' : 'Als Idee speichern'}</Text></Pressable>{!!saved[suggestionKey(place)] && <Text style={styles.helper}>{saved[suggestionKey(place)]}</Text>}</View>)}</View>}
    {!!reply.plan.length && <View style={styles.replySection}><Text style={styles.sectionLabel}>Planvorschlag</Text>{reply.plan.map((day) => <PlanCard key={day.day} day={day} places={places} />)}<Pressable onPress={() => onApply(messageID, reply.plan)} style={styles.primaryButton}><Text style={styles.primaryText}>Plan prüfen und übernehmen</Text></Pressable>{canUndo && <Pressable onPress={onUndo} style={styles.secondaryButton}><Text style={styles.secondaryText}>Rückgängig</Text></Pressable>}</View>}
    {!!reply.preferences.length && <View style={styles.replySection}><Text style={styles.sectionLabel}>Als persönliche Vorliebe merken?</Text>{reply.preferences.map((preference) => <View key={preference} style={styles.preference}><Text style={styles.body}>{preference}</Text><Pressable onPress={() => onRemember(preference)}><Text style={styles.actionText}>Merken</Text></Pressable></View>)}</View>}
  </View>;
}

function PlanCard({ day, places }: { day: AssistantDay; places: ReturnType<typeof usePlaceStore>['places'] }) {
  const names = day.place_ids.map((id) => places.find((place) => place.id === id)?.title).filter((name): name is string => Boolean(name));
  return <View style={styles.planCard}><Text style={styles.planTitle}>{dayTitles[day.day] ?? `Tag ${day.day}`}</Text><Text style={styles.body}>{names.length ? names.join(' · ') : day.note}</Text>{names.length > 0 && !!day.note && <Text style={styles.helper}>{day.note}</Text>}</View>;
}

const styles = StyleSheet.create({
  root: { backgroundColor: colors.paper, flex: 1 }, content: { gap: space.medium, padding: space.page, paddingBottom: 28 }, welcome: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 20, borderWidth: 1, gap: 10, padding: 20 }, eyebrow: { color: colors.red, fontSize: 12, fontWeight: '700', letterSpacing: 1.4 }, title: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 30, fontWeight: '600' }, body: { color: colors.inkSoft, fontSize: 15, lineHeight: 22 }, suggestions: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 6 }, chip: { borderColor: colors.rule, borderRadius: 18, borderWidth: 1, paddingHorizontal: 12, paddingVertical: 9 }, chipText: { color: colors.red, fontSize: 14, fontWeight: '600' }, messageRow: { alignItems: 'flex-start', gap: 8 }, userRow: { alignItems: 'flex-end' }, message: { borderRadius: 18, maxWidth: '92%', paddingHorizontal: 15, paddingVertical: 11 }, userMessage: { backgroundColor: colors.red }, assistantMessage: { backgroundColor: colors.card, borderColor: colors.rule, borderWidth: 1 }, messageText: { color: colors.ink, fontSize: 16, lineHeight: 23 }, userText: { color: colors.card }, replyCards: { gap: 10, width: '100%' }, replySection: { gap: 7 }, sectionLabel: { color: colors.inkSoft, fontSize: 13, fontWeight: '700' }, source: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 12, borderWidth: 1, gap: 3, padding: 11 }, sourceTitle: { color: colors.ink, fontSize: 14, fontWeight: '700' }, quote: { color: colors.inkSoft, fontSize: 13, lineHeight: 19 }, placeCard: { alignItems: 'center', backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 12, borderWidth: 1, flexDirection: 'row', gap: 8, padding: 11 }, placeCopy: { flex: 1, gap: 2 }, placeTitle: { color: colors.ink, fontSize: 15, fontWeight: '700' }, planCard: { backgroundColor: colors.paperDeep, borderRadius: 12, gap: 4, padding: 12 }, planTitle: { color: colors.ink, fontSize: 15, fontWeight: '700' }, preference: { alignItems: 'center', backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 12, borderWidth: 1, flexDirection: 'row', gap: 8, justifyContent: 'space-between', padding: 11 }, actionText: { color: colors.red, fontSize: 14, fontWeight: '700' }, primaryButton: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 22, minHeight: 44, justifyContent: 'center', paddingHorizontal: 14 }, primaryText: { color: colors.card, fontSize: 14, fontWeight: '700' }, secondaryButton: { alignItems: 'center', borderColor: colors.rule, borderRadius: 22, borderWidth: 1, minHeight: 42, justifyContent: 'center', paddingHorizontal: 14 }, secondaryText: { color: colors.ink, fontSize: 14, fontWeight: '700' }, loading: { alignItems: 'center', flexDirection: 'row', gap: 12, paddingVertical: 5 }, loadingText: { color: colors.inkSoft, flex: 1, fontSize: 14 }, error: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 14, borderWidth: 1, gap: 6, padding: 13 }, composer: { backgroundColor: colors.card, borderTopColor: colors.rule, borderTopWidth: 1, gap: 8, padding: 12 }, inputRow: { alignItems: 'flex-end', flexDirection: 'row', gap: 8 }, input: { flex: 1, backgroundColor: colors.paper, borderColor: colors.rule, borderRadius: 14, borderWidth: 1, color: colors.ink, maxHeight: 120, minHeight: 44, paddingHorizontal: 13, paddingVertical: 10, paddingRight: 13 }, sendButton: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 20, height: 44, justifyContent: 'center', width: 44 }, disabled: { opacity: 0.4 }, sendText: { color: colors.card, fontSize: 24, fontWeight: '700', marginTop: -4 }, options: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between' }, optionButton: { paddingVertical: 4 }, webOption: { alignItems: 'center', flexDirection: 'row', gap: 5 }, optionText: { color: colors.inkSoft, fontSize: 12 }, helper: { color: colors.inkSoft, fontSize: 12, lineHeight: 17 },
});
