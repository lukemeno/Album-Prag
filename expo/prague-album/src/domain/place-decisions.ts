import type { Place, PlaceDecision } from '@/domain/place';

export function myDecision(place: Place, memberName: string): PlaceDecision {
  if (place.approvals.includes(memberName)) return 'approved';
  if (place.passedBy.includes(memberName)) return 'opposed';
  return 'open';
}

export function decidePlace(place: Place, memberName: string, decision: PlaceDecision): Place {
  const approvals = place.approvals.filter((name) => name !== memberName);
  const passedBy = place.passedBy.filter((name) => name !== memberName);

  if (decision === 'approved') approvals.push(memberName);
  if (decision === 'opposed') passedBy.push(memberName);

  return {
    ...place,
    approvals,
    passedBy,
    franked: approvals.length > 0,
    deferred: false,
    updatedAt: Date.now(),
  };
}

export function isShared(place: Place): boolean {
  return new Set(place.approvals).size >= 2;
}
