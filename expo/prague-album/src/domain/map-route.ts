import type { Place } from '@/domain/place';

export const TRIP_DAYS = [4, 5, 6, 7, 8, 9] as const;
export type TripDay = typeof TRIP_DAYS[number];
export type MapFilter = 'all' | 'approved' | 'visited' | { day: TripDay };
export interface Coordinate { latitude: number; longitude: number; }
export interface RoutePoint { coordinate: Coordinate; placeID?: string; label: string; }

export const OLD_TOWN: Coordinate = { latitude: 50.0875, longitude: 14.4213 };

export function sameMapFilter(left: MapFilter, right: MapFilter): boolean {
  if (typeof left === 'string' || typeof right === 'string') return left === right;
  return left.day === right.day;
}

export function validCoordinate(value: Pick<Place, 'lat' | 'lng'> | Coordinate | null | undefined): Coordinate | null {
  if (!value) return null;
  if ('latitude' in value) {
    const coordinate = value as Coordinate;
    if (!coordinate || !Number.isFinite(coordinate.latitude) || !Number.isFinite(coordinate.longitude) || coordinate.latitude < -90 || coordinate.latitude > 90 || coordinate.longitude < -180 || coordinate.longitude > 180) return null;
    return { latitude: coordinate.latitude, longitude: coordinate.longitude };
  }
  if (typeof value.lat !== 'number' || typeof value.lng !== 'number' || !Number.isFinite(value.lat) || !Number.isFinite(value.lng) || value.lat < -90 || value.lat > 90 || value.lng < -180 || value.lng > 180) return null;
  return { latitude: value.lat, longitude: value.lng };
}

export function hotelCoordinate(places: readonly Place[]): Coordinate {
  const hotel = places.find((place) => !place.deleted && place.franked && place.category === 'Unterkunft' && validCoordinate(place));
  return validCoordinate(hotel) ?? OLD_TOWN;
}

export function haversineMeters(a: Coordinate, b: Coordinate): number {
  if (![a.latitude, a.longitude, b.latitude, b.longitude].every(Number.isFinite)) return Number.POSITIVE_INFINITY;
  const radians = Math.PI / 180;
  const dLat = (b.latitude - a.latitude) * radians;
  const dLng = (b.longitude - a.longitude) * radians;
  const latA = a.latitude * radians;
  const latB = b.latitude * radians;
  const value = Math.sin(dLat / 2) ** 2 + Math.cos(latA) * Math.cos(latB) * Math.sin(dLng / 2) ** 2;
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(Math.max(0, value)), Math.sqrt(Math.max(0, 1 - value)));
}

export function filterPlaces(places: readonly Place[], filter: MapFilter): Place[] {
  return places.filter((place) => {
    if (place.deleted) return false;
    if (filter === 'all') return true;
    if (filter === 'approved') return place.franked;
    if (filter === 'visited') return place.visited;
    return place.franked && place.day === filter.day;
  });
}

export function sortNearby<T extends { lat?: number; lng?: number }>(places: readonly T[], origin: Coordinate | null): T[] {
  if (!origin) return [...places];
  return [...places].sort((a, b) => {
    const aCoordinate = validCoordinate(a as Pick<Place, 'lat' | 'lng'>);
    const bCoordinate = validCoordinate(b as Pick<Place, 'lat' | 'lng'>);
    const aDistance = aCoordinate ? haversineMeters(origin, aCoordinate) : Number.POSITIVE_INFINITY;
    const bDistance = bCoordinate ? haversineMeters(origin, bCoordinate) : Number.POSITIVE_INFINITY;
    return aDistance - bDistance;
  });
}

export function routeSegments(stops: readonly Place[], hotel: Coordinate = OLD_TOWN): RoutePoint[][] {
  const points: RoutePoint[] = [{ coordinate: hotel, label: 'Start am Hotel' }, ...stops.flatMap((place) => {
    const coordinate = validCoordinate(place);
    return coordinate ? [{ coordinate, placeID: place.id, label: place.title }] : [];
  }), { coordinate: hotel, label: 'Zurück zum Hotel' }];
  if (points.length < 3) return [];
  const segments: RoutePoint[][] = [];
  let start = 0;
  while (start < points.length - 1) {
    const end = Math.min(start + 4, points.length - 1);
    segments.push(points.slice(start, end + 1));
    if (end === points.length - 1) break;
    start = end;
  }
  return segments;
}

export function googleWalkingURL(segment: readonly RoutePoint[]): string {
  if (segment.length < 2) throw new Error('Eine Route braucht mindestens zwei gültige Punkte.');
  const origin = segment[0].coordinate;
  const destination = segment[segment.length - 1].coordinate;
  const waypoints = segment.slice(1, -1).map((point) => `${point.coordinate.latitude},${point.coordinate.longitude}`).join('|');
  const params = [`api=1`, `origin=${encodeURIComponent(`${origin.latitude},${origin.longitude}`)}`, `destination=${encodeURIComponent(`${destination.latitude},${destination.longitude}`)}`, 'travelmode=walking'];
  if (waypoints) params.push(`waypoints=${encodeURIComponent(waypoints)}`);
  return `https://www.google.com/maps/dir/?${params.join('&')}`;
}
