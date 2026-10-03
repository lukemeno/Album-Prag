import type { Place } from '@/domain/place';
import { octoberWeekday, parseOpeningHours, type OpeningHours } from '@/domain/opening-hours';

export const ITINERARY_DAYS = [4, 5, 6, 7, 8, 9] as const;
export type ItineraryDay = typeof ITINERARY_DAYS[number];
export interface Coordinate { latitude: number; longitude: number; }
export interface FlightLike { direction?: string; departure?: string; arrival?: string; }
export interface DayWindow { start: number; end: number; minutes: number; }
export interface PlanStop { place: Place; slot: string; note: string | null; }
export type LeftOverReason = 'missing_coordinates' | 'closed' | 'capacity';
export interface ItineraryLeftOver { place: Place; reason: LeftOverReason; }
export interface DayPlanProposal {
  days: Record<number, PlanStop[]>;
  windows: Record<number, DayWindow>;
  leftOver: ItineraryLeftOver[];
  hotel: Coordinate;
}

const DEFAULT_HOTEL: Coordinate = { latitude: 50.0875, longitude: 14.4213 };
const MAX_DAY_LOAD = 0.85;
const NEW_AREA_COST = 1_500;

export function coordinateFor(place: Pick<Place, 'lat' | 'lng'>): Coordinate | null {
  if (typeof place.lat !== 'number' || typeof place.lng !== 'number' || !Number.isFinite(place.lat) || !Number.isFinite(place.lng) || place.lat < -90 || place.lat > 90 || place.lng < -180 || place.lng > 180) return null;
  return { latitude: place.lat, longitude: place.lng };
}

export function haversineMeters(a: Coordinate, b: Coordinate): number {
  if (![a.latitude, a.longitude, b.latitude, b.longitude].every(Number.isFinite)) return Number.POSITIVE_INFINITY;
  const radians = Math.PI / 180;
  const latitudeDelta = (b.latitude - a.latitude) * radians;
  const longitudeDelta = (b.longitude - a.longitude) * radians;
  const latitudeA = a.latitude * radians;
  const latitudeB = b.latitude * radians;
  const value = Math.sin(latitudeDelta / 2) ** 2 + Math.cos(latitudeA) * Math.cos(latitudeB) * Math.sin(longitudeDelta / 2) ** 2;
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(Math.max(0, value)), Math.sqrt(Math.max(0, 1 - value)));
}

export function walkingMinutes(meters: number): number { return Number.isFinite(meters) ? Math.max(0, Math.round(meters * 1.3 / 75)) : 0; }

export function visitMinutes(place: Pick<Place, 'category'>): number {
  switch (place.category) {
    case 'Essen & Trinken': return 75;
    case 'Sehenswert': return 60;
    case 'Aussicht': return 30;
    case 'Shopping': return 45;
    default: return 45;
  }
}

function parseClock(value: unknown): number | null {
  if (typeof value !== 'string') return null;
  const match = /^(\d{1,2}):(\d{2})$/u.exec(value.trim());
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  return Number.isInteger(hour) && Number.isInteger(minute) && hour >= 0 && hour < 24 && minute >= 0 && minute < 60 ? hour * 60 + minute : null;
}

function flightMinute(flights: readonly FlightLike[], direction: string, field: 'arrival' | 'departure'): number | null {
  const flight = flights.find((item) => item.direction === direction);
  return parseClock(flight?.[field]);
}

export function dayWindows(flights: readonly FlightLike[] = []): Record<number, DayWindow> {
  const windows: Record<number, DayWindow> = {};
  for (const day of ITINERARY_DAYS) windows[day] = { start: 10 * 60, end: 22 * 60, minutes: 12 * 60 };
  const arrival = flightMinute(flights, 'outbound', 'arrival') ?? 16 * 60;
  const departure = flightMinute(flights, 'inbound', 'departure') ?? 12 * 60 + 30;
  const arrivalStart = Math.min(22 * 60, Math.max(0, arrival + 90));
  windows[4] = { start: arrivalStart, end: 22 * 60, minutes: Math.max(0, 22 * 60 - arrivalStart) };
  const departureEnd = Math.max(8 * 60 + 30, Math.min(24 * 60, departure - 165));
  windows[9] = { start: 8 * 60 + 30, end: departureEnd, minutes: Math.max(0, departureEnd - (8 * 60 + 30)) };
  return windows;
}

