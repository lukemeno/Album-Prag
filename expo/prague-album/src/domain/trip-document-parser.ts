import { applyTripFields, emptyHotel, type FlightLeg, type HotelDetails, type TripInfo } from '@/domain/trip';
export interface ExtractedTrip { flights: FlightLeg[]; hotelDetails: HotelDetails; bookingNumber: string | null; travelers: string[]; notes: string[]; }
const groups = (pattern: RegExp, text: string): string[] | null => { const match = pattern.exec(text); return match ? match.slice(1) : null; };
const first = (pattern: RegExp, text: string): string | null => groups(pattern, text)?.[0] ?? null;
export function normalizeTripText(raw: string): string { return raw.replace(/\u00a0/gu, ' ').replace(/ﬂ/gu, 'fl').replace(/ﬁ/gu, 'fi').replace(/(\d{1,2}:\d) (\d)\b/gu, '$1$2').replace(/(\d{2}\/\d{2}\/)(\d{2,3}) (\d{1,2})\b/gu, '$1$2$3').replace(/[ \t]+/gu, ' '); }
const airports: Record<string, string> = { KÖLN: 'Köln', COLOGNE: 'Köln', PRAG: 'Prag', PRAGUE: 'Prag', BERLIN: 'Berlin', MÜNCHEN: 'München', MUNICH: 'München', FRANKFURT: 'Frankfurt', HAMBURG: 'Hamburg', DÜSSELDORF: 'Düsseldorf', STUTTGART: 'Stuttgart' };
function pretty(value: string): string { return value.toLocaleLowerCase('de-DE').split('-').map((part) => part.split(' ').map((word) => word ? word[0].toLocaleUpperCase('de-DE') + word.slice(1) : word).join(' ')).join('-'); }
function flightCandidates(text: string): FlightLeg[] {
  const result: FlightLeg[] = []; const pattern = /\b([A-Z]{2}|[A-Z]\d|\d[A-Z]) ?(\d{2,4})\b(?=[^\n]*(?:Class|Klasse|Economy|Business)|[\s\S]{0,400}?\d{2}\/\d{2}\/\d{4})/gu;
  for (const match of text.matchAll(pattern)) {
    const number = `${match[1]}${match[2]}`; if (result.some((item) => item.number === number)) continue;
    const start = match.index ?? 0; const after = text.slice(start + match[0].length, start + match[0].length + 500);
    const times = groups(/(\d{2})\/(\d{2})\/(\d{4})\s*-?\s*(\d{1,2}:\d{2})[\s\S]{0,40}?(\d{2})\/(\d{2})\/(\d{4})\s*-?\s*(\d{1,2}:\d{2})/u, after);
    if (!times) continue;
    const before = text.slice(Math.max(0, start - 600), start); const cities = before.split(/\n|Details/gu).map((line) => line.trim().toUpperCase()).filter((line) => airports[line] || (/^[A-ZÄÖÜ ]{3,20}$/u.test(line) && !line.includes('BUCHUNG'))).map((line) => airports[line] ?? pretty(line));
    const section = text.slice(Math.max(0, start - 1000), start); const inbound = /Rück/iu.test(section) || result.length > 0;
    result.push({ direction: inbound ? 'inbound' : 'outbound', number, airline: null, from: cities[0] ?? 'Abflug', to: cities[1] ?? 'Ziel', date: `${times[0]}.${times[1]}.${times[2]}`, departure: times[3], arrival: times[7], arriveBy: null, bookingCode: first(/Buchungs\s*(?:referenz|code|nummer)[^:\n]{0,20}:\s*([A-Z0-9]{5,8})\b/iu, section) });
  }
  return result;
}
export function parseTripDocument(raw: string): ExtractedTrip {
  const text = normalizeTripText(raw); const hotel = emptyHotel();
  hotel.name = first(/^\s*(Hotel [^\n]{3,60}?)\s*(?:\d\*)?\s*$/imu, text);
  const hotelSection = text.split(/\nHotel\n/iu).pop() ?? text;
  hotel.address = first(/^\s*([^\n\d]{3,40}\s\d{1,4}[a-z]?,[^\n]{3,80}\d{3}\s?\d{2})\s*$/imu, hotelSection);
  hotel.checkIn = first(/Check-in:\s*(\d{1,2}:\d{2})/iu, text); hotel.checkOut = first(/Check-out:\s*(\d{1,2}:\d{2})/iu, text);
  const travelers = [...text.matchAll(/\b(?:Herr|Frau)\s+([A-ZÄÖÜ][A-ZÄÖÜ-]+)\s+([A-ZÄÖÜ][a-zäöüß-]+)/gu)].map((match) => `${match[2]} ${pretty(match[1])}`);
  const notes = []; const tax = text.split(/\n/gu).find((line) => /Tourismusabgabe|Kurtaxe|City Tax/iu.test(line)); if (tax) notes.push(tax.trim());
  if (/check-in erforderlich|obligatorischer check-in/iu.test(text.replace(/ /gu, ''))) notes.push('Online-Check-in ist Pflicht.');
  return { flights: flightCandidates(text), hotelDetails: hotel, bookingNumber: first(/^\s*(\d{6,}[A-Z]{2,6})\s*$/mu, text), travelers: [...new Set(travelers)], notes };
}
export function applyExtractedTrip(trip: TripInfo, extracted: ExtractedTrip): TripInfo { return applyTripFields(trip, { flights: extracted.flights, hotelDetails: extracted.hotelDetails, bookingNumber: extracted.bookingNumber ?? undefined, travelers: extracted.travelers, notes: extracted.notes.join('\n') }); }
