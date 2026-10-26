# Automatische Ortsfotos für jede Reise

Stand 26.10.2026. Vom Nutzer beauftragt und anschließend umgesetzt. Backend veröffentlicht, Simulator-/Quellenabnahme durchgeführt; genaue Nachweise und verbleibende öffentliche Release-Gates in QA-AUTOMATISCHE-ORTSFOTOS.md. Dieser Plan hält den Zielentwurf fest und ersetzt die Vorschläge zu obligatorischer KI-Bildprüfung und zusätzlichen Fotoanbietern in PLAN-BILDAUSWAHL.md und Phase B3 von PLAN-FERTIG-V1.md. Andere Funktionen dieser Pläne bleiben separat.

## Ziel und Erlebnis

Jede neu eingeworfene Idee wird sofort gespeichert. Ein Hintergrundablauf bestimmt den Ort anhand ihrer eigenen Reise und ergänzt automatisch ein belastbares Foto. Das gilt für Cafés, Restaurants, Hotels und Sehenswürdigkeiten weltweit, ohne Prag-Vorgaben und ohne manuelle Pflege einzelner Orte. Automatischer Ablauf bedeutet keine garantierte Fotoabdeckung: fehlt eine geeignete Quelle, bleibt ein gestalteter Platzhalter.

Beim Laden dezente Rückmeldung im Bildbereich, keine blockierende Vollbildanzeige. Kein technischer Agent-Begriff im Produkt. Mehrdeutige Orte erhalten die bestehende Ortsbestätigung. Allgemeine Ideen wie „Pasta essen“ bekommen kein erfundenes Restaurantfoto. „Bild neu suchen“, „Eigenes Foto“ und „Bild entfernen“ bleiben erhalten. Entfernen setzt eine synchronisierte Automatik-Sperre, bis der Nutzer erneut suchen lässt.

## Geprüfter Ausgangspunkt

- AlbumStore.refreshPlaceImages bearbeitet höchstens fünf Orte pro Aufruf; die Versuchsmengen sind im Arbeitsspeicher. Das ist keine dauerhafte Warteschlange.
- PlaceEditor.save startet die nachgelagerte Suche ausdrücklich nur ohne Koordinaten; weitere Starts liegen im Lifecycle und in der Oberfläche. Alle Speicher-/Importwege müssen an denselben Koordinator angebunden werden.
- PlaceResolver in CollectionPlaceSuggestions.swift verwendet MapKit und den Kontext der Reise. Nicht durch eine zweite Ortsauflösung ersetzen.
- Wikimedia-Matching, Quellenangaben, typisiertes Bildmodell, Schutz eigener Bilder und ortsgebundene Website-Vorschau sind vorhanden.
- place-photo hat heute einen Cache je Serverprozess: maximal 128 Einträge, Treffer eine Stunde, leere Ergebnisse eine Minute. Gleichzeitige Aufrufe werden nur innerhalb dieses Prozesses zusammengeführt.
- Ein anderer vorhandener Backend-Pfad kann Google zur Ortsauflösung verwenden. Die neue Fotoautomatik darf ihn nicht unbemerkt aufrufen. Tripadvisor ist optional und bleibt ausgeschaltet.
- Bestehende persistente Enrichment-Jobs bringen bereits Leases und Wiederholungen mit; sie sind derzeit nutzer-/requestbezogen und ersetzen weder eine reiseübergreifende öffentliche Cache-Identität noch Wikimedia-Budgets. Backend-Struktur erweitern, keinen parallelen zweiten Worker bauen. Ein bestehender bedingter Scheduler darf weiterlaufen, aber keinen neuen kostenpflichtigen Dauerjob einführen; ein gestarteter Backendauftrag darf nach App-Schließen fertig werden, die lokale Website-Stufe wartet auf die aktive App.
- Aktueller main bei Prüfung: 1ee00bd. Zwei andere Planentwürfe sind bereits untracked; diese nicht überschreiben.

## Ablauf und Prioritäten

