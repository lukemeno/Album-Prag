# Album Reise-Assistent – Umsetzungsplan

Stand: 03.10.2026. Ergebnis der grilling-Runden; alle ausgesprochenen Empfehlungen sind bestätigt. Umsetzung noch nicht gestartet.

## Bestätigtes Produkt

Privater Chat pro Teilnehmer mit gemeinsamem Reisekontext. Schwebender Einstieg unten rechts oberhalb der Tab-Leiste auf allen Hauptseiten, auch Karte; bei Editoren/Dialogen ausgeblendet. Position respektiert die aufziehbare Kartenliste und deren Bedienelemente. Zusätzliche kontextuelle Einstiege bei Ort und Tagesplan. Eingabe per Text und zunächst nativer iOS-Tastatur-Diktierfunktion. Kurze Antworten, bedienbare Ortskarten und Tagesplan-Vorschauen; Quelle öffnen, Auf Karte zeigen, Als Ort speichern, Plan übernehmen.

Erste Version: gespeicherte Orte und Sammlung berücksichtigen, Tagesplanung, Was passt jetzt?, Plan spontan anpassen (Zeit, Müdigkeit, Regen), Fragen zu Flug/Hotel/Reiseunterlagen, externe Ortssuche und Web-Recherche mit Quellen. Aktueller Standort nur auf ausdrücklichen Aufruf mit iOS-Berechtigung; gewählter Ausgangspunkt als Alternative. Persönliche Vorlieben erst nach sichtbarer Zustimmung merken, bearbeiten/löschen ermöglichen. Sammlungsbereinigung folgt nach der ersten Version. Keine Buchungen/Käufe oder laufenden Sprachgespräche.

Änderungen an der Reise zuerst als konkrete Vorschau, erst nach Bestätigung speichern und mit Teilnehmern synchronisieren. Zwischenzeitliche Änderungen revalidieren, Konflikte nicht überschreiben. Rückgängig als bedingte Gegenaktion, die neuere Änderungen ebenfalls nicht überschreibt. Private Chats anderer Teilnehmer sind kein Kontext.

Benötigte Informationen dürfen über das Backend an einen KI-Anbieter geschickt werden; keine pauschale Übertragung aller PDFs/Chats. Provider-Key bleibt ausschließlich im Backend. Zielbudget 10 EUR/Monat für beide, Verbrauchsanzeige und App-Quota. Anbieter: OpenAI; Standardmodell: gpt-6-luna über Responses API. Preise und konkrete Quoten vor der Live-Anbindung festlegen; Zielbudget ist keine Zusage einer exakten Anbieterrechnung.

## Code-Anschlüsse und fehlende Bausteine

- Album/AlbumRoot.swift: globaler Tab-Host und bestehende Sheets; neuer zentraler Chat-Host und Floating-Einstieg.
- Album/TripMapView.swift + Album/PlacesDrawer.swift: bestehende Detents und Kartenabdeckung; Layoutzustand für Buttonposition weitergeben, keine zweite Drag-Geste über den Drawer legen.
- Album/AlbumStore.swift: Ortsmutationen und atomisches Anwenden von Tagesplan-Vorschlägen vorhanden; allgemeine revisionsgeprüfte Aktions-/Undo-Schicht fehlt.
- Album/Models.swift + Album/TripDocumentParser.swift: Dokumenttext und strukturierte Buchungsdaten vorhanden; Seiten-/Textstellenreferenzen fehlen.
- supabase/functions/_shared/album.ts: vorhandene Bearer-Auth und Mitgliedschaftsprüfung als Grundlage für neuen KI-Endpoint. Aktuelle Anmeldung anonym: private Daten strikt an Auth-ID binden; Anzeigename ist keine Berechtigung.
- Sammlung hat Versions-/CAS-Muster; Trip/Place-Mutationen benötigen gleichwertige Konfliktkontrolle für bestätigte Bot-Aktionen.
- Keine bestehende KI-Integration, Chat-Historie, persönliche Preference-Schicht, allgemeine Recherche oder Monatsquota. Kein Standortdienst für gezielten Bot-Aufruf.

## Issue-Entwürfe (noch nicht in Linear erstellt)

