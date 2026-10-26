# Automatische Ortsfotos: Abnahme 26.10.2026

## Ergebnis

Sol prüfte Architektur und Diffs, Luna implementierte Client und Backend, Root integrierte und führte die unten genannten Tests aus. Automatik ist unabhängig von Prag: neue/identitätsveränderte Ideen werden nach erfolgreicher Speicherung in einer persistenten lokalen Warteschlange verarbeitet. Eigene/manuell gewählte Bilder, bewusste Bildentfernung und gültige vorhandene Fotos bleiben geschützt. Neustart und Foreground setzen ausstehende Arbeit fort; iOS garantiert keine Ausführung bei geschlossener App.

MapKit bestätigt zunächst den Ort im Kontext seiner Reise. Unklare Namen brauchen eine Ortsbestätigung. Danach kostenlose Wikimedia-Suche, bei Bedarf ortsgebundene Website-Vorschau auf dem Gerät, sonst neutraler Platzhalter. Keine automatische Galerie, kein kostenpflichtiger LLM-/Vision-Aufruf. Automatische Requests können Google/Tripadvisor nicht erreichen. Auch der optionale manuelle Terra-Pfad benötigt jetzt zusätzlich PAID_PHOTO_PROVIDERS_APPROVED; dieses neue Secret wurde nicht aktiviert.

## Nachweise

| Prüfung | Tatsächliches Ergebnis | Beleg |
|---|---|---|
| Finale Swift-Unit-Suite | 258 insgesamt, 253 bestanden, 5 bewusst übersprungen | /tmp/album-auto-acceptance-20261026.xcresult |
| Reale UI: neue Idee → Einwurf → Ort bestätigen → echtes Foto → Neustart | bestanden, Knedlín/Národní; kein Bilder-Refresh betätigt | derselbe Bundle, NativePrototypeUITests.testNewIdeaLoadsPhotoAutomaticallyAndKeepsItAfterRelaunch |
| Reale MapKit-/Website-Queue-Probe | gespeichert, tatsächlicher JPEG-Abruf decodierbar | PhotoResolutionCoordinatorTests.testLiveAutomaticSaveProofIsExplicitlyOptIn |
| Finale Deno-Suite inklusive Endpoint-Fresh-/Miss-Tests | 86 bestanden, 0 Fehler | /tmp/album-auto-backend-release-final-20261026.log |
| Originalschema + neue Migration + SQL-RPC-Regression | bestanden in wegwerfbarer lokaler PostgreSQL-DB | QA/photo-pipeline-sql-qa.py |
| 50 parallele Cache-Claims | 1 Besitzer, 49 wartend | /tmp/album-auto-sql-verified-20261026.log |
| 50 parallele Run-Reservierungen desselben Nutzers | 30 erlaubt, 20 begrenzt | derselbe Beleg |
| Globaler Wikimedia-Semaphore | A hält, B abgewiesen, nach Release B erfolgreich | derselbe Beleg |
| Nichtberechtigter DB-/RPC-Zugriff | authenticated abgewiesen | derselbe Beleg |
| Authentifizierter Live-MISS und HIT | Tokyo Tower/Q183536, jeweils HTTP200; Foto-HTTP200 mit App-User-Agent, Urheber/Lizenz vorhanden | geschützte Receipt /tmp/album-auto-backend-smoke-receipt-20261026.json |
| Gemessener Live-Verbrauch dieser MISS/HIT-Probe | 1 Suchlauf, 4 echte Upstream-HTTP-Aufrufe; 3 Endpoint-Aufrufe einschließlich ungültiger Anfrage | Datenbankzählung ausschließlich des markierten QA-Nutzers |
| Ungültige Null-Koordinate | HTTP400 | dieselbe Receipt |
| Vier-Städte-Quellenrunde | Tokio/Q183536, Paris/Q243, São Paulo/Q82941, Prag/Q193369: verifizierte Fotos; Paris/Prag nach Hotfix erneut erfolgreich | /tmp/album-auto-multicity-final-receipt-20261026.json und ursprüngliche São-Paulo-/Tokio-Receipts |

Screenshots der echten Website-Fotos nach Speichern und Neustart wurden visuell geprüft: .qa-shots/automatic-photos-live-20261026/ (ignored). Das Foto zeigt die Knödel von knedlin.cz, kein Kartenbild und keine Fixture. Der frühere deterministische UI-Test mit SF-Symbol und „Automatisches Testfoto“ ist ein separater Ablaufnachweis, kein Realfoto-Beleg.

Die echten UI-Tests umgehen bewusst die authentifizierte Wikimedia-Funktion und testen MapKit + Website-Fallback. Der separate authentifizierte Backend-Smoke belegt die Wikimedia-/Cache-Stufe. Kein kombinierter Zwei-Geräte-Live-Sync-Test wird daraus abgeleitet.

## Veröffentlichung und Betrieb