1. Nach erfolgreichem Speichern/Import einen Auftrag für Ort und aktuelle Identität vormerken. Auch bestätigter Ortswechsel und später ergänzter Reisekontext lösen aus; Notiz, Stimme oder Tagesplan allein nicht.
2. Eigene/manuell gewählte Fotos und bewusste Entfernung schützen. Bereits gültiges automatisch gewähltes Foto behalten; keine regelmäßige kosmetische Neusuche.
3. Bestehende, brauchbare Linkvorschau sofort nutzen. Karten, Logos und unspezifische Social-Vorschauen gelten nicht als belastbares Ortsfoto. Ein echtes Website-/Social-Vorschaubild bleibt als solches gekennzeichnet, nicht als verifiziertes Commons-Foto.
4. Ohne bestätigte Koordinaten: bestehende MapKit-Auflösung mit Reiseziel, Adresse und ggf. Koordinaten. Bei Mehrdeutigkeit warten, nicht im Hintergrund raten. Fehlendes Reiseziel ist ein eigener Wartezustand.
5. Erst lokale und geteilte vorhandene Ergebnisse, dann dauerhaften Wikimedia-Metadaten-Cache prüfen. Ohne brauchbaren Treffer begrenzte Wikimedia-Suche; vorhandene strenge Identitäts-/Entfernungsregeln erhalten.
6. Ohne verifiziertes Wikimedia-Foto: vorhandene Website-Vorschau über eindeutigen MapKit-Eintrag bzw. passenden gespeicherten Website-Link. Keine automatische kostenpflichtige Websuche zum Entdecken einer fehlenden Homepage. Bestehende Download-, Größen-, Identitäts- und Logo-Prüfungen weiterverwenden.
7. Ersten ausreichend guten Treffer übernehmen und abbrechen. Keine Galerie oder KI-Prüfung im Hintergrund nachladen. Weitere Kandidaten erst beim ausdrücklichen Öffnen der Bildauswahl.
8. Bildmetadaten wie bisher im Place-Payload synchronisieren. Der zweite Teilnehmer übernimmt dieses Ergebnis, statt regulär erneut zu suchen.

Die Stufen sind Wiederverwendung vorhandener Komponenten, kein neuer universeller Agent. Keine LLM-/Vision-Aufrufe, Google-Bilder, Stockfotos oder neuen bezahlten Anbieter in dieser Stufe. Look-Around und Kartensnapshots nicht als Ortsfoto verwenden.

## Aufträge, Identität und Lebenszyklus

- Neuer persistenter Sidecar je Reise, getrennt vom synchronisierten Place-Payload. Schlüssel: Reise-/Store-ID + Place-ID + Identitäts-Fingerprint + Pipeline-Version. Keine Benutzung des aktuell sichtbaren Reiseziels für Aufträge einer anderen Reise.
- Fingerprint aus kanonischer Provider-ID, soweit vorhanden, sonst normalisiertem Namen, Adresse, Kategorie und exakten bestätigten Koordinaten; zusätzlich relevanter Reise-Kontext. Bloße Nähe oder Namensgleichheit reicht nie zur Wiederverwendung. Public-Cache-Schlüssel und lokale Auftrags-ID sind verschiedene Dinge.
- Zustände: pending, running mit Lease-Ablauf, waitingForContext, needsReview, retryAt, completed, noMatch, suppressed. Anzahl Versuche, nächste Fälligkeit und Fehlertyp persistieren. Prozessabbruch macht Auftrag nach Lease-Ablauf wieder ausführbar.
- Eine aktive Suche pro geöffnetem Store. Nach jedem erledigten Auftrag nächsten fälligen nehmen; kein Fünfer-Limit, das den Rest dauerhaft liegen lässt. Sichtbare/neue Ideen priorisieren, alte dennoch fair bedienen.
- Aufträge nach Speichern, App-Start und Aktivierung fortsetzen. Beim Wechsel der Reise Arbeit abbrechen bzw. Ergebnis nur nach erneuter Prüfung auf den ursprünglichen Store anwenden. iOS garantiert keine Ausführung bei geschlossener App; V1 läuft, solange die App aktiv ist, und setzt später fort. Keine kostenpflichtigen Dauerjobs oder Polling-Worker.
- Vor jeder Übernahme Store, Place-ID, Fingerprint, Löschstatus, aktuelle Bildwahl und Automatik-Sperre prüfen. Kein spätes Überschreiben einer Nutzerwahl. Ein Resultat schreibt nicht rekursiv einen neuen Auftrag.
- Offline: lokal speichern und Auftrag behalten. Begrenzte Wiederholung nur bei vorübergehenden Fehlern; Retry-After respektieren. Startvorschlag: 1 Minute, 15 Minuten, 6 Stunden; maximal drei automatische Wiederholungen pro Identität, danach auf Nutzeraktion warten.
- noMatch: sieben Tage Ruhe; danach erst bei einer neuen Aktivierung/Interaktion fällig, kein Timer im Hintergrund. Unveränderte positive Bilder nicht allein wegen Cache-Ablauf ersetzen.
- Gemeinsame Reisen: Mitgliedschaftsgeprüfte, atomare Lease je tripID/placeID/Fingerprint für externe Suche; ein Gerät gewinnt, andere warten auf Sync. Ablaufende Lease schützt bei Abbruch. Lokale Reisen bleiben ohne gemeinsame Reise nutzbar. Getrennte Offline-Geräte können bis zum Abgleich doppelt arbeiten; keine Exactly-once-Garantie.

