/** Parsed subset of the OSM opening_hours syntax used by the day planner. */
export interface OpeningRange { start: number; end: number; }

const DAY_NAMES = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'] as const;
const DAY_INDEX = new Map<string, number>(DAY_NAMES.map((name, index) => [name, index]));

function minute(value: string): number | null {
  const match = /^(\d{1,2}):(\d{2})$/u.exec(value.trim());
  if (!match) return null;
  const hour = Number(match[1]);
  const minutes = Number(match[2]);
  if (!Number.isInteger(hour) || !Number.isInteger(minutes) || minutes > 59 || hour < 0 || hour > 24 || hour === 24 && minutes !== 0) return null;
  return hour * 60 + minutes;
}

function daySpec(value: string): number[] | null {
  const result: number[] = [];
  for (const piece of value.split(',')) {
    const bounds = piece.trim().split('-');
    const first = DAY_INDEX.get(bounds[0]);
    if (first === undefined) return null;
    if (bounds.length === 1) { result.push(first); continue; }
    if (bounds.length !== 2) return null;
    const last = DAY_INDEX.get(bounds[1]);
    if (last === undefined) return null;
    let current = first;
    while (true) {
      result.push(current);
      if (current === last) break;
      current = (current + 1) % 7;
    }
  }
  return result;
}

function ranges(value: string): OpeningRange[] | null {
  const result: OpeningRange[] = [];
  for (const part of value.split(',')) {
    const bounds = part.trim().split('-');
    if (bounds.length !== 2) return null;
    const start = minute(bounds[0]);
    let end = minute(bounds[1]);
    if (start === null || end === null) return null;
    if (end <= start) end += 1_440;
    result.push({ start, end });
  }
  return result;
}

export class OpeningHours {
  readonly week: readonly (readonly OpeningRange[])[];

  private constructor(week: OpeningRange[][]) { this.week = week; }

  static parse(raw: string | null | undefined): OpeningHours | null {
    if (typeof raw !== 'string') return null;
    const text = raw.trim().replace(/(Mo|Tu|We|Th|Fr|Sa|Su),\s+(?=Mo|Tu|We|Th|Fr|Sa|Su)/gu, '$1,');
    if (!text) return null;
    if (/^24\s*\/\s*7$/u.test(text)) return new OpeningHours(Array.from({ length: 7 }, () => [{ start: 0, end: 1_440 }]));

    const week: OpeningRange[][] = Array.from({ length: 7 }, () => []);
    let recognized = false;
    for (const rawRule of text.split(';').map((part) => part.trim()).filter(Boolean)) {
      if (/^(?:PH|SH)(?:\s|$)/u.test(rawRule)) continue;
      const parts = rawRule.split(/\s+/u);
      const parsedDays = daySpec(parts[0]);
      const days = parsedDays ?? Array.from({ length: 7 }, (_, index) => index);
      const timeText = parsedDays ? parts.slice(1).join(' ') : rawRule;
      if (!timeText) return null;
      let parsedRanges: OpeningRange[] | null;
      if (/^(?:off|closed)$/iu.test(timeText)) parsedRanges = [];
      else parsedRanges = ranges(timeText);
      if (parsedRanges === null) return null;
      recognized = true;
      for (const day of days) week[day] = parsedRanges.map((range) => ({ ...range }));
    }
    return recognized ? new OpeningHours(week) : null;
  }

  rangesFor(weekday: number): readonly OpeningRange[] {
    return Number.isInteger(weekday) && weekday >= 0 && weekday < 7 ? this.week[weekday] : [];
  }

  isOpen(weekday: number): boolean { return this.rangesFor(weekday).length > 0; }

  isOpenAt(weekday: number, atMinute: number): boolean {
    return this.rangesFor(weekday).some((range) => atMinute >= range.start && atMinute <= range.end);
  }

  summary(weekday: number): string {
    const dayRanges = this.rangesFor(weekday);
    if (!dayRanges.length) return 'geschlossen';
    return dayRanges.map((range) => `${OpeningHours.clock(range.start)}–${OpeningHours.clock(range.end)}`).join(', ');
  }

  static clock(value: number): string {
    if (value === 1_440) return '24:00';
    const normalized = ((value % 1_440) + 1_440) % 1_440;
    return `${String(Math.floor(normalized / 60)).padStart(2, '0')}:${String(normalized % 60).padStart(2, '0')}`;
  }
}

export function parseOpeningHours(raw: string | null | undefined): OpeningHours | null {
  return OpeningHours.parse(raw);
}

export function octoberWeekday(day: number): number {
  if (!Number.isInteger(day) || day < 1 || day > 31) return -1;
  return (new Date(Date.UTC(2026, 9, day)).getUTCDay() + 6) % 7;
}
