# Version 1: Sehenswürdigkeiten nach Interessen unter Entdecken

Stand: 23.10.2026. Status: ausgeplanter Vorschlag, noch keine Implementierung. Nutzerentscheidungen und Sol-Review sind berücksichtigt. Keine neuen kostenpflichtigen Anbieter, keine Social-Media-Trends.

## 1. Ziel und Nutzerablauf

- Unter dem bestehenden Tab „Ideen“ erscheint ein sichtbarer Einstieg „Entdecken“. Kein neuer Haupttab, keine Umbenennung oder Verdrängung der gemeinsamen Ideen.
- Beim ersten Öffnen persönliche Interessen für diese Reise wählen: **Kultur & Museen, Geschichte, Architektur, Natur & Parks, Aussicht, Kunst**. Mehrfachauswahl und „Alle Themen“; später jederzeit änderbar. Keine automatische Ableitung und kein Freitext in V1.
- Reiseziel als Vorschlag für eine Stadtsuche verwenden. Eine eindeutig zugeordnete Stadt bestätigen; bei Ländern, Regionen, mehreren Städten oder gleichnamigen Orten aktiv eine Stadt wählen. Auswahl später änderbar. Die Auswahl ändert weder Reiseziel noch Reisedaten.
- V1 zeigt bekannte besuchbare Highlights im ausdrücklich benannten Umkreis von **25 km um den bestätigten Stadtmittelpunkt**. Kein Anspruch auf vollständige administrative Stadtfläche, keine gesonderte Tagesausflugsfunktion, keine Standortberechtigung erforderlich.
- Nach Interessenwahl und Stadtbestätigung Katalog laden. Zunächst zwölf passende Orte anzeigen, mit „Weitere anzeigen“ bis maximal sechzig aus dem Katalog. Bereits gespeicherte Ergebnisse sofort anzeigen; Fotos nachladen.
- Karte eines Vorschlags: Name, kurzes Wikidata-Beschreibungsfeld (falls vorhanden), passende Themen, Foto oder neutraler Platzhalter, Quellenlink und „Als Idee übernehmen“. Detailansicht mit Lage, Quelle sowie Bildurheber/Lizenz. Keine erfundenen Beschreibungen, Bewertungen, Preise oder Öffnungszeiten.
- „Als Idee übernehmen“ fügt den Ort mit einem bewussten Tippen zu gemeinsamen Ideen hinzu. Es stimmt dem Ort nicht zu und plant keinen Tag. Vorhandene Orte zeigen „Bereits in euren Ideen“ bzw. „Bereits geplant“. Entfernte Orte werden nicht still wiederhergestellt.

## 2. Datenbasis und Auswahl

**Quelle:** Wikidata für stabile QID, Koordinaten, Typen, Namen, Kurzbeschreibung, Wikipedia-Verweise und gegebenenfalls P18-Bild. Vorhandene Orts-/Bildtechnik wiederverwenden. Kein Sprachmodell und keine Websuche pro Vorschlag.

**Filter vor Bekanntheit:** Eine feste, versionierte und durch Quellen-Fixtures geprüfte Zuordnung besuchbarer POI-Typen zu den sechs Interessen. Mehrere Themen pro Ort sind möglich. Museen, historische Bauwerke, Brücken, Denkmäler, Parks, Aussichtspunkte und ortsfeste Kunst können passen. Länder, Städte selbst, historische Staaten/Ereignisse, Verkehrsnetze, Flughäfen und reine Organisationen werden ausgeschlossen. Ein tatsächlich besuchbares Denkmal darf auch zu einem ausgeschlossenen Ereignis gehören; entscheidend ist das konkrete POI-Objekt.

**Bekanntheit:** Anzahl tatsächlicher Wikipedia-Sprachartikel einer Entity; Wikipedia-Domains aus den Sitelinks zählen, nicht alle Wikimedia-Projekte und nicht ungeprüft `wikibase:sitelinks`. Diese Zahl ist ein Näherungswert, keine Besucherzahl oder offizielle Bestenliste. Technische Vorsortierung per Gesamtsitelinks ist zulässig, die angezeigte und endgültige Wertung muss echte Wikipedia-Artikel zählen. Keine frei erfundene Mindestbekanntheit oder Sternebewertung.

