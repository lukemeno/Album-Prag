import type { Place, PlaceDecision } from '@/domain/place';

export function myDecision(place: Place, memberName: string): PlaceDecision {
  if (place.approvals.includes(memberName)) return 'approved';
  if (place.passedBy.includes(memberName)) return 'later';
  return 'open';
}

export function decidePlace(place: Place, memberName: string, approve: boolean): Place {
  if (approve) {
    return {
      ...place,
      approvals: place.approvals.includes(memberName) ? place.approvals : [...place.approvals, memberName],
      passedBy: place.passedBy.filter((name) => name !== memberName),
      franked: true,
      deferred: false,
      updatedAt: Date.now(),
    };
  }

  return {
    ...place,
    approvals: place.approvals.filter((name) => name !== memberName),
    passedBy: place.passedBy.includes(memberName) ? place.passedBy : [...place.passedBy, memberName],
    updatedAt: Date.now(),
  };
}

export function isShared(place: Place): boolean {
  return new Set(place.approvals).size >= 2;
}
