# Gemeinsame Sammlung — ausführbarer Plan / Linear-Issue-Entwürfe

Stand: 2026-10-02. Der Umfang ist freigegeben; nach dieser Sol-Planung folgt die Umsetzung mit Luna. Ein passendes Linear-Projekt „Album“ wurde nicht gefunden; **SAM-1 bis SAM-5** sind deshalb Issue-Entwürfe und wurden nicht als echte Issues angelegt.

## Ziel und feste Produktentscheidungen

Unter **Ideen** entsteht ein dauerhaft sichtbarer Einstieg **Sammlung**. Die bestehende Ideen-Wischansicht bleibt erhalten; oben schaltet ein nativer segmentierter Picker zwischen **Entdecken** und **Sammlung** um. Es gibt keinen zusätzlichen Haupt-Tab.

Die Sammlung nimmt Links und reine Nachrichten sofort lokal an. Titel, Ort, Netzwerk und Vorschau sind keine Voraussetzung. Ein Beitrag kann Kommentare, Herzen und mehrere bewusst hinzugefügte Orte haben. Kommentare, Reaktionen und Ortsverknüpfungen sind eigenständige Datensätze; sie werden nie als veränderliche Arrays im Beitrag gespeichert.

Nicht im Umfang: automatische Ortserkennung aus Social-Captions, Diktat, Push-Mitteilungen, Medien-Uploads für Sammlungsposts, mehrere gleichzeitig geöffnete Reisen und automatische Zusammenführung unbekannter Kurzlinks. Einen vorhandenen Ort zusätzlich anzuhängen kann später folgen.

## Gemeinsame Invarianten

1. **Lokal zuerst:** Ein gültiger Beitrag wird vor jeder Metadaten- oder Netzwerkanfrage atomar in `album.json` gespeichert. Ein fehlgeschlagener Sync oder eine fehlende Backend-Migration löscht keine lokale Eingabe.
2. **Stabile Identität:** `participantID` ist eine einmal erzeugte Installations-UUID in `UserDefaults` (`album.participantID`). Der Anzeigename bleibt veränderlich und wird nur als Snapshot gespeichert. Kommentare und Herzen vergleichen niemals Namen; Tests können die Identität injizieren.
3. **Unabhängige Records:** Beitrag, Kommentar, Reaktion und Ortsverknüpfung besitzen eigene ID, Version und Tombstone. Löschen bedeutet `deleted = true`; „Herz entfernen“ schreibt `active = false` und bleibt synchronisierbar.
4. **Keine falschen Orte:** Metadaten dürfen Feedtitel, Caption und Vorschaubild ergänzen, aber niemals `PlaceEditor`-Titel oder MapKit-Query setzen. Eine Ortsverknüpfung entsteht nur nach bewusstem, erfolgreichem Speichern.
5. **Versionssicherer Sync:** Collection-Records werden nie blind `upsert`-et. Insert und Update verwenden die Serverversion als Compare-and-swap-Bedingung. Dirty wird nur für genau die gesendete lokale Mutation bestätigt.
6. **Explizites Share-Ziel:** Die Haupt-App schreibt einen `ShareContext` mit aktuellem `tripKey` in die App Group. Jedes Queue-Element übernimmt ihn. Import erfolgt nur bei exakter Übereinstimmung; fehlende oder fremde Ziele bleiben erhalten.

## Daten- und Konfliktmodell

### Lokale Modelle

Neue Dateien halten die Sammlung aus `Place` heraus, beispielsweise `CollectionModels.swift`, `CollectionStore.swift`, `CollectionViews.swift` sowie das von App und Extension gemeinsam kompilierte `Shared/ShareInbox.swift`.

`CollectionEntry` ist `Codable`, `Equatable` und `Identifiable`:

- `id`, `kind` (`post`, `comment`, `reaction`, `placeLink`) und optionales `postID`
- `authorID`, `authorName`, `createdAt`, `updatedAt`
- für Beiträge `text`, `url`, `canonicalURL`, `displayTitle`, `caption`, `thumbnailURL`, `metadataState`
- für Verknüpfungen `placeID`, für Reaktionen `active`, für alle `deleted`

Lokale Sync-Metadaten bleiben außerhalb des Server-Payloads in `collectionSync[id]`: `serverVersion`, `mutationToken` und optional letzter Fehlercode. Jede lokale Änderung erzeugt ein neues `mutationToken` und markiert `collection:<id>` in der vorhandenen Dirty-Menge. Damit kann ein laufender Upload eine spätere lokale Änderung nicht quittieren.

