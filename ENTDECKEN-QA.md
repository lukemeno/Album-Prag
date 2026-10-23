# Entdecken V1: lokaler Stand und Freigabe

Stand 23.10.2026. Code lokal auf main. Keine Produktionsmigration, kein Deployment, kein Push.

## Implementiert
Unter Ideen öffnet Entdecken persönliche Interessen pro Reise, eine ausdrücklich bestätigte Wikidata-Stadt und passende Vorschläge im 25-km-Radius um deren Zentrum. Übernommene Orte sind gemeinsame Ideen, ohne Stimme oder Tagesplanung. QID/Ortsidentität verhindern Dubletten; entfernte Orte benötigen eine explizite Wiederherstellung. Interessen und Stadtauswahl bleiben als persönliches Sidecar auf diesem Gerät.

Die separate Function discover-places verlangt eine authentifizierte Sitzung; DISCOVERY_ENABLED muss ausdrücklich true sein, sonst bleibt sie deaktiviert. Anfragen enthalten Stadt-QID und Sprache, keine Reise-ID, Person oder Interessen. Die Migration 202610230001_discovery_catalog_cache.sql ergänzt einen privaten Katalogcache und private nutzerbezogene Rate-Limits. Tabellen und RPCs sind ausschließlich für service_role zugänglich; keine Änderung am Reise-Sync.

## Prüfung
226 Unit-Tests: 0 Fehler, 4 bestehende Live-Gates übersprungen. 12 aktuelle UI-Szenarien bestanden über Integrationslauf und gezielte Nachprüfung; der vorhandene Bild-Retry-Test scrollt vor dem Tap jetzt zum Element über der schwebenden Tab-Leiste. Der neue Ablauf prüft Interessen, bestätigte Stadt, Übernahme, Dublettenerkennung und Neustart mit isolierten Fixtures. 63 Backend-Shared-Tests grün; deno check der neuen Function grün.

Die SQL-Migration wurde ausschließlich in einer temporären lokalen PostgreSQL-17-Instanz geprüft: FORCE RLS und Client-Sperren, Lease-Besitz, frisch/alt/abgelaufen, einstündige Pause nach kaltem Quellfehler und atomare 3/10-Anfragen-pro-Minute-Limits.

Echte lokale HTTP-Prüfung gegen Wikidata und dieselben SQL-RPCs: Stadtsuche Prag liefert Q1085/Tschechien in3,45s. Ein Katalogabruf brach nach14,6s am begrenzten Quellbudget ab. Folgeabruf ergibt503 mit Retry-After von circa1h in0,16s; kein leerer Erfolgskatalog gespeichert. Das belegt Fehlerbehandlung, keine erfolgreiche Katalogqualität.

## Offene Abnahme vor Produktivfreigabe
- Erfolgreiche echte Kataloge für Prag, Tokyo, Paris und São Paulo: bekannte Referenzorte, alle sechs Themen, ausgeschlossene Typen, tatsächliche Bildidentität/Lizenzen und Gesamtlaufzeit. Während dieser Runde war WDQS stark begrenzt bzw. nicht rechtzeitig erreichbar. Keine erfolgreichen Vier-Städte-Smokes behaupten.
- Der einmalige Geo-Pool enthält maximal500 nach Sitelinks vorgewählte Objekte. Erst darin greifen vollständige Typ-/Ausschlussprüfung und die abschließende echte Wikipedia-Sprachartikel-Rangfolge. Diese Performance-Vorauswahl weicht vom ursprünglichen unbeschränkten Typ-vor-Bekanntheit-Anspruch ab und kann Themen in dicht erschlossenen Städten benachteiligen. Am realen Qualitätsgate messen, vor Freigabe bei Bedarf neu aufteilen.
- Das Quellenlimit2 gilt pro Edge-Isolate. Für eine harte Grenze über alle Instanzen ist eine verteilte Quellen-Lease erforderlich. Nicht ohne diese Prüfung als globales Limit ausweisen.
- Manuelles Durchklicken durch Root war durch den gesperrten Mac blockiert. Simulator-UI-Tests und ihre Screenshots sind geprüft; kein persönlicher Live-Simulator-Test behauptet.
- Migration/Function-Konfiguration erst nach separatem Release-Go aktivieren. Alte Bildfunctions nicht beiläufig neu deployen; deployed assistant_validation-Drift bleibt zu beachten.

## Isolierte lokale QA
ALBUM_TEST_STORE isoliert die Reise vom produktiven Sync. ALBUM_DISCOVERY_QA=1 aktiviert ausschließlich einen kleinen lokalen Fixture-Katalog ohne echte Bilder. ALBUM_EMPTY_TEST_STORE=1 erzeugt dafür ein frisches Testalbum.

Für echte lokale Abfragen zusätzlich ALBUM_DISCOVERY_LIVE_QA=1 und ALBUM_DISCOVERY_LOCAL_URL=http://127.0.0.1:PORT angeben; nur Loopback mit explizitem Port wird angenommen. Der Endpoint lautet /functions/v1/discover-places. Ohne explizites Live-Opt-in greifen isolierte Tests nicht auf Supabase zurück. QA-Flags existieren nur im DEBUG-Zweig.

Normale Backend-Regression: deno test --allow-env=WIKIMEDIA_USER_AGENT supabase/functions/_shared