- Migration produktiv auf akzrlkbylglwrlbaacjo: **20261026223140 / place_photo_pipeline**, lokale Quelle supabase/migrations/202610260001_place_photo_pipeline.sql.
- Finale Funktionen: **place-photo v13**, **place-enrichment v6**, **place-enrichment-worker v6**. JWT-Einstellungen erhalten (photo true, übrige false mit bestehender interner Auth-Prüfung).
- Vorherige Funktionsquellen gesichert unter /tmp/album-auto-live-backup-20261026; genaue Veröffentlichungspakete unter /tmp/album-auto-deploy-20261026. Die bereits vorhandene Live-Version von assistant_validation.ts wurde beibehalten. Keine unzugehörigen Assistentenänderungen veröffentlicht.
- Quoten: Endpoint120/Minute/Nutzer; neue Suchläufe30/Stunde und100/Tag/Nutzer,150/Tag/gemeinsamer Reise; maximal12 HTTP-Aufrufe je Lauf und global10/Minute/1000/Tag. Wikimedia maximal ein aktiver HTTP-Aufruf projektweit. Google-Reservierungen zählen, halten aber keinen Wikimedia-Semaphore. Cache-Hits verbrauchen keine Suchlauf-Quoten, bleiben endpointbegrenzt.
- Private Cache-Leases sind bei geteilten Reisen reiseweit, bei lokalen Reisen nutzergebunden. Globale Metadaten-Caches erst nach bestätigter öffentlicher QID; keine privaten Links/Notizen/Uploads. Automatik-/Galerie-Caches getrennt, Revisionen SHA-256/64 Zeichen. Eine unbekannte QID muss zunächst weiter aufgelöst werden: globale Medienwiederverwendung bedeutet nicht null Wikidata-Aufrufe bei jedem neuen Ort.
- Positive Metadaten30 Tage, negative7 Tage; transiente Fehler nicht negativ cachen. Globale öffentliche Caches auf100k Einträge begrenzt; veraltete Jobs/Leases und Nutzungsdaten werden bereinigt. Cron-Prune setzt seinen Service-Role-Claim explizit.
- Lokal maximal100MB URLCache; eigene Originale separat. Website-Vorschauen bleiben private Vorschauen und werden nicht als frei lizenzierte Wikimedia-Fotos ausgegeben.
- Aktuelles Bundle zusätzlich auf bestehendem iPhone18Pro-Simulator installiert, ohne Deinstallation/Containerlöschung. Die native Abnahme lief auf iPhone17/iOS27. Keine echten Reisedatensätze im Backend verändert.

## Gefundene und behobene Fehler

- Fehlende Swift-Dateiregistrierung, Decoder-/Initializer- und Test-Compile-Probleme vor der ersten grünen Suite behoben.
- Queue-/direkte Ortsbestätigung konnten zeitgleich laufen: gültiges bereits gespeichertes Foto beendet jetzt einen späteren Retry ohne neue Suche.
- MapKit lieferte für einen Lokalnamen einen Stadttreffer. POI-Suche verhindert die automatische Zuordnung dieses Stadtergebnisses; Mehrdeutigkeit bleibt sichtbar.
- Der erste produktive MISS scheiterte durch einen nicht mehr JSON-parsbaren mode-partitionierten RAM-Key. place-photo wurde sofort vorübergehend auf die gesicherte Vorgängerversion zurückgestellt (aktive Versionsnummer11), nach Handler-MISS-Regressionsprüfung als v12 korrigiert veröffentlicht. Keine Erfolgsaussage nur auf Basis von Cache-Hits.
- Vier-Städte-Probe fand transiente P18-Fehler als falschen Negativtreffer sowie explizites Public-Domain-Material ohne LicenseUrl. v13 reicht Quellfehler weiter und nutzt bei ausdrücklich belegter Public-Domain-Lizenz die HTTPS-Commons-Seite als Rechte-Referenz. Unbekannte Lizenz ohne Link bleibt abgelehnt. Gezielt nur der vorhandene leere Auto-v2-Cache für Q243 entfernt; Q193369 war unter dem geprüften Schlüssel nicht vorhanden. Verifizierte Tokio-/São-Paulo-Caches erhalten.
- Auth-Testkonten und ihre privaten Cache-/Verbrauchszeilen nach Metadaten-/Mitgliedschaftsprüfung gezielt gelöscht. Abschließender Backendstand: 2 Reisen,5 Mitgliedschaften,5 Orte,0 Dokumente,0 Foto-QA-Nutzer,0 private Foto-QA-Cache-Zeilen. Öffentliche, echte Ortsmetadaten dürfen im Produktcache bleiben.

## Noch kein öffentlicher Release-Nachweis

Kein physischer Zwei-iPhone-Test, keine iOS18-Laufzeitabnahme, keine Garantie für jedes Lokal oder für dauerhafte Verfügbarkeit externer Bilder. Vier echte Quellenfälle sind kein repräsentativer Qualitäts-/Kostenpilot. Vor App-Store-Freigabe längerer Nutzungspilot, öffentliche Wikimedia-Kontaktangabe, kommerzielle Vorschau-/Bildrechte sowie stabile Nutzer-/Tarifidentität abnehmen. Anonyme Neuinstallationen können Nutzergrenzen umgehen; globale Quellenlimits bleiben die zusätzliche Schutzgrenze. Kein Gewinn- oder Null-Infrastrukturkostenversprechen.

## Reproduzieren

Backend: `deno test --allow-env supabase/functions/_shared supabase/functions/place-photo_test.ts`.

SQL: `python3 QA/photo-pipeline-sql-qa.py` gegen lokalen PostgreSQL auf127.0.0.1:65439; erzeugt und entfernt eine eigene DB, benötigt die vorhandenen Rollen anon/authenticated/service_role. Verbindet sich nie zu Supabase.

Live-Simulator nur ausdrücklich: TEST_RUNNER_ALBUM_LIVE_AUTO_PHOTO_QA=1 für reale Unit-Proben; zusätzlich TEST_RUNNER_ALBUM_LIVE_AUTO_PHOTO_UI_QA=1 für den echten Save-/Neustart-UI-Test. Ohne Opt-in laufen Tests mit isolierten Fixtures. Backend-Live-Proben erfordern markierte temporäre Nutzer und anschließende exakte Bereinigung; keine Zugangstoken in Berichte schreiben.
