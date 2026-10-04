import { useCallback, useState } from 'react';
import { Linking, Pressable, StyleSheet, Text, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, { Extrapolation, interpolate, runOnJS, useAnimatedStyle, useSharedValue, withSequence, withSpring } from 'react-native-reanimated';
import { colors, fonts, space } from '@/domain/theme';
import { myDecision } from '@/domain/place-decisions';
import type { Place, PlaceDecision } from '@/domain/place';

const decisions: { id: PlaceDecision; title: string }[] = [
  { id: 'approved', title: 'Dafür' },
  { id: 'opposed', title: 'Dagegen' },
  { id: 'open', title: 'Offen' },
];

export default function DecisionCard({
  place,
  memberName,
  onDecide,
  onAssignDay,
}: {
  place: Place;
  memberName: string;
  onDecide: (id: string, decision: PlaceDecision) => Promise<void>;
  onAssignDay: (id: string, day: number | null) => Promise<void>;
}) {
  const decision = myDecision(place, memberName);
  const translateX = useSharedValue(0);
  const cardWidth = useSharedValue(320);
  const [committing, setCommitting] = useState(false);

  const finishDecision = useCallback(async (next: PlaceDecision) => {
    if (next === decision) {
      setCommitting(false);
      return;
    }
    try {
      await onDecide(place.id, next);
    } catch {
      // The caller surfaces persistence errors; keep the gesture handler settled.
    } finally {
      setCommitting(false);
    }
  }, [decision, onDecide, place.id]);

  const animateDecision = useCallback((next: PlaceDecision, direction: -1 | 1) => {
    if (committing || next === decision) return;
    setCommitting(true);
    // Reanimated shared-value writes are UI-thread mutations, not React state.
    // eslint-disable-next-line react-hooks/immutability
    translateX.value = withSequence(
      withSpring(direction * 12, { damping: 18, stiffness: 260 }),
      withSpring(0, { damping: 18, stiffness: 220 }, (finished) => {
        if (finished) runOnJS(finishDecision)(next);
      }),
    );
  }, [committing, decision, finishDecision, translateX]);

  const pan = Gesture.Pan()
    .activeOffsetX([-12, 12])
    .failOffsetY([-14, 14])
    .onUpdate((event) => {
      // eslint-disable-next-line react-hooks/immutability
      translateX.value = Math.max(-cardWidth.value * 0.52, Math.min(cardWidth.value * 0.52, event.translationX));
    })
    .onEnd((event) => {
      if (committing) {
        // eslint-disable-next-line react-hooks/immutability
        translateX.value = withSpring(0, { damping: 18, stiffness: 220 });
        return;
      }
      const threshold = Math.max(68, cardWidth.value * 0.22);
      const swipedRight = event.translationX > threshold || (event.translationX > threshold * 0.6 && event.velocityX > 700);
      const swipedLeft = event.translationX < -threshold || (event.translationX < -threshold * 0.6 && event.velocityX < -700);
      if (swipedRight) runOnJS(animateDecision)('approved', 1);
      else if (swipedLeft) runOnJS(animateDecision)('opposed', -1);
      else translateX.value = withSpring(0, { damping: 18, stiffness: 220 });
    });

  const animatedCardStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { rotateZ: `${interpolate(translateX.value, [-160, 160], [-2.6, 2.6], Extrapolation.CLAMP)}deg` },
    ],
  }));
  const approveHintStyle = useAnimatedStyle(() => ({ opacity: interpolate(translateX.value, [0, cardWidth.value * 0.3], [0, 1], Extrapolation.CLAMP) }));
  const opposeHintStyle = useAnimatedStyle(() => ({ opacity: interpolate(translateX.value, [-cardWidth.value * 0.3, 0], [1, 0], Extrapolation.CLAMP) }));

  const selectedTitle = decisions.find((item) => item.id === decision)?.title ?? 'Offen';

  return (
    <View onLayout={(event) => { cardWidth.value = event.nativeEvent.layout.width; }} style={styles.frame}>
      <View pointerEvents="none" style={styles.swipeHints}>
        <Animated.View style={[styles.swipeHint, styles.approveHint, approveHintStyle]}><Text style={styles.hintText}>Dafür</Text></Animated.View>
        <Animated.View style={[styles.swipeHint, styles.opposeHint, opposeHintStyle]}><Text style={styles.hintText}>Dagegen</Text></Animated.View>
      </View>
      <GestureDetector gesture={pan}>
        <Animated.View style={[styles.card, animatedCardStyle]}>
          <View style={styles.cardHeader}>
            <Text style={styles.category}>{place.category.toLocaleUpperCase('de')}</Text>
            <Text style={styles.currentState}>Deine Wahl · {selectedTitle}</Text>
          </View>
          <Text selectable style={styles.placeTitle}>{place.title}</Text>
          {!!place.note && <Text selectable style={styles.note}>{place.note}</Text>}
          {!!place.address && <Text selectable style={styles.address}>{place.address}</Text>}
          {place.approvals.length > 1 && <Text style={styles.shared}>Gemeinsam dafür</Text>}
          <View style={styles.actions}>
            {decisions.map((item) => {
              const selected = item.id === decision;
              return (
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel={`${item.title} für ${place.title}`}
                  accessibilityState={{ selected }}
                  disabled={committing}
                  key={item.id}
                  onPress={() => animateDecision(item.id, item.id === 'opposed' ? -1 : 1)}
                  style={[styles.decisionButton, selected && styles.decisionButtonSelected, selected && item.id === 'opposed' && styles.opposedSelected, selected && item.id === 'open' && styles.openSelected]}
                >
                  <Text style={[styles.decisionText, selected && styles.selectedText]}>{item.title}</Text>
                  {selected && <Text pointerEvents="none" style={styles.selectedCheck}>✓</Text>}
                </Pressable>
              );
            })}
          </View>
          {!!place.sourceURL && (
            <Pressable accessibilityRole="link" onPress={() => void Linking.openURL(place.sourceURL)} style={styles.linkButton}>
              <Text style={styles.linkText}>Quelle ansehen ↗</Text>
            </Pressable>
          )}
          {decision === 'approved' && <View style={styles.dayActions}>
            <Text style={styles.dayLabel}>{place.day ? `Geplant: ${place.day}. Oktober` : 'Tag planen'}</Text>
            {[4, 5, 6, 7, 8, 9].map((day) => <Pressable accessibilityRole="button" accessibilityLabel={`Am ${day}. Oktober planen`} key={day} onPress={() => void onAssignDay(place.id, day)} style={[styles.dayButton, place.day === day && styles.dayButtonSelected]}><Text style={[styles.dayButtonText, place.day === day && styles.dayButtonTextSelected]}>{day}</Text></Pressable>)}
            {place.day != null && <Pressable accessibilityRole="button" accessibilityLabel="Tag entfernen" onPress={() => void onAssignDay(place.id, null)} style={styles.clearDay}><Text style={styles.clearDayText}>×</Text></Pressable>}
          </View>}
          <Text style={styles.swipeHintCopy}>Wischen: rechts dafür · links dagegen</Text>
        </Animated.View>
      </GestureDetector>
    </View>
  );
}

