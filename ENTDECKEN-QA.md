# Entdecken V1: lokaler Stand und Freigabe

Stand 23.10.2026. Code lokal auf main. Keine Produktionsmigration, kein Deployment, kein Push.

## Implementiert
Unter Ideen öffnet Entdecken persönliche Interessen pro Reise, eine ausdrücklich bestätigte Wikidata-Stadt und passende Vorschläge im 25-km-Radius um deren Zentrum. Übernommene Orte sind gemeinsame Ideen, ohne Stimme oder Tagesplanung. QID/Ortsidentität verhindern Dubletten; entfernte Orte benötigen eine explizite Wiederherstellung. Interessen und Stadtauswahl bleiben als persönliches Sidecar auf diesem Gerät.

Die separate Function discover-places verlangt eine authentifizierte Sitzung; DISCOVERY_ENABLED muss ausdrücklich true sein, sonst bleibt sie deaktiviert. Anfragen enthalten Stadt-QID und Sprache, keine Reise-ID, Person oder Interessen. Die Migration 202610230001_discovery_catalog_cache.sql ergänzt einen privaten Katalogcache und private nutzerbezogene Rate-Limits. Tabellen und RPCs sind ausschließlich für service_role zugänglich; keine Änderung am Reise-Sync.

## Prüfung
226 Unit-Tests: 0 Fehler, 4 bestehende Live-Gates übersprungen. 12 aktuelle UI-Szenarien bestanden über Integrationslauf und gezielte Nachprüfung; der vorhandene Bild-Retry-Test scrollt vor dem Tap jetzt zum Element über der schwebenden Tab-Leiste. Der neue Ablauf prüft Interessen, bestätigte Stadt, Übernahme, Dublettenerkennung und Neustart mit isolierten Fixtures. 73 Backend-Shared-Tests grün; deno check der neuen Function grün.

Die SQL-Migration wurde ausschließlich in einer temporären lokalen PostgreSQL-17-Instanz geprüft: FORCE RLS und Client-Sperren, Lease-Besitz, frisch/alt/abgelaufen, einstündige Pause nach kaltem Quellfehler und atomare 3/10-Anfragen-pro-Minute-Limits.

Echte HTTP-Prüfung mit öffentlichen Wikidata-/Commons-Daten und denselben SQL-RPCs erfolgreich: Prag 13 Orte/9 Bilder, Paris 25/17 (12,9 s), Tokio 26/18 (18,0 s), São Paulo 34/19 (12,1 s). Paris/Tokio/São-Paulo-Zahlen dokumentieren die erste erfolgreiche Datenrunde vor der abschließenden Kunst-/Abrissfilterkorrektur. Finaler frischer Prag-Abruf danach: 13 Orte/9 Bilder, darunter 1 Kunst-Treffer, in12,66s; Cache-Folgeabruf0,043s. Keine Fixtures oder stadtspezifischen Ersatzkataloge. Einzelne vorherige P31-Abrufe überschritten weiterhin das 8-s-Quellenbudget; bestehende Kataloge werden dann aus dem Cache bedient.

Behoben: Commons-P18-Abfragen verwenden File-Namensraum und Redirect-/Normalisierungszuordnung bei erhaltener Groß-/Kleinschreibung. Geo-Kandidaten kommen aus CirrusSearch; direkte P31-Typen und begrenzte einzelne P279-Elternschritte ersetzen die langsame transitive Geo-Abfrage. Öffentliche Typ-Eltern werden inkrementell zwischengespeichert. HTTP-200-API-Fehler werden nicht als leere Daten akzeptiert. Kunstmuseen und Pinakotheken gehören auch zu Kunst; konkret als aufgelöst/abgerissen erfasste Orte (P576) entfallen. Die SQL-TTL vergleicht feste 168/720 Stunden statt kalendarischer Tage und funktioniert damit über Sommerzeitwechsel hinweg. Regression für UTC, Berlin und New York mit Frühjahrs-/Herbstterminen bestanden. Swift-Build inklusive sichtbarem Bildladezustand grün.

## Offene Abnahme vor Produktivfreigabe
- Vier Städte liefern echte Kataloge; vollständige redaktionelle Qualität und Abdeckung aller sechs Interessen bleiben ein Release-Gate. Nicht jeder bekannte Ort wird gefunden, nicht jedes Bild hat ausreichende Lizenz-/Urheberangaben. Der abschließende manuelle Simulator-Test mit echten Bildern ist wegen erneut gesperrtem Mac offen; Entsperren wurde angefragt.
- Der einmalige Geo-Pool enthält maximal500 CirrusSearch-Geotreffer in dessen Relevanzreihenfolge. Erst darin greifen vollständige Typ-/Ausschlussprüfung und die abschließende echte Wikipedia-Sprachartikel-Rangfolge. Diese Performance-Vorauswahl weicht vom ursprünglichen unbeschränkten Typ-vor-Bekanntheit-Anspruch ab und kann Themen in dicht erschlossenen Städten benachteiligen. Am realen Qualitätsgate messen, vor Freigabe bei Bedarf neu aufteilen.
- Das Quellenlimit2 gilt pro Edge-Isolate. Für eine harte Grenze über alle Instanzen ist eine verteilte Quellen-Lease erforderlich. Nicht ohne diese Prüfung als globales Limit ausweisen.
- Manueller Root-Test nach Entsperren im iPhone-18-Pro-Simulator bestanden, mit isolierten Testdaten: Architektur auswählen, Prag bestätigen, Prager Burg übernehmen, Karlsbrücke als bestehende Idee erkennen, Veitsdom nur explizit wiederherstellbar, Ortsdetails mit Lage/Quellenerklärung, Ideenliste und unveränderten leeren Tagesplan prüfen, App neu starten und gespeicherte Interessen/Stadt/Idee ohne erneute Übernahmemöglichkeit prüfen. Leere Interessenauswahl und Themen ohne Treffer zeigen passende Hinweise. Keine echten Kataloge oder Bilder damit live abgenommen.
- Eine öffentliche Support-URL oder Kontaktadresse für den Wikimedia-User-Agent ist angefragt und noch offen; keine private Adresse ungefragt verwenden. Aktuelle QA nutzt einen ehrlichen lokalen Entwicklungs-User-Agent.
- Migration/Function-Konfiguration erst nach separatem Release-Go aktivieren. Alte Bildfunctions nicht beiläufig neu deployen; deployed assistant_validation-Drift bleibt zu beachten.

## Isolierte lokale QA
ALBUM_TEST_STORE isoliert die Reise vom produktiven Sync. ALBUM_DISCOVERY_QA=1 aktiviert ausschließlich einen kleinen lokalen Fixture-Katalog ohne echte Bilder. ALBUM_EMPTY_TEST_STORE=1 erzeugt dafür ein frisches Testalbum.

Für echte lokale Abfragen zusätzlich ALBUM_DISCOVERY_LIVE_QA=1 und ALBUM_DISCOVERY_LOCAL_URL=http://127.0.0.1:PORT angeben; nur Loopback mit explizitem Port wird angenommen. Der Endpoint lautet /functions/v1/discover-places. Ohne explizites Live-Opt-in greifen isolierte Tests nicht auf Supabase zurück. QA-Flags existieren nur im DEBUG-Zweig.

Normale Backend-Regression: deno test --allow-env=WIKIMEDIA_USER_AGENT supabase/functions/_shared