`AlbumData` erhält `albumID`, `collectionEntries` und `collectionSync`. Ein eigener `init(from:)` liest neue Felder mit `decodeIfPresent`; alte Dateien ohne diese Schlüssel laden unverändert. Bestehende Orte, Reise, Dokumente, Dirty-Marker und Collaboration-Daten behalten ihre bisherigen Defaults und Codierpfade.

### IDs und Duplikate

- Linkbeitrag: `post-` plus SHA-256 der kanonischen URL. Zwei Geräte konvergieren beim selben Clip auf dieselbe ID.
- Textbeitrag und Kommentar: UUID; beim Share-Import wird die Queue-ID Teil der deterministischen ID, damit Wiederholung idempotent bleibt.
- Reaktion: Hash aus `postID + participantID`; `active=false` ist der Unlike-Tombstone.
- Ortsverknüpfung: Hash aus `postID + placeID`; mehrere verschiedene Orte bleiben möglich.

Kanonisierung akzeptiert nur HTTP(S), normalisiert Scheme/Host, Default-Port, Fragment und Pfadform. Bekannte Trackingparameter (`utm_*`, `fbclid`, `gclid`, `igshid`/`igsh`) werden entfernt; unbekannte Parameter bleiben sortiert erhalten. TikTok `/@…/video/<id>` und Instagram `/p|reel|tv/<shortcode>` werden auf genau diesen Clip reduziert. Unterschiedliche IDs/Shortcodes dürfen nie zusammenfallen. Nicht auflösbare Kurzlinks behalten ihre eigene URL; die Extension macht keinen Netzwerkaufruf.

Bei gleichzeitigem Link-Insert gewinnt genau ein Insert; der Verlierer lädt den vorhandenen Record. Eine optionale persönliche Nachricht zu einem Link ist ein eigener Kommentar und kein konkurrierendes Feld im kanonischen Beitrag. Async-Metadaten füllen nur leere verwaltete Felder; manuelle Inhalte bleiben erhalten.

### Metadatenzustand

Linkbeiträge speichern sofort einen neutralen Titel wie `TikTok-Link`, `Instagram-Link` oder den Host. Danach darf die bestehende `OEmbedService` Caption, Autor und Thumbnail ergänzen. `metadataState` ist persistent (`pending`, `available`, `unavailable`, `cancelled`) und bietet Retry. Die volle Social-Caption landet ausschließlich in `caption`; der kompakte Feedtitel ist etwa `TikTok · @creator`. Generation beziehungsweise `mutationToken` schützt Linkwechsel, manuelle Änderungen, Abbruch und verspätete Ergebnisse. `SourceMetadataPolicy` des Ortseditors wird hierfür nicht verwendet.

## SAM-1 — Lokales Modell, Store und Sammlungseinstieg

**Ziel:** Links und Nachrichten ohne Ort oder Netzwerk dauerhaft sammeln und unter Ideen erreichen.

**Abhängigkeit:** Keine; bildet die lokale Grundlage für alle weiteren Issues.

**Umfang**

- Modelle, rückwärtskompatibles `AlbumData`, Teilnehmer-ID und URL-Kanonisierung ergänzen.
- `AlbumStore` um testbare Mutationen erweitern: Beitrag/Kommentar anlegen oder tombstonen, Herz setzen/entfernen, Ort verknüpfen/lösen. Jede Mutation persistiert zuerst, setzt ein Mutation-Token und plant danach Sync.
- Unter `InboxView` einen nativen Picker **Entdecken / Sammlung** einbauen. Sammlung zeigt neueste Beiträge zuerst; Detail zeigt Caption, Kommentare chronologisch, Herzstatus/-zahl und Orte.
- Composer als native Sheet/Form: Nachricht oder Link, optionale Nachricht, lokaler Fehler bei ungültigem Inhalt. Metadaten laufen erst nach erfolgreichem Speichern.
- Neutraler Ersatz bei fehlendem Thumbnail, externer Link bleibt öffnbar. Dynamic Type, Tastatur, Portrait und Querformat mit vorhandenen `Stitch`-Stilen berücksichtigen.

**Akzeptanz**