**Katalog und Rangfolge:** Bis zehn bekannte Orte je Thema, danach nach QID zusammenführen, maximal sechzig. Client filtert auf mindestens ein gewähltes Thema und sortiert nach Wikipedia-Sprachartikelzahl absteigend; bei Gleichstand Entfernung zum Stadtmittelpunkt, danach QID. Passende Themen stehen als Begründung am Vorschlag. Ein Infohinweis erklärt die Auswahl; der Bereich behauptet keine objektive Top-10-Liste.

**Bilder:** P18 der exakten QID bevorzugen; Commons-Dateiinformationen gebündelt über die vorhandene Wikimedia-Metadatenlogik laden. Nur passende Bilder mit Quelle/Urheber und überprüfter Lizenz anzeigen. Fehlt ein belegtes Foto, bleibt die Karte nutzbar. Nicht für jeden Katalogort die komplette namenbasierte Wikimedia-Suchpipeline erneut starten. Nach Übernahme kann die vorhandene automatische Bildsuche ergänzen; Nutzerbilder und ausdrücklich gewählte Bilder bleiben geschützt.

**Prüfbeleg:** Eine öffentliche WDQS-Probe für Prag, zwölf Kilometer, lieferte am 23.10.2026 in ca. 1,2 s unter anderem Prager Burg, Karlsbrücke und Veitsdom. Ungefiltert erschienen zugleich Prag, Tschechoslowakei, Metro, Flughafen und eine Schlacht. Das belegt den Datenzugang und die Notwendigkeit der Typfilter, aber noch keine geprüfte globale Vorschlagsqualität.

## 3. Architektur und Grenzen

### Native App und persönliche Speicherung

- Stabile Typen: `DiscoveryInterest` mit Codes `culture_museums`, `history`, `architecture`, `nature_parks`, `viewpoints`, `art`; `DiscoveryCity`, `DiscoveryItem`, `DiscoveryCatalog` und ein persönlicher `DiscoverySession`-Zustand.
- Die Stadt trägt QID, Name, Land und Wikidata-Mittelpunkt. Ein Item trägt QID, Name, optionale Kurzbeschreibung, Koordinate, Themen, tatsächliche Wikipedia-Artikelzahl, kanonischen Quellenlink und optionales verifiziertes Bild. Der Katalog enthält Schema-/Rankingversion, Stadt, Sprache, Abdeckung und Abruf-/Ablaufzeit.
- Persönlicher Sidecar im Store-Verzeichnis nach bestehendem AssistantSession-Muster: `discovery-<safeAlbumID>-<safeParticipantID>.json`. Interessen, Stadtauswahl und lokale Katalogkopie gehören weder in `AlbumData` noch in den geteilten Trip-Payload.
- Persistenter Scope: gemeinsame Reise-ID, wenn vorhanden, sonst Album-ID; niemals Reisename oder veränderlicher Anzeigename. Beim Teilen der bestehenden Reise lokale Einstellungen in den neuen gemeinsamen Reisescope übernehmen; beim Beitritt zu einer anderen Reise nicht ungefragt alte Präferenzen kopieren. In V1 bleiben persönliche Einstellungen auf diesem Gerät, ohne geräteübergreifenden Abgleich.
- Bei geänderter Reisezielzeichenfolge Stadtbestätigung und Katalog verwerfen, Interessen erhalten. Bei Stadt-/Sprachwechsel ausstehende Antworten verwerfen. Umbenennung allein verändert die Interessen nicht.
- Eine `DiscoveryServiceProtocol`-Schnittstelle bietet Stadtsuche und Katalogabruf nach Stadt-QID und Sprache. ALBUM_TEST_STORE bleibt standardmäßig netzfrei; echte Abfragen nur mit ausdrücklichem Debug-Live-Opt-in.

### Backend und Cache

