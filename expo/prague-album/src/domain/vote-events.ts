import type { PlaceDecision } from '@/domain/place';

export interface VoteEvent { choice: PlaceDecision; at: number; }
export type VoteEvents = Record<string, VoteEvent>;

export function parseVoteEvents(value: unknown): VoteEvents {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return Object.fromEntries(Object.entries(value).slice(0, 100).flatMap(([name, raw]) => {
    if (!name.trim() || !raw || typeof raw !== 'object') return [];
    const event = raw as Partial<VoteEvent>;
    return (event.choice === 'approved' || event.choice === 'later' || event.choice === 'open') && typeof event.at === 'number' && Number.isFinite(event.at)
      ? [[name, { choice: event.choice, at: event.at }]] : [];
  }));
}

export function mergeVoteEvents(left: VoteEvents, right: VoteEvents): VoteEvents {
  const result: VoteEvents = Object.assign(Object.create(null), left);
  for (const [name, incoming] of Object.entries(right)) {
    const previous = result[name];
    if (!previous || incoming.at > previous.at || incoming.at === previous.at && incoming.choice.localeCompare(previous.choice) > 0) result[name] = incoming;
  }
  return result;
}

export function legacyVoteEvents(approvals: string[], passedBy: string[], at: number, existing: VoteEvents = {}): VoteEvents {
  const result: VoteEvents = Object.assign(Object.create(null), existing);
  for (const name of passedBy) if (!result[name]) result[name] = { choice: 'later', at };
  for (const name of approvals) if (!existing[name]) result[name] = { choice: 'approved', at };
  return result;
}

export function voteLists(events: VoteEvents): { approvals: string[]; passedBy: string[] } {
  const names = Object.keys(events).sort();
  return { approvals: names.filter((name) => events[name].choice === 'approved'), passedBy: names.filter((name) => events[name].choice === 'later') };
}