- Reine Nachricht und echter Link lassen sich offline speichern und überstehen Neustart.
- Lange Social-Caption erscheint im Detail, aber nie als MapKit-Query.
- Gleichnamige Personen bleiben durch IDs getrennt.
- Gleiche Link-URL erzeugt einen Beitrag; verschiedene Clips bleiben verschieden.
- Alte `album.json`-Dateien laden ohne Datenverlust.

**Tests**

- Altes JSON ohne Collection-Felder dekodieren und erneut speichern.
- TikTok-/Instagram-Kanonisierung, Trackingparameter, bedeutungsvolle Parameter, verschiedene Clips.
- Textpost-UUID, Link-ID und doppelter Link mit zwei unabhängigen Notizen.
- Store-Neustart, Persistenzfehler sowie Metadaten nach manueller Änderung/Abbruch.
- XCUI: Sammlung öffnen, Offline-Nachricht anlegen, Detail wieder öffnen.

## SAM-2 — Kommentare, Herzen und mehrere Orte

**Ziel:** Mitglieder reagieren unabhängig und verknüpfen bewusst mehrere Orte.

**Abhängigkeit:** SAM-1.

**Umfang**

- Kommentare als eigene Records mit UUID und `postID`; Löschen setzt Tombstone.
- Ein Herz pro `postID + participantID`; erneutes Tippen schreibt denselben Record mit `active=false`. Gezählt werden nur aktive, nicht gelöschte Reaktionen.
- Ortsverknüpfungen als eigene Records. Das Detail zeigt alle vorhandenen Orte und öffnet die bestehende Ortsdetailansicht.
- `PlaceEditor` erhält kompatible Defaults `autoSourceEnrichment = true` und `onSaved`. Collection öffnet einen leeren, manuell zu benennenden Ort mit ursprünglicher Source-URL und `autoSourceEnrichment = false`.
- `AlbumStore.upsert` oder ein schmaler Wrapper meldet Persistenzerfolg. Erst danach entsteht `placeLink`; Abbrechen erzeugt weder Ort noch Verbindung.

**Akzeptanz**

- Gleichzeitige Kommentare überschreiben sich nicht.
- Gleichnamige Personen setzen getrennte Herzen; Offline-Unlike bleibt entfernt.
- Abbruch im Ortseditor hinterlässt keine Verknüpfung.
- Zwei verschiedene Orte lassen sich demselben Clip hinzufügen und einzeln lösen.
- Reguläre Ortseditor-Flows behalten bisherige Vorschau und Suche.

**Tests**

- Kommentar-IDs, Reaktion pro stabiler Identität und Unlike-Tombstone.
- Zwei Ortsverknüpfungen, idempotente gleiche Verknüpfung und gelöschter Ort.
- Save-Callback nur nach erfolgreicher Persistenz; Cancel ohne Seiteneffekt.
- XCUI: Kommentar, Herz an/aus, Ortseditor abbrechen, zwei Orte speichern.

## SAM-3 — Supabase-Sync mit CAS und RLS

**Ziel:** Gemeinsame Records synchronisieren, ohne dass langsame oder gleichzeitige Writes neuere Daten überschreiben.

**Abhängigkeit:** SAM-1 und SAM-2; Migration-Deployment durch den Parent vor der Live-Abnahme.

**Migration `supabase/migrations/202610020001_collection_entries.sql`**

- Tabelle `public.collection_entries`: `trip_id uuid` mit FK/Cascade, `id text`, `payload jsonb`, `version bigint default 1`, `deleted boolean`, `updated_at timestamptz default now()`, Primärschlüssel `(trip_id,id)` und Index `(trip_id,updated_at desc)`.
- Trigger setzt `updated_at` serverseitig; Clientzeit ist kein Konfliktschutz.
- RLS für `select`, `insert`, `update` nur `authenticated` und `public.is_trip_member(trip_id)`; keine Delete-Policy, keine `anon`-Rechte, nur nötige Grants.
- Additiv zur Realtime-Publikation hinzufügen.

Die Instanz `akzrlkbylglwrlbaacjo` hat aktuell eine Reise mit drei Mitgliedern; die Tabelle fehlt. Der Parent deployt die Migration vor Live-Sync. Ohne Migration bleibt lokale Sammlung erhalten und zeigt verständlichen Sync-Fehler.

**Client-Protokoll**

