import { readFileSync } from 'node:fs';

const swiftPath = new URL('../../../Album/Models.swift', import.meta.url);
const seedPath = new URL('../src/data/prague-ideas.json', import.meta.url);
const swift = readFileSync(swiftPath, 'utf8');
const sourceStart = swift.indexOf('static let examples: [Place] = [');
const sourceEnd = swift.indexOf('private static func suggestion', sourceStart);
if (sourceStart < 0 || sourceEnd < 0) throw new Error('Could not locate Place.examples in Album/Models.swift');

const block = swift.slice(sourceStart, sourceEnd);
const expected = new Set([
  ...Array.from(block.matchAll(/suggestion\("([^"]+)"/g), (match) => `prague-${match[1]}`),
  ...Array.from(block.matchAll(/Place\(id:\s*"(prague-[^"]+)"/g), (match) => match[1]),
]);
const seeds = JSON.parse(readFileSync(seedPath, 'utf8'));
const actual = new Set(seeds.map((place) => place.id));
const missing = [...expected].filter((id) => !actual.has(id));
const extra = [...actual].filter((id) => !expected.has(id));
const duplicateCount = seeds.length - actual.size;

if (missing.length || extra.length || duplicateCount) {
  throw new Error(JSON.stringify({ missing, extra, duplicateCount }, null, 2));
}

console.log(`${actual.size} Expo idea IDs match the Swift seed.`);