- Eigene authentifizierte Function `discover-places`, getrennt von Assistent und Reise-Sync. Aktionen `search_cities` (Suchtext, Sprache) und `catalog` (Stadt-QID, Sprache). Keine Teilnehmer-, Reise-, Hotel-, Planungsdaten oder Interessenauswahl für den Katalog übertragen; Personalisierung erfolgt lokal.
- Stadtsuche nutzt die Wikidata-Textsuche plus Entity-Prüfung auf Stadt-/Siedlungstyp und belastbare Koordinate. Maximal fünf Kandidaten; kein ungeprüftes erstes Suchergebnis. Katalog akzeptiert nur eine geprüfte Stadt-QID, keine frei eingesandte SPARQL-Abfrage, Koordinate oder externe URL.
- Feste versionierte, geografisch begrenzte WDQS-Abfragen und Entity-Nachladen; höchstens zwei parallele Upstream-Anfragen, zwanzig Sekunden Gesamtdeadline, feste Ergebnislimits. Kein Fuzzy-Textfilter über den ganzen Wikidata-Graph. User-Agent, Retry-After und begrenzte Wiederholung beachten.
- Gemeinsamer persistenter Cache mit Schlüssel `catalogVersion|cityQID|language`, sieben Tage gültig. Service-Role-Zugriff ausschließlich im Backend; kein direkter Client-Schreib-/Lesezugriff auf die Cachetabelle. Der vorhandene pro-Edge-Isolat-Memorycache genügt hierfür nicht.
- Bei Quellenfehlern bis zu dreißig Tage alte Kataloge mit deutlichem Stand-/Offlinehinweis nutzbar halten; danach keinen aktuellen Katalog vortäuschen. Manuelles Neuladen frühestens nach einer Stunde Upstream-Arbeit auslösen, identische laufende Anfragen zusammenführen. Pro angemeldeter Sitzung maximal zehn Stadtsuchen pro Minute und drei Kataloganforderungen pro Minute; zusätzlich harte Upstream-Begrenzung und Not-Aus.
- Client zeigt unterschiedliche Zustände für erste Ladung, leeres Themenresultat, nicht zugeordnetes Ziel, fehlendes Netz, Quellenbegrenzung und veralteten Cache. Interessenwechsel filtert vorhandenen Katalog sofort und erzeugt keinen neuen Upstream-Abruf. Kein heimlicher Wechsel zu allgemeinen „Top“-Ergebnissen bei Quellenfehlern.

### Übernahme und Kompatibilität

- `AlbumStore.upsert` und bestehende Bild-/Syncpfade verwenden. Stabile Place-ID `discovery-<lowercase QID>` und Quellen-URL `https://www.wikidata.org/wiki/Q…`. Die vorhandene Datenbank erlaubt Text-IDs und trennt sie nach Reise.
- Vor Übernahme über alle vorhandenen Orte prüfen: zuerst stabile ID/kanonische QID-URL, dann identischer normalisierter Name bei höchstens 100 m Abstand. Bloße Nähe ist kein Duplikatbeweis. Bestehende Daten, Bilder und Stimmen nicht überschreiben.
- Neuer Ort: Autor aktuelle Person, Kategorie `Aussicht` für Aussichtspunkte, sonst `Sehenswert`, Koordinate direkt aus bestätigtem Wikidata-POI; keine erneute MapKit-Zuordnung. `franked=false`, keine Stimmen, kein Datum/Tag/Reihenfolge, nicht zurückgestellt und nicht gelöscht. Bei fehlgeschlagener Speicherung keinen Erfolg anzeigen.
- Gelöschte Treffer kennzeichnen und ausschließlich über ausdrückliche Wiederherstellung erneut zeigen; diese bewahrt vorhandene Metadaten. Gleiche QID erhält auch bei paralleler Übernahme durch zwei Personen dieselbe ID.
- Keine Änderung der Place-/Trip-Syncschemas nötig. Die neue Cachetabelle ist die einzige geplante DB-Erweiterung. Vorhandene Ideen-IDs, Startargumente, Haltemenü, Abstimmung und Tagesplanung bleiben kompatibel.

## 4. Issue-Entwürfe und Abnahme

