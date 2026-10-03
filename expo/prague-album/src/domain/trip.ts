export interface FlightLeg { direction: 'outbound' | 'inbound'; number: string; airline: string | null; from: string; to: string; date: string; departure: string; arrival: string; arriveBy: string | null; bookingCode: string | null; }
export interface HotelDetails { name: string | null; address: string | null; checkIn: string | null; checkOut: string | null; included: string[]; }
export interface TripInfo { hotel: string; outbound: string; arrival: string; route: string; flightNumber: string; notes: string; updatedAt: number; flights?: FlightLeg[]; hotelDetails?: HotelDetails; bookingNumber?: string; travelers?: string[]; }
export interface TravelDocument { id: string; name: string; filename: string; extractedText: string; storagePath: string | null; originalAvailable: boolean; updatedAt: number; }
export const emptyHotel = (): HotelDetails => ({ name: null, address: null, checkIn: null, checkOut: null, included: [] });
export const emptyTrip = (): TripInfo => ({ hotel: 'Hotel Urban Crème', outbound: '', arrival: '', route: '', flightNumber: '', notes: '', updatedAt: 0 });
export function applyTripFields(trip: TripInfo, extracted: Partial<TripInfo>): TripInfo {
  const next = { ...trip };
  if (extracted.flights?.length) next.flights = extracted.flights;
  const outbound = extracted.flights?.find((flight) => flight.direction === 'outbound') ?? extracted.flights?.[0];
  if (outbound) { next.flightNumber = outbound.number; next.outbound = outbound.departure; next.arrival = outbound.arrival; next.route = `${outbound.from} → ${outbound.to}`; }
  if (extracted.hotelDetails) { next.hotelDetails = extracted.hotelDetails; if (extracted.hotelDetails.name) next.hotel = extracted.hotelDetails.name; }
  for (const key of ['bookingNumber', 'travelers'] as const) if (extracted[key] !== undefined) next[key] = extracted[key] as never;
  if (extracted.notes?.trim()) next.notes = next.notes ? `${next.notes}\n${extracted.notes.trim()}` : extracted.notes.trim();
  next.updatedAt = Math.max(Date.now(), trip.updatedAt + 1);
  return next;
}