function parsedHours(place: Pick<Place, 'openingHours'>): OpeningHours | null { return parseOpeningHours(place.openingHours); }
function openDays(place: Place): ItineraryDay[] {
  const hours = parsedHours(place);
  if (!hours) return [...ITINERARY_DAYS];
  return ITINERARY_DAYS.filter((day) => hours.isOpen(octoberWeekday(day)));
}

function nearestDistance(point: Coordinate, places: readonly Place[], hotel?: Coordinate): number {
  const candidates = places.map(coordinateFor).filter((value): value is Coordinate => value !== null);
  if (hotel) candidates.push(hotel);
  return candidates.length ? Math.min(...candidates.map((candidate) => haversineMeters(point, candidate))) : 0;
}

export function route(places: readonly Place[], start: Coordinate): Place[] {
  const remaining = places.filter((place) => coordinateFor(place) !== null);
  const ordered: Place[] = [];
  let position = start;
  while (remaining.length) {
    let bestIndex = 0;
    let bestDistance = Number.POSITIVE_INFINITY;
    remaining.forEach((place, index) => {
      const distance = haversineMeters(position, coordinateFor(place)!);
      if (distance < bestDistance) { bestDistance = distance; bestIndex = index; }
    });
    const [next] = remaining.splice(bestIndex, 1);
    ordered.push(next);
    position = coordinateFor(next)!;
  }
  if (ordered.length < 3) return separateMeals(ordered);
  let improved = true;
  while (improved) {
    improved = false;
    for (let first = 0; first < ordered.length - 1; first += 1) {
      for (let last = first + 1; last < ordered.length; last += 1) {
        const candidate = ordered.slice();
        candidate.splice(first, last - first + 1, ...candidate.slice(first, last + 1).reverse());
        if (routeLength(candidate, start) + 1 < routeLength(ordered, start)) {
          ordered.splice(0, ordered.length, ...candidate);
          improved = true;
        }
      }
    }
  }
  return separateMeals(ordered);
}

export function routeLength(places: readonly Place[], start: Coordinate): number {
  let total = 0;
  let position = start;
  for (const place of places) {
    const coordinate = coordinateFor(place);
    if (!coordinate) continue;
    total += haversineMeters(position, coordinate);
    position = coordinate;
  }
  return total + haversineMeters(position, start);
}

export function separateMeals(places: readonly Place[]): Place[] {
  const result = [...places];
  const isMeal = (place: Place) => place.category === 'Essen & Trinken';
  for (let index = 1; index < result.length; index += 1) {
    if (!isMeal(result[index]) || !isMeal(result[index - 1])) continue;
    const other = result.findIndex((place, candidate) => candidate >= index && !isMeal(place));
    if (other >= 0) {
      const [place] = result.splice(other, 1);
      result.splice(index, 0, place);
    }
  }
  return result;
}

function estimatedMinutes(places: readonly Place[], hotel: Coordinate): number {
  return places.reduce((total, place) => total + visitMinutes(place), 0) + walkingMinutes(routeLength(route(places, hotel), hotel));
}

function slot(value: number): string {
  if (value < 12 * 60) return 'vormittags';
  if (value < 14 * 60 + 30) return 'mittags';
  if (value < 18 * 60) return 'nachmittags';
  return 'abends';
}

