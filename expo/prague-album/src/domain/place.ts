export interface PlaceSeed {
  id: string;
  title: string;
  note: string;
  sourceURL: string;
  category: string;
  address?: string;
  lat?: number;
  lng?: number;
}

export interface Place extends PlaceSeed {
  author: string;
  image: Record<string, unknown> | null;
  franked: boolean;
  deferred: boolean;
  deleted: boolean;
  visited: boolean;
  day: number | null;
  dayOrder: number | null;
  approvals: string[];
  passedBy: string[];
  openingHours: string | null;
  gallery: Record<string, unknown>[] | null;
  updatedAt: number;
}

export type PlaceDecision = 'open' | 'approved' | 'opposed';
