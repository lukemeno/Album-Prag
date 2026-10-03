import { mkdirSync, writeFileSync } from 'node:fs';

const objects = [
  '<< /Type /Catalog /Pages 2 0 R >>',
  '<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>',
  '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 7 0 R >>',
  '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 8 0 R >>',
  '<< /Length 0 >>\nstream\n\nendstream',
  '<< /Length 77 >>\nstream\nBT /F1 18 Tf 72 700 Td (Prague Trip Probe Page One) Tj 0 -36 Td (Flight EW123 04/10/2026 12:45) Tj ET\nendstream',
  '<< /Length 83 >>\nstream\nBT /F1 18 Tf 72 700 Td (Prague Trip Probe Page Two) Tj 0 -36 Td (Hotel Example, Prague) Tj ET\nendstream',
];
let pdf = '%PDF-1.4\n';
const offsets = [0];
for (let index = 0; index < objects.length; index += 1) {
  offsets[index + 1] = Buffer.byteLength(pdf, 'binary');
  pdf += `${index + 1} 0 obj\n${objects[index]}\nendobj\n`;
}
const xref = Buffer.byteLength(pdf, 'binary');
pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n${offsets.slice(1).map((offset) => `${String(offset).padStart(10, '0')} 00000 n `).join('\n')}\ntrailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
mkdirSync('src/assets', { recursive: true });
writeFileSync('src/assets/pdf-probe.pdf', pdf, 'binary');