**E1 · Domain, persönliche Sitzung und Übernahme.** Typen, Sidecar/Scopewechsel, Zielinvalidierung, Duplikatprüfung und Upsert. Abnahme: Interessen bleiben nach Neustart und getrennt pro Person/Reise erhalten; Sharing-/Join-Übergänge stimmen; Übernahme ohne Stimmen/Plan; entfernte oder manuell bearbeitete Orte werden nicht überschrieben. Keine Abhängigkeit von Backend für deterministische Tests.

**E2 · Stadt-/Highlight-Daten, Bilder und Cache.** Function, versionierte Klassifizierung/Ranking, gebündelte Commons-Zuordnung, Migration/RLS, Grenzen und Not-Aus. Abnahme: Typfilter und echte Wikipedia-Domainzählung bestehen Fixtures; Cache frisch/alt/abgelaufen, fehlende Lizenz, 429/503 und Auth-/RLS-Sperren sind geprüft. Die End-to-End-Qualität für Prag/Tokyo/Paris ist vor Frontend-Freigabe nachzuweisen. Keine Abhängigkeit von E1 für öffentliche Datenfixtures.

**E3 · Entdecken unter Ideen.** Erstinteressen, Stadtbestätigung, zwölf Karten mit Nachladen, Quellen/Erklärung, Auswahländerung und Einzelübernahme. Abnahme: VoiceOver/Dynamic Type, Laden/Fehler/Offline und unveränderte bestehende Ideenflüsse. Abhängig von den Verträgen aus E1/E2; zunächst mit Fixtures umsetzbar.

**E4 · Eigene Abnahme und Veröffentlichung.** Vollständige passende Unit-/UI-Prüfung, echte Opt-in-Quellenabfragen und eigene Simulatorbedienung. Abhängig von E1–E3. Backend/Migration zuerst, dann Client; Authkonfiguration und unabhängige Live-Drift erhalten. Veröffentlichung und GitHub-Push erst auf separates Nutzer-Go.

**Pflichtfälle:** Prag-Burg/Brücke/Dom erlaubt und Länder/Metro/Airport/Ereignisse ausgeschlossen; Mehrfachthemen und Bildausfall; gleiche QID/gleicher Name neben anderem POI; gelöschter Ort; parallele Übernahme; Zielwechsel bei laufender Anfrage; private Interessen beim Join/Teilen/Neustart; keine Stimmen oder Planung durch Übernahme; Offline/Quellenlimits/alte Daten; mehrdeutiges Stadtziel und Land statt Stadt. Echte Abnahme mindestens Prag, Tokyo und Paris plus São Paulo für Sprache/Diakritika. Keine flüchtigen exakten Ranglisten als Testoracle: erlaubter Typ, valide Koordinate, richtige Stadtregion, Quellen-/Bildidentität und Limits prüfen. Zusätzlich pro Stadt vorab fünf bekannte konkrete Referenz-POIs auf passende Themen prüfen, damit Qualität nicht nur formal korrekt ist; kein Fixture-Fallback in Live-Ergebnissen.

## Quellen und Status

- [Wikidata-Datenzugang und Zugriffsregeln](https://www.wikidata.org/wiki/Help:Data_access)
- [Wikidata-Lizenzierung](https://www.wikidata.org/wiki/Wikidata:Licensing)
- [Apple POI-Suche](https://developer.apple.com/documentation/mapkit/mklocalpointsofinterestrequest)

Keine neuen Datenanbietergebühren eingeplant; bestehendes Backend, Speicher, Bilderabrufe und Entwicklung verursachen weiterhin Aufwand/Kosten. Öffentliche Wikimedia-Dienste haben keinen zugesagten Verfügbarkeitsvertrag für Album; begrenzte Abfragen, gemeinsamer Cache und ehrliche Fehlerzustände sind deshalb Teil von V1.

Diese vier Issues sind lokale Entwürfe. Linear-Projektsuche nach „Album“ lieferte kein Projekt; es wurden keine externen Issues angelegt. Ein Zielprojekt ist vor einer späteren Übertragung zu klären. Dieser Plan startet weder Implementierung noch Deployment.
