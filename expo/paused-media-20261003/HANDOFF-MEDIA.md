# Handoff: Expo media slice

Arbeitskopie: `/tmp/prague-expo-media-20261003`

## Angelegt/geändert

- `src/storage/database.ts`
  - Migration von SQLite user_version 2 auf 3.
  - Neue Tabelle `local_media(image_id, place_id, path, storage_path, updated_at)` plus Place-Index.
- `src/domain/place-images.ts`
  - Native kompatible JSON-Typen und Guards für `uploaded`, `external`, `linkPreview`, `bundled`.
  - Erkennung eigener Fotos, Ortsbindung, Ortswechsel und Remote-/Quell-URLs.
- `src/storage/place-media.ts`
  - Expo-57-ImageManipulator-Pipeline für ausgewählte Fotos: Resize auf 1600px, JPEG 0.8, 5-MB-Grenze.
  - Dauerhafte Ablage unter `Paths.document/place-images` und `local_media`-Mapping.
  - Entfernen lokaler Medien.
  - `syncPlaceMedia(db, tripID)` für Upload in privaten Storage-Pfad `tripID/placeID/imageID.jpg`, bevor der Parent Place-Referenzen veröffentlicht.
  - `cacheRemotePlaceImage` für Signed-URL-Download (30 Minuten) in den dauerhaften lokalen Cache.

## Fertig

- Expo 57 Dokumentation für ImageManipulator, ImagePicker, FileSystem, Crypto und Clipboard wurde gelesen.
- `expo-crypto` und `expo-image-manipulator` sind in der Arbeitskopie verfügbar.
- Keine Primary-Dateien wurden bearbeitet.

## Unfertig

- `src/storage/place-editor.ts` fehlt noch: atomisches Draft-Speichern, Vote-Erhalt, Delete/Restore, Location- und Tagesfelder.
- `src/storage/link-preview.ts` fehlt noch: TikTok oEmbed/Redirect/HTML-Metadaten mit 2-MB-/12-Sekunden-Limits.
- `src/components/place-photo.tsx` fehlt noch.
- `src/app/place/[id].tsx` fehlt noch.
- `src/app/(tabs)/ideen.tsx` muss um echte Pressable-Navigation, Foto-/Link-Metadaten und Archivliste ergänzt werden.
- `src/app/_layout.tsx` braucht die `/place/[id]`-Route.
- `place-media.ts` braucht noch Backend-Suche für `place-photo` inklusive Candidate-Auswahl und stale request guards im Editor.
- `syncPlaceMedia` ist absichtlich nicht in `trip-sync.tsx` integriert; Parent soll es vor dem Publizieren der Place-Payload aufrufen.
- `src/storage/place-media.ts` und `src/storage/database.ts` wurden noch nicht typegeprüft.

## Hinweise für die Fortsetzung

- `Place.image` und `Place.gallery` sind im aktuellen Expo-Modell noch generische Record-Typen. Die neuen JSON-Helper kapseln die native Enum-Form, ohne bisherige Store-/Sync-Dateien zu verändern.
- `place-media.ts` nutzt die SDK-57-modern API (`File.bytes`, `File.write`, `Directory.create`, `ImageManipulator.manipulate(...).renderAsync().saveAsync`).
- Die Parent-Integration sollte beim Sync erst `syncPlaceMedia(db, tripID)` abwarten und dann die Place-Payload mit `storagePath` veröffentlichen.