## Cache und Datenschutz

Zwei getrennte Bereiche:

- **Öffentliche Wikimedia-Metadaten:** dauerhafter Backend-Cache nur für bestätigte öffentliche Ortsidentitäten und öffentliche Bild-/Lizenzmetadaten. Keine Reisetitel, Teilnehmer, privaten Links, Notizen oder Fotos. Nicht durch frei formulierten Suchtext global teilen. Auch negative Treffer cachen; bei Orten ohne belastbare öffentliche ID bleibt der Cache lokal/reisegebunden.
- **Website-/Social-Vorschau und private Bilder:** lokal bzw. innerhalb der berechtigten Reise. Kein globaler Cache privater oder tokenhaltiger URLs; keine URL-Parameter in Telemetrie. Externe Bilder nicht pauschal in Supabase kopieren. Website-Vorschau ist keine freie Bildlizenz; kommerzielle Darstellungs-/Cache-Regeln sind vor öffentlichem Release zu prüfen.

Startwerte als Produktentscheidungen, keine Anbieterzusagen: öffentliche positive Metadaten 30 Tage frisch, bis Tag 90 bei Quellenausfall nutzbar, sofern nicht gesperrt/entfernt; negative Ergebnisse sieben Tage. Ablauf allein verursacht keinen Abruf. Quelldaten mit Ablauf/Entfernung respektieren. Lokaler Bildcache maximal 100 MB mit LRU; private eigene Originale sind hiervon ausgenommen. Anzeige lädt passende Thumbnails, keine Originalbilder auf Vorrat.

Dauerhafte Cache-Tabelle mit Ablaufbereinigung und maximaler Eintragszahl, atomarer Fetch-Lease sowie Pipeline-/Matching-Version. Datenbank-RPCs nur über geprüfte Funktion; kein frei beschreibbarer Nutzer-Cache und keine Rückgabe von Reise-Leases an Fremde. Vorhandenen RAM-Cache als kleine Zusatzstufe behalten.

Vorübergehende 429/5xx sind keine negativen Ortsfunde und erhalten eigenen Backoff. Vorschläge höchstens 24 Stunden frisch halten, nicht als verifizierte 30-Tage-Treffer cachen. Verarbeitete private Snapshots nach sieben Tagen, terminale Jobs nach 30 Tagen entfernen; rohe Nutzungsereignisse sieben Tage, Tagesaggregate 90 Tage. Auftragsstatus gebündelt lesen, kein Polling pro Kartenzeile. Bestehende Enrichment-Request-Snapshots und ihre privaten Links in diese Bereinigung einbeziehen.

## Kosten und Missbrauch

Keine neuen kostenpflichtigen Quellen aktivieren. Automatische Galerieabfragen und versteckte Google-Ortsauflösung unterbinden; serverseitige Schalter sind maßgeblich. Eigene Aufnahmen bleiben normal synchronisierbar.

Vorläufige konservative Startkonfiguration, später durch Pilotmessung anpassen:

| Grenze | Startwert | Verhalten |
|---|---:|---|
| neue Backend-Suchdurchläufe je Nutzer | 30/Stunde, 100/Tag | Auftrag wartet bis Reset |
| externe Durchläufe je gemeinsamer Reise | 150/Tag | Cache und bestehende Bilder funktionieren weiter |
| manuell erzwungene Neusuche | 3 je Ort/Tag | ebenso innerhalb aller anderen Grenzen |
| Wikimedia-Upstream HTTP-Aufrufe gesamt | 10/Minute, 1.000/Tag | globaler Stop für neue externe Suche |
| Upstream-Aufrufe je Durchlauf | maximal 12, inklusive Retries/Redirects | beste bisherige Ausbeute oder Platzhalter |
| gleichzeitige Wikimedia-Aufrufe | initial 1 projektweit | kurze atomare Leases; warten statt offenes Polling |