export function timeline(ordered: readonly Place[], day: number, window: DayWindow, hotel: Coordinate): PlanStop[] {
  let clock = window.start;
  let position = hotel;
  return ordered.map((place) => {
    const coordinate = coordinateFor(place);
    if (coordinate) { clock += walkingMinutes(haversineMeters(position, coordinate)); position = coordinate; }
    const hours = parsedHours(place);
    let note: string | null = null;
    if (hours) {
      const weekday = octoberWeekday(day);
      if (!hours.isOpen(weekday)) note = 'an diesem Tag geschlossen';
      else if (!hours.isOpenAt(weekday, clock)) {
        const opens = hours.rangesFor(weekday).map((range) => range.start).filter((start) => start > clock).sort((a, b) => a - b)[0];
        if (opens !== undefined && opens - clock <= 90) clock = opens;
        else note = `offen ${hours.summary(weekday)}`;
      }
    } else {
      note = 'Öffnungszeiten unbekannt';
    }
    const stop = { place, slot: slot(clock), note };
    clock += visitMinutes(place);
    return stop;
  });
}

export function planItinerary(places: readonly Place[], hotel: Coordinate = DEFAULT_HOTEL, flights: readonly FlightLike[] = [], keepAssigned = true): DayPlanProposal {
  const safeHotel = [hotel.latitude, hotel.longitude].every(Number.isFinite) ? hotel : DEFAULT_HOTEL;
  const windows = dayWindows(flights);
  const active = places.filter((place) => !place.deleted && place.franked && place.category !== 'Unterkunft');
  const buckets: Record<number, Place[]> = Object.fromEntries(ITINERARY_DAYS.map((day) => [day, []]));
  const leftOver: ItineraryLeftOver[] = [];
  const free: Place[] = [];
  for (const place of active) {
    if (!coordinateFor(place)) { leftOver.push({ place, reason: 'missing_coordinates' }); continue; }
    if (keepAssigned && typeof place.day === 'number' && ITINERARY_DAYS.includes(place.day as ItineraryDay)) buckets[place.day].push(place);
    else free.push(place);
  }
  free.sort((a, b) => {
    const byAvailability = openDays(a).length - openDays(b).length;
    if (byAvailability) return byAvailability;
    return nearestDistance(coordinateFor(b)!, [], safeHotel) - nearestDistance(coordinateFor(a)!, [], safeHotel);
  });
  for (const place of free) {
    const options: { day: ItineraryDay; cost: number }[] = [];
    const availability = openDays(place);
    for (const day of availability) {
      const bucket = buckets[day];
      const meals = bucket.filter((item) => item.category === 'Essen & Trinken').length;
      if (place.category === 'Essen & Trinken' && meals >= 2) continue;
      const load = estimatedMinutes(bucket, safeHotel);
      const extra = visitMinutes(place) + walkingMinutes(nearestDistance(coordinateFor(place)!, bucket, safeHotel));
      if (load + extra > Math.floor(windows[day].minutes * MAX_DAY_LOAD)) continue;
      const longest = Math.max(...ITINERARY_DAYS.map((item) => windows[item].minutes), 1);
      const area = bucket.length ? nearestDistance(coordinateFor(place)!, bucket) : NEW_AREA_COST + (nearestDistance(coordinateFor(place)!, [], safeHotel) < 1_000 ? 0 : (1 - windows[day].minutes / longest) * 1_000);
      const mealCost = place.category === 'Essen & Trinken' ? meals * 700 : 0;
      const fullness = load / Math.max(windows[day].minutes, 1);
      options.push({ day, cost: area + mealCost + fullness * 800 });
    }
    const best = options.sort((a, b) => a.cost - b.cost)[0];
    if (best) buckets[best.day].push(place);
    else leftOver.push({ place, reason: availability.length ? 'capacity' : 'closed' });
  }
  const days: Record<number, PlanStop[]> = {};
  for (const day of ITINERARY_DAYS) days[day] = timeline(route(buckets[day], safeHotel), day, windows[day], safeHotel);
  return { days, windows, leftOver, hotel: safeHotel };
}