Linear-Suche nach Album ergab kein Zielprojekt. Entwürfe bleiben hier; Linear-Zuordnung vor Erstellung klären.

### A1 – Chat-Einstieg und private Unterhaltung
Ziel: leicht erreichbarer, ruhiger Chat im vorhandenen Designsystem.
Umfang: Floating-Button, native Sheet-Präsentation, Text/Diktieren, lokale private Historie als Umsetzungsvorschlag, Lade-/Abbrechen-/Wiederholen-/Offline-Zustände, löschbare Unterhaltungen. Kontextuelle Einstiege bei Ort und Plan.
Akzeptanz: alle Hauptseiten und Drawer-Detents bedienbar; Button verdeckt keine Kartenaktionen; Editor/Dialog blendet Einstieg aus; große Schrift/Rotation/Reduce Motion unterstützt; gespeicherte Unterhaltung nach Neustart lesbar. Kein Audio-Upload für Tastatur-Diktieren nötig.
Abhängigkeit: A2 für echte Antworten, lokale UI mit isoliertem Testadapter vorab prüfbar.
Prüfung: UI-Test für Karte/Drawer/Chat/Keyboard, Abbruch und Neustart; Nutzertexte dürfen nicht in Produktlogs landen.

### A2 – KI-Endpoint, Zugriff und Nutzungslimit
Ziel: sichere, begrenzte Anfragen ohne Schlüssel in der App.
Umfang: serverseitiger Anbieteradapter, Auth-/Trip-Mitgliedschaft, strikte Tool-Schemas, Request-ID, Limits für Kontext/Antwort, Kosten-/Tokenzähler, serverseitige Rate-/Monatsquoten, geschützter Provider-Key.
Akzeptanz: fremde Reise und fremde private Informationen nicht abrufbar; fehlende Auth/Quota führt zu verständlicher Antwort; Limits atomar auch bei gleichzeitigen Anfragen; Netzwerkabbruch erzeugt keine Reiseänderung; Texte aus Web/PDF sind Daten und dürfen keine System-/Tool-Berechtigungen ändern.
Abhängigkeit: Anbieter/API-Key, aktuelles Preismodell und Betriebs-Konfiguration.
Prüfung: isolierte Zwei-Teilnehmer- und Fremdreise-Tests, parallele Quota-Anfragen, manipulierte Dokument-/Web-Texte, Ausfall/Timeout.

### A3 – Reisekontext und Dokumentfragen mit Belegen
Ziel: Antworten auf tatsächliche Reiseinformationen gründen.
Umfang: aktuelle Orte, Sammlung und Tagesplan gezielt lesen; strukturierte Flug-/Hoteldaten und relevante Dokumentausschnitte abrufen; Dokument-ID plus verlässliche Seite/Textstelle als Quellenmodell ergänzen.
Akzeptanz: Quelle öffnet passendes Dokument/Belegstelle; fehlende Information wird als unbekannt bezeichnet; Flug-/Check-in-Angaben werden nicht erfunden; private Chats anderer bleiben ausgeschlossen; nur notwendige Ausschnitte gehen zum Anbieter.
Abhängigkeit: A2.
Prüfung: synthetische Buchungs-PDFs mit widersprüchlichen Angaben, gelöschte/ersetzte Dokumente, Source-Link-UI und Zugriffstests.

### A4 – Bedienbare Ergebnisse und bestätigte Aktionen
Ziel: aus Antworten brauchbare Orts-/Planvorschläge machen.
Umfang: typisierte Antwortkarten, Karte öffnen, Ortseditor vorbereiten, bestehende Planung wiederverwenden, expliziter Bestätigungsschritt. Revisions-/Snapshot-Prüfung und bedingtes Undo für betroffene Felder.
Akzeptanz: Chattext allein verändert nichts; Ort/Vorschlag ist editierbar; doppelte Bestätigung erzeugt keinen Doppelimport; Planänderungen werden vor Speichern gegen aktuellen Stand geprüft; Undo überschreibt keine jüngeren Teilnehmeränderungen.
Abhängigkeit: A2/A3, revisionsgeprüfte Persistenz.
Prüfung: konkurrierende Planänderungen auf zwei Clients, Bestätigung nach verspäteter Antwort, wiederholter Request, Wiederanlauf und Undo-Konflikt.