Das sind Arbeitsbudgets, keine fertige Tarifgestaltung. Cache-Hits verbrauchen kein externes Suchkontingent, haben aber weiterhin ein eigenes Endpoint-Ratelimit. Jeder tatsächlich versuchte externe Aufruf zählt auch bei Fehler/Abbruch. Atomare Reservierung vor dem Aufruf, begrenzte Requestgrößen, kurze Timeouts, globale Abschaltung und Tagesgrenzen müssen für alle Foto-Einstiegspunkte gelten, einschließlich place-enrichment. Rohes Backend-Cache-Leeren ist kein Weg, Limits zurückzusetzen. Lokale Website-Abrufe haben zusätzliche persistente Client-Limits; diese sind allein keine Missbrauchsschutzgrenze für Serverkosten.

Anonyme Neuinstallation kann Nutzerlimits umgehen. Globale Grenzen wirken trotzdem; für öffentliche Bezahlkontingente an verifizierte stabile Identität/Entitlement anbinden, kein clientseitiges Pro-Flag. Bestehende Auth-/Bezahlarbeiten nicht nebenbei umbauen.

Messen: Suchdurchläufe, öffentliche Cache-Hits, echte Upstream-Aufrufe je Quelle, Bild-/Metadatenbytes, Fehler, noMatch und Laufzeiten. Keine privaten Titel/URLs protokollieren. Auch direkte externe Bildabrufe auf dem Gerät erfassen, soweit datensparsam möglich. Nur aggregierte Kennzahlen, begrenzte Aufbewahrung.

Kostenmodell vor Preisfestlegung: fixe Infrastruktur + Funktions-/DB-Nutzung + Bild-/Storage-/Realtime-Traffic + bezahlte Anbieter (hier ausgeschaltet). Kosten pro aktivem Nutzer und pro Reise getrennt messen. Gewinnprognosen erst mit Pilotdaten, realem Abo-Nettoerlös und dem Verbrauch der übrigen Funktionen; kein Versprechen „kostenlos“ oder profitabel durch diesen Plan allein. Supabase-Spend-Cap schützt nur bestimmte Positionen und ersetzt keine Anwendungslimits.

## Umsetzungspakete / lokale Issue-Entwürfe

**AF-1 – Zentrale Auslöser und persistente lokale Warteschlange.** Dateien: AlbumStore.swift, neuer PhotoResolutionCoordinator/Sidecar, PlaceEditor.swift und Import-/Discovery-/Sync-Einstiege nach Aufrufinventur. Ziel: alle erfolgreich gespeicherten Ideen, keine Bild-Neusuche durch Stimmen/Notizen, Neustartfestigkeit, sichere Store-Wechsel, bewusste Entfernung. Abnahme: zwölf Ideen werden vollständig abgearbeitet; Offline/Neustart, Identitätswechsel und verspätete Antworten korrekt. Abhängigkeit: stabile Reise-Store-ID; mit Reisebibliothek abstimmen, ohne sie vorauszusetzen.

**AF-2 – Dauerhafter Cache, gemeinsame Leases und Serverlimits.** Dateien: place-photo/index.ts, _shared/place_photo_cache.ts, gemeinsame Foto-/Enrichment-Adapter, neue Migration und SQL-/Deno-Tests. Ziel: globale Wikimedia-Wiederverwendung, getrennte private Zustände, verteilte Begrenzung. Abnahme: zwei Instanzen verursachen bei gleichem öffentlichen Treffer nur eine laufende Suche; zwei Reisemitglieder teilen eine Lease; Cache-Hit ohne Upstream, Limits auch unter Parallelität wirksam, Fremde ohne Zugriff. Abhängigkeit: AF-1-Verträge/Fingerprint vor Implementierung einfrieren.

Dabei vorhandene Jobtabellen/Claims wiederverwenden und ihre bisherige Eindeutigkeit pro Nutzer um private Reise-/Place-Revision und öffentliche Cache-Lease ergänzen. Test mit 50 gleichzeitigen gleichen Jobs und einem 100-Orte-Import: ein aktiver öffentlicher Fetch je Schlüssel, keine verlorenen Folgeaufträge, begrenzte Statusabfragen und keine Quotenüberschreitung. „Ein Fetch“ kann mehrere gezählte Wikimedia-HTTP-Aufrufe benötigen.

