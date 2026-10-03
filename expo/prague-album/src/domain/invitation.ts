export function invitationToken(input: string): string {
  const value = input.trim();
  if (/^[A-Za-z0-9_-]{32,256}$/u.test(value)) return value;
  try {
    const url = new URL(value);
    if ((url.protocol === 'album:' || url.protocol === 'praguealbum:') && url.hostname === 'join') {
      const token = decodeURIComponent(url.pathname.split('/').filter(Boolean)[0] ?? '');
      if (/^[A-Za-z0-9_-]{32,256}$/u.test(token)) return token;
    }
  } catch { /* The caller receives one clear validation error. */ }
  throw new Error('Bitte füge einen gültigen Einladungscode oder Album-Einladungslink ein.');
}
