# Album, unser Prag-Album

Native SwiftUI-App für die Reise nach Prag vom 4. bis 9. Oktober 2026. Daten bleiben offline auf jedem iPhone verfügbar und können über ein privates Supabase-Projekt zwischen zwei Geräten synchronisiert werden.

## Lokal starten

1. `Album.xcodeproj` in Xcode öffnen.
2. Das Schema **Album** und einen iPhone-Simulator wählen.
3. Mit `⌘R` starten.
4. Links aus Instagram oder TikTok kopieren und in Album über **+** einfügen.

Die lokale App benötigt keine Zugangsdaten. Karte, Ortssuche und TikTok-oEmbed benötigen Internet. Instagram wird nicht ausgelesen.

## Supabase einrichten

Voraussetzungen sind ein kostenloses Supabase-Projekt und die installierte Supabase CLI.

1. Im Supabase Dashboard unter **Authentication → Providers → Anonymous Sign-Ins** anonyme Anmeldungen aktivieren.
2. Im Terminal in den Ordner `Album` wechseln und das Projekt verbinden:

   ```sh
   supabase login
   supabase link --project-ref DEINE_PROJECT_REF
   supabase db push
   supabase functions deploy create-trip
   supabase functions deploy join-trip
   supabase functions deploy place-photo
   ```

3. In `project.yml` die beiden Werte ersetzen:

   ```yaml
   SUPABASE_URL: "https://DEINE_PROJECT_REF.supabase.co"
   SUPABASE_ANON_KEY: "DEIN_PUBLISHABLE_KEY"
   ```

4. Das Xcode-Projekt neu erzeugen:

   ```sh
   xcodegen generate --spec project.yml
   ```

Der Publishable- beziehungsweise Anon-Key darf in einer Client-App enthalten sein. Zugriffsschutz leisten die Row-Level-Security-Regeln in `supabase/migrations`. Der Service-Role-Key wird ausschließlich von Supabase Edge Functions aus der Serverumgebung gelesen.

## Ortsbilder

Nach der Auswahl eines Kartenortes sucht Album zuerst bei Wikidata nach dem konkreten Ort und lädt das zugehörige Bild samt Urheber und Lizenz aus Wikimedia Commons. Name und Koordinaten werden geprüft, damit ähnlich benannte Orte nicht verwechselt werden. Linkvorschauen und eigene Fotos haben Vorrang. Eigene Fotos werden ohne EXIF-Daten, mit maximal 2.048 Pixeln Kantenlänge und höchstens 5 MB im privaten Bucket `trip-images` gespeichert.

Für Wikimedia kann optional ein eigener, gut erkennbarer User-Agent gesetzt werden:

```sh
supabase secrets set WIKIMEDIA_USER_AGENT="Album/1.0 (private Prague travel app)"
```

Tripadvisor Terra ist vorbereitet und standardmäßig ausgeschaltet. Erst nach Freischaltung eines passenden Terra-Zugangs aktivieren:

```sh
supabase secrets set TRIPADVISOR_TERRA_API_KEY="DEIN_TERRA_KEY"
supabase secrets set TRIPADVISOR_TERRA_ENABLED="true"
supabase functions deploy place-photo
```

Ohne Terra-Key arbeitet Album weiterhin vollständig mit Linkvorschau, Wikimedia, eigenen Fotos und dem gestalteten Platzhalter.

## Gemeinsames Album verwenden

1. Auf dem ersten iPhone das Personen-Symbol und **Gemeinsames Album starten** wählen.
2. Den angezeigten privaten Link mit der Partnerin teilen.
3. Sie öffnet `album://join/...` auf einem iPhone, auf dem Album installiert ist.
4. Änderungen werden nach dem Speichern, beim Aktivieren der App, über Realtime und über **Jetzt abgleichen** synchronisiert.

Der Link ist der Zugangsschlüssel und läuft nach 30 Tagen ab. Ein beigetretenes Gerät bleibt danach Mitglied. PDFs liegen in einem privaten Storage-Bucket und sind auf 25 MB begrenzt. Bei gleichzeitigen Änderungen am selben Datensatz gewinnt der neuere `updatedAt`-Zeitstempel.

## Auf einem iPhone installieren

Ein kostenloses Personal Team reicht aus, weil die App keine iCloud-, App-Group- oder Share-Extension-Entitlements verwendet. In Xcode unter **Targets → Album → Signing & Capabilities** das eigene Team wählen, eine eindeutige Bundle-ID setzen und das verbundene iPhone als Ziel starten. Für das zweite iPhone denselben Vorgang wiederholen. Die Installation über ein Personal Team muss regelmäßig erneuert werden; TestFlight benötigt weiterhin das Apple Developer Program.

## Prüfungen

Hinweis zum Abgleich: Builds mit `CODE_SIGNING_ALLOWED=NO` dürfen den Schlüsselbund nicht benutzen. Die anonyme Supabase-Sitzung geht dann bei jedem Start verloren; Schreibzugriffe scheitern mit „new row violates row-level security policy“. Den Abgleich deshalb nur mit signierten Builds prüfen (Xcode ⌘R oder `xcodebuild` ohne diese Option). Als Unit-Test-Host gleicht die App nie ab.

```sh
xcodebuild -project Album.xcodeproj -scheme Album -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test
deno test supabase/functions/_shared/album_test.ts supabase/functions/_shared/place_photo_test.ts
```

Vor der Reise auf zwei echten Geräten prüfen: Einladungslink öffnen, Ideen in beide Richtungen bearbeiten, offline ändern und später abgleichen sowie ein echtes PDF hochladen und auf dem zweiten Gerät öffnen.

## Technik

- SwiftUI, MapKit und PDFKit.
- Supabase Auth, Postgres, Realtime, Storage und Edge Functions.
- `AlbumStore` besitzt die lokale atomare Speicherung und Änderungswarteschlange.
- `SupabaseSync` übernimmt Authentifizierung, Upload, Download, Zusammenführung und Realtime.
- Original-Figma: https://www.figma.com/design/BvFJ4PzwQXAxhPlrEw73rB/Trip-Planner?node-id=6-7

Font-Lizenzen liegen unter `Album/Resources/*-OFL.txt`.