**AF-3 – Auswahl und Darstellung auf geringe Kosten ausrichten.** Dateien: PlaceImageService.swift, AlbumPhoto und Bildauswahl/Statusanzeige. Ziel: frühes Stoppen, keine automatische Galerie, gleiche Qualitätsregeln für alle Städte, Attribution und Opt-out. Abnahme: eigene Fotos geschützt, Karte/Logo abgelehnt, bestehendes Foto bei Fehler behalten, exakte passende Website-Fotos möglich, keine LLM-/Google-/Tripadvisor-Anfrage. Abhängigkeit: AF-1; AF-2 für vollständigen Serverpfad.

**AF-4 – Abnahme, Verbrauchspilot und Release.** Tests/Messlauf mit dokumentierten realen Quellen, mindestens Prag, Paris, Tokio und São Paulo sowie gleichnamigen Kettenfilialen. Abdeckung: Sehenswürdigkeit, Café, Restaurant, Hotel, generische Idee, fehlendes Ziel, Linkimport, manuell gewählter Ort, Discovery-Übernahme, PDF-Hotel und gemeinsamer Sync. Metriken getrennt nach Quelle und Kategorie; kein Erfolg durch manuell ergänzte Website als automatische Entdeckung ausgeben. Vor öffentlicher Freigabe Kontakt-User-Agent, Bildquellen-/Lizenzregeln und tatsächliche Budgetkonfiguration prüfen. Migration/Deploy erfolgen erst im Umsetzungsauftrag, nicht durch diese Planung.

Reihenfolge: AF-1-Vertrag und AF-2-Datenmodell gemeinsam planen; AF-1/AF-2 danach getrennt implementierbar, AF-3 integrieren, AF-4 abschließen. Sol prüft Plan/Diff, Luna implementiert gemäß AGENTS. Linear-Zielprojekt ist nicht bestätigt; diese Texte sind lokale Issue-Entwürfe, keine angelegten Tickets.

## Übergreifende Abnahme

- Keine festen Prag-Koordinaten/-Namen im Produktionsablauf; gleiche Namen verschiedener Städte oder Filialen nicht zusammenwerfen.
- Eine neue Idee startet ohne „Bilder ergänzen“; mehr als fünf Ideen werden fair verarbeitet.
- Neuöffnen, Scrollen und Realtime für unveränderte fertige Orte erzeugen keine neue Quellensuche.
- Zwei Teilnehmer sehen denselben gewählten Treffer; Bildlöschung/Opt-out und eigene Fotos bleiben nach Sync erhalten.
- Unsicherer Ort wartet auf Bestätigung; Bild ohne Quelle/Lizenz wird nicht als Wikimedia verified gespeichert.
- Fehler, Offline, abgelaufene Lease und Bild-URL, 403/429/503 sowie Identitäts-/Reisewechsel ohne Verlust gespeicherter Ideen.
- Budgetende blockiert nur neue externe Bildsuche; Speichern, Karte, Planung, vorhandene Bilder und Uploads bleiben benutzbar.
- Nach einem begrenzten Pilotlauf: tatsächliche Kosten-/Requestzahlen und verbleibende Bildlücken dokumentieren, erst dann Tarif-/Grenzenentscheidung.

## Quellen, geprüft am 26.10.2026

- MediaWiki API-Etikette: Kontakt-User-Agent, Cache und schonende serielle Anfragen: https://www.mediawiki.org/wiki/API:Etiquette
- Für nichtinteraktive Wikimedia-Aufträge maxlag und Backoff beachten: https://www.mediawiki.org/wiki/Manual:Maxlag_parameter
- Supabase: Spend Cap deckt nur bestimmte Kostenpositionen ab: https://supabase.com/docs/guides/platform/cost-control
- Supabase Produktions-/Missbrauchsprüfung: https://supabase.com/docs/guides/deployment/going-into-prod

Planwerte sind eigene Vorschläge und keine aus diesen Quellen übernommenen Quoten oder Preiszusagen.

Sol hat den bestehenden Queue-/Cache-Code und die Umsetzung gegengeprüft. Die anfängliche Planung selbst änderte keine App. Nach der ausdrücklichen Umsetzungsfreigabe wurden Swift-, UI-, Deno-, SQL- und reale Quellenprüfungen ausgeführt; Ergebnisse im Abnahmebericht. Einzelne Zielwerte und Release-Prüfungen sind dort von tatsächlich implementierten bzw. gemessenen Eigenschaften unterschieden.