### A5 – Web-Recherche und aktuelle Ortsinformationen
Ziel: neue Orte, Öffnungszeiten und Alternativen nachvollziehbar recherchieren.
Umfang: Maps-Ortssuche plus serverseitige Web-Recherche, Quellen-URLs und Abrufzeit; gespeicherte Angaben von neuen Ergebnissen unterscheiden. Zulässige URLs/Redirects und Größenlimits prüfen.
Akzeptanz: konkrete Ortskarte mit überprüften Koordinaten; Öffnungszeiten/Wetter nur mit passender Quelle und Zeitpunkt oder explizitem Nichtwissen; keine unpassenden Ortstreffer; fehlerhafte Quellen öffnen nicht beliebige lokale Ziele.
Abhängigkeit: A2/A3, Rechercheanbieter mit Kosten und Zugang.
Prüfung: geschlossene Orte, ähnlich benannte Orte, gesperrte Webseiten, veraltete Daten und ungültige Quellen.

### A6 – Was passt jetzt?, spontane Anpassung und Vorlieben
Ziel: zur aktuellen Situation passende Vorschläge liefern.
Umfang: Zeitfenster, Ausgangspunkt, vorhandene Orte und bestätigte persönliche Vorlieben; Standort on demand, keine Hintergrundverfolgung; Regen-/Müdigkeits-/Kurzzeit-Anpassung als bestätigbarer Plan. Persönliche Vorlieben sichtbar merken/bearbeiten/löschen.
Akzeptanz: bei verweigertem Standort bleibt gewählter Ausgangspunkt nutzbar; Standortdaten werden nur bedarfsgerecht verwendet; keine unmöglichen Zeit-/Wegepläne; persönliche Vorlieben werden nicht ungefragt zur Gruppenregel.
Abhängigkeit: A3/A4/A5.
Prüfung: Berechtigung verweigert/ungefährer Standort, leerer Plan, zwei Stunden Zeit, konkurrierende Teilnehmerpräferenzen, Offline-Ausfall.

### A7 – Abnahme auf Simulator und beiden Geräten
Ziel: vollständige Kernabläufe und Fehlersituationen verifizieren.
Umfang: isolierte Testdaten, wiederholbare Mock-Anbieter-Tests, begrenzte echte API-Stichprobe und Gerätebedienung.
Akzeptanz: Kontextfrage, Quellenöffnung, Ortskarte, Planbestätigung, Undo, Konflikt, Quote, Löschen und Offline-Zustände bestehen; keine Tests verändern persönliche Reise-/Chatdaten. Signierter Build inklusive Share Extension bleibt installierbar.
Abhängigkeit: A1–A6.
Prüfung: Testbericht mit tatsächlich geprüften Fällen, Kosten der Live-Stichprobe und verbleibenden Grenzen.

### A8 – Später: Sammlung aufräumen
Ziel: ähnliche Ideen erkennen und Beiträge bestätigten Orten zuordnen.
Umfang: Vorschau, explizite Bestätigung, reversible Verknüpfungen; keine stille Löschung von Nachrichten/Quellen.
Abhängigkeit: stabile erste Version und A4.
Prüfung: Duplikate mit verschiedenen Notizen/Autoren, Rückgängig und parallele Änderungen.

## Reihenfolge und offene Umsetzungsvoraussetzungen

A2-Grundlage + A1, danach A3/A4, A5/A6, schließlich A7. Sol prüft Plan und schwierige Änderungen; Luna implementiert abgegrenzte freigegebene Pakete.

OpenAI-Zugang eingerichtet: Schlüssel Travel Buddy im ausgewählten Default project lokal als OPENAI_API_KEY in Git-ignorierter .env.local gespeichert (owner-only). Authentifizierter GET /v1/models/gpt-6-luna erfolgreich (HTTP200). Keine Chat-Anfrage und keine Produktionsbereitstellung durchgeführt. Schlüssel nicht in App-Bundle aufnehmen.

Offen: serverseitige Anbindung/Secret-Bereitstellung, konkrete Preis-/Quota-Konfiguration, Recherche-Anbindung und Linear-Zielprojekt. Chatbot-Implementierung noch nicht begonnen.
