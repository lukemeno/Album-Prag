# Prag Album (Expo)

This is the Expo Go client for the Prague trip. The native Swift app remains the fallback while migration work is in progress.

## Start on an iPhone

1. Install **Expo Go** from the App Store on each iPhone.
2. Keep both phones on the same Wi-Fi as this Mac.
3. From this folder, run `npm install` and `npx expo start --lan`.
4. Scan the terminal QR code with the iPhone camera and open it in Expo Go.
5. On the first phone, set a member name and tap **Gemeinsame Reise erstellen**. Copy the invitation code and send it to the other person.
6. On the second phone, enter that code under **Reise beitreten**.

Expo Go is a free App Store app, so this development path does not require either person to share an Apple account or pay for the Apple Developer Program. The QR session depends on the development server running on the Mac.

## Local configuration

Create `.env.local` with the Supabase project URL and its public publishable/anon key:

```text
EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-public-publishable-key
```

These values are public client configuration. Never add a Supabase service-role key or the OpenAI key to this file.

## Current scope

- Local SQLite ideas, voting, search and adding places.
- Anonymous Supabase sign-in, invite/create/join and place sync.
- Map markers with on-device place geocoding in small batches.
- JSON album import/export, including places, collection metadata and extracted document text.
- Imported collection posts/comments/reactions shown read-only.

The full native trip itinerary, collection editing, travel assistant, photo/PDF file sync and verified two-phone run are still open migration work. Keep using the Swift app as the source of truth until those are complete and checked.

## Checks

```bash
npm run check:prague-seeds
npx tsc --noEmit
npx expo lint
npx expo export --platform ios --output-dir /tmp/prague-album-expo-dist
npx expo-doctor
```