1. Pull lädt alle Rows. Saubere lokale Records folgen höherer Serverversion. Bei lokal Dirty bleibt die lokale Absicht bestehen: Tombstone dominiert, Metadaten füllen nur Lücken, Kommentarinhalt ist nach Erstellung unveränderlich, Reaktion/Ortslink behalten lokale Aktivität für CAS-Retry.
2. Pro Dirty-Record Snapshot aus Payload, `serverVersion` und `mutationToken` nehmen.
3. Neue Row mit `insert`, nie `upsert`. Bei Unique-Konflikt vorhandene Row laden und typgerecht mergen; so konvergieren kanonische Links.
4. Update nur mit `where trip_id/id/version == expected`, gleichzeitig `version = expected + 1`, und Row zurückgeben. Null Rows bedeutet Konflikt: aktuell laden, mergen und höchstens zweimal erneut versuchen. Danach bleibt Dirty samt sichtbarem Fehler.
5. Nach Ack `serverVersion` aktualisieren. `collection:<id>` nur löschen, wenn das aktuelle `mutationToken` noch dem Snapshot entspricht. Eine Änderung während `await` bleibt Dirty.
6. Realtime beobachtet zusätzlich `collection_entries` und stößt den bestehenden gebündelten Sync an. Place-/Document-/Trip-Sync bleibt unverändert.

**Akzeptanz**

- RLS trennt Reisen; Fremde können weder lesen noch schreiben.
- Zwei Kommentare und zwei Herzen bleiben erhalten; Unlike konvergiert auf inaktiv.
- Änderung während Upload bleibt Dirty.
- Zwei gleichzeitige Link-Inserts ergeben einen Beitrag ohne Notizverlust.
- Veralteter Client überschreibt keine höhere Serverversion.

**Tests**

- Fake-Sync mit angehaltenem `await`: Mutation nach Snapshot, Ack entfernt Marker nicht.
- CAS-Konflikt, Merge, begrenzter Retry und persistierter Fehler.
- Typregeln und Tombstones.
- Migration/RLS als Mitglied und Fremder, Realtime, Unique-Konflikt.

## SAM-4 — Native Share Extension und verlustfreie App-Group-Queue

**Ziel:** Aus TikTok, Instagram und Safari direkt in die aktuelle Sammlung teilen, auch bei beendeter/offliner Haupt-App.

**Abhängigkeit:** SAM-1; App-Group- und Signing-Freigabe für die native End-to-End-Prüfung.

**Projektintegration**

- App Group `group.de.privatealbum.prague` in App- und Extension-Entitlements.
- Extension-Bundle `de.privatealbum.prague.share`, Name `Album`, iOS 17, `APPLICATION_EXTENSION_API_ONLY = YES`, `SKIP_INSTALL = YES`.
- `project.yml`: Shared-Quellen in beiden Targets, Share-Target und eingebettete Abhängigkeit; danach Projekt regenerieren und **Embed App Extensions** prüfen.
- Aktivierungsregel als Dictionary für höchstens eine Web-URL und Text, kein `TRUEPREDICATE`.
- Apple Developer/Automatic Signing muss die App Group für beide Bundle-IDs und Profile enthalten.

**Ablauf und Routing**

- Native UIKit/SwiftUI-Extension liest `public.url` und Text mit HTTP(S)-URL über `NSItemProvider`/`UniformTypeIdentifiers`. Kein Netzwerk, Auth oder Öffnen der App.
- Composer zeigt Quelle, optionale Nachricht und neutralen Previewzustand. Erst „In Album sammeln“ schreibt. Abbruch schreibt nichts; Fehler bleiben sichtbar und behalten den Entwurf.
- Main veröffentlicht atomar `ShareContext` mit `tripKey`: bei gemeinsamer Reise `trip:<UUID>`, sonst `local:<albumID>`. Isolierte Teststores verändern Produktionskontext/Queue nur bei expliziter Injection.
- Fehlt Container oder Context, meldet die Extension „Album einmal öffnen“ und schließt nicht erfolgreich.

**Queue-Protokoll**