const styles = StyleSheet.create({
  frame: { position: 'relative' },
  swipeHints: { bottom: 0, flexDirection: 'row', justifyContent: 'space-between', left: 0, paddingHorizontal: 10, paddingTop: 14, position: 'absolute', right: 0, top: 0 },
  swipeHint: { alignSelf: 'flex-start', borderRadius: 14, paddingHorizontal: 11, paddingVertical: 6 },
  approveHint: { backgroundColor: colors.red },
  opposeHint: { backgroundColor: colors.ink },
  hintText: { color: colors.card, fontSize: 12, fontWeight: '700' },
  card: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: space.cardRadius, borderWidth: 1, gap: 12, padding: 18 },
  cardHeader: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between', gap: 8 },
  category: { color: colors.red, fontSize: 10, fontWeight: '700', letterSpacing: 1.1 },
  currentState: { color: colors.inkSoft, fontSize: 11, fontWeight: '600' },
  shared: { color: colors.teal, fontSize: 12, fontWeight: '600' },
  placeTitle: { color: colors.ink, fontFamily: fonts.place, fontSize: 27, lineHeight: 31 },
  note: { color: colors.inkSoft, fontSize: 15, lineHeight: 21 },
  address: { color: colors.inkSoft, fontSize: 13 },
  actions: { flexDirection: 'row', gap: 7, marginTop: 2 },
  decisionButton: { alignItems: 'center', backgroundColor: colors.paperDeep, borderRadius: 17, flex: 1, justifyContent: 'center', minHeight: 48, paddingHorizontal: 6, position: 'relative' },
  decisionButtonSelected: { backgroundColor: colors.red },
  opposedSelected: { backgroundColor: colors.ink },
  openSelected: { backgroundColor: colors.teal },
  decisionText: { color: colors.ink, fontSize: 13, fontWeight: '600', textAlign: 'center' },
  selectedText: { color: colors.card },
  selectedCheck: { color: colors.card, fontSize: 10, fontWeight: '800', left: 10, position: 'absolute', top: 18 },
  linkButton: { alignSelf: 'flex-start', justifyContent: 'center', minHeight: 36, paddingHorizontal: 4 },
  linkText: { color: colors.red, fontSize: 13, fontWeight: '600' },
  dayActions: { alignItems: 'center', flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: 2 },
  dayLabel: { color: colors.inkSoft, fontSize: 12, marginRight: 2 },
  dayButton: { alignItems: 'center', backgroundColor: colors.paperDeep, borderRadius: 16, justifyContent: 'center', minHeight: 32, minWidth: 32 },
  dayButtonSelected: { backgroundColor: colors.teal },
  dayButtonText: { color: colors.ink, fontSize: 12, fontWeight: '600' },
  dayButtonTextSelected: { color: colors.card },
  clearDay: { alignItems: 'center', justifyContent: 'center', minHeight: 32, minWidth: 32 },
  clearDayText: { color: colors.red, fontSize: 20 },
  swipeHintCopy: { color: colors.inkSoft, fontSize: 11, textAlign: 'center' },
});