- Ein `ShareQueueItem` pro UUID-Datei: Payload, optionale Notiz, `tripKey`, `createdAt`, `attemptCount`, `state` (`pending`, `failed`, `cancelled`) und `lastErrorCode`.
- Temporärdatei plus atomare Umbenennung; Queue-ID bleibt über Retries stabil.
- Main drainiert bei Start und `.active`, aber nur bei exakt passendem `tripKey`. Mismatch, fehlendes Ziel, Decode- oder Persistenzfehler bleiben `failed` und werden nie gelöscht oder falsch importiert.
- Datei erst nach erfolgreicher lokaler Persistenz entfernen. Textpost-/Notiz-ID aus Queue-ID, Linkpost-ID aus Canonical URL: Ein Crash zwischen Persistenz und Entfernen dupliziert nichts.
- Sammlung zeigt fehlgeschlagene Imports knapp mit **Erneut versuchen** und **Verwerfen**. Verwerfen ist ausdrücklich; ein Lease/Zustand verhindert parallelen Doppelimport.

**Akzeptanz**

- Teilen funktioniert ohne Ort, Netzwerk oder laufende App.
- Neustart importiert genau einmal in die passende Reise.
- Fehlende App Group, fehlender Context, Schreibfehler und Zielwechsel verlieren nichts.
- Wiederholtes Drainen erzeugt keine doppelten Beiträge/Notizen.

**Tests**

- Foundation-Tests für URL/Text-Extraktion, atomisches Schreiben/Lesen, beschädigte Datei, Retry, Verwerfen und Persistenzfehler.
- Matching, Mismatch und fehlender `tripKey`; zweimaliges Drainen derselben Datei.
- XCUI: vorbereitete Queue importieren und nach Neustart genau einmal zeigen.
- Manueller nativer Share-Test aus Safari/TikTok auf signiertem Simulator/Gerät, App vorher beendet.

## SAM-5 — Integration und echte Zwei-Teilnehmer-Abnahme

**Abhängigkeit:** SAM-1 bis SAM-4 sowie deployte Migration und gültige Signierung.

**Reihenfolge:** SAM-1 lokal → SAM-2 Interaktionen → SAM-3 Migration und Sync → SAM-4 Target/Signing → vollständige Regression. Unit-Tests haben keine Live-Netzabhängigkeit.

**Live-Abnahme**

- A und B treten derselben Reise bei; eine dritte fremde Session bestätigt RLS-Abweisung.
- A/B legen offline gleichzeitig denselben kanonischen Link an: nach Sync genau ein Beitrag.
- Beide kommentieren und setzen Herzen: zwei Kommentare, zwei Herzen. A entfernt offline sein Herz: nach Reconnect genau ein Herz.
- Während angehaltenem Sync entsteht eine weitere lokale Änderung: sie bleibt Dirty und erscheint nach Folgesync auf B.
- Zwei Orte werden manuell mit demselben Clip verknüpft; Abbruch eines dritten erzeugt nichts.
- Safari/TikTok teilt bei beendeter App; nach Start erscheint der Beitrag einmal. Nach Wechsel des `tripKey` wird eine alte Queue nicht automatisch importiert.
- Portrait, Querformat, Dynamic Type und VoiceOver-Reihenfolge prüfen. Für UI-Belege bevorzugt XCUI mit Accessibility-IDs; eine kurze Aufnahme ergänzt nur den nativen Share-Flow.

## Erwartete Dateien und Grenzen

Voraussichtlich neu: Collection-Model/Store/UI, `Shared/ShareInbox.swift`, Share-Extension und Entitlements, Supabase-Migration, fokussierte Tests. Schmale Änderungen: `Models.swift`, `AlbumStore.swift`, `SupabaseSync.swift`, `AlbumRoot.swift`/`InboxView.swift`, `AlbumApp.swift`, `PlaceEditor.swift`, `project.yml`.

Bestehende Kartenblatt-, Bildfallback-, Google-Link-, Design- und Ortslogik bleibt erhalten. `PlaceEditor` behält Defaults; nur Collection deaktiviert Source-Enrichment ausdrücklich. Bestehender Place-/Trip-/Document-Sync wird nicht auf CAS umgestellt.

## Externe Voraussetzungen

Keine offene Produktentscheidung blockiert den lokalen Start. Für vollständige Auslieferung übernimmt der Parent:

- Migration im Projekt `akzrlkbylglwrlbaacjo` deployen und prüfen.
- App Group/Provisioning für `de.privatealbum.prague` und `de.privatealbum.prague.share` im Team `X7K385PZ68` freischalten.
- Zwei getrennte Teilnehmer-Sessions für Live-Abnahme bereitstellen.

Fehlt etwas davon, werden lokale Funktion, Queue und Tests trotzdem fertiggestellt; Backend- oder Signing-Erfolg wird ausdrücklich als ungeprüft ausgewiesen.
