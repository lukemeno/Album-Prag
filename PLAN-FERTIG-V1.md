# Plan: Album Version 1 fertigstellen · Entwurf 25.10.2026

Status: Vorschlag, nichts umgesetzt. Start erst nach Freigabe des Nutzers. Push, Deploy, Migrationen und alles mit Auth, Zahlung oder Sicherheit brauchen je ein eigenes Go.

## 0. Was „fertig“ heißt (Annahme, bitte bestätigen)

Version 1 ist eine App für fremde Nutzer im App Store: eigene Reisen anlegen, Plan, Ideen mit passenden Bildern, Karte, Gruppe, Unterlagen, Ausgaben, Erinnerungen, Assistent mit fairem Kontingent, Entdecken. Das ist die Richtung aus `PLAN-APPSTORE.md`. Die Prag-Reise (4.–9.10.) ist vorbei, die App muss ohne festen Prag-Bezug laufen. Nicht in V1: Instagram/TikTok-Trends (`PLAN-SOCIAL-TRENDS.md`), Expo/Android.

## 1. Ausgangslage (im Repository geprüft)

- Lokaler `main` liegt 15 Commits vor `origin/main`. Im Working Tree liegt uncommittete Arbeit (Fan-Menü-Geometrie, Reiseerinnerungen, Ortsvorschläge in `AlbumStore.swift`, `Models.swift`, `AlbumExperienceRoot.swift`, `AlbumExperienceViews.swift`).
- Letzter dokumentierter Lauf: 246 Tests, 4 Skips, 0 Fehler. Optik: weiß/dunkelgrün mit Haltemenü.
- Backend live: place-photo v9, place-enrichment v5, Assistenten-Limits Welle 1. `discover-places` ist standardmäßig deaktiviert.
- **Fehlt im Code:** Reisewahl mit mehreren Reisen (`TripLibraryView` lag nur im alten WIP-Branch, nicht auf `main`), Anmeldung, Bezahlung, App Attest. Es gibt nur `PrivacyInfo.xcprivacy`.
- Auf dem iPhone läuft noch `a63fb6f`, ohne B1.

## 2. Phasen

### Phase A · Stand sichern (klein, zuerst)
1. Uncommittete Arbeit in thematische Commits ordnen (Fan-Geometrie, Reiseerinnerungen, Ortsvorschläge). Nichts verwerfen. **Beleg:** `git status` sauber, Commit-SHAs.
2. Voller Testlauf auf dem Commit-Stand (Unit und UI). **Beleg:** `.xcresult`, 0 Fehler.
3. Aktuellen `main` auf das iPhone installieren und die echte Reise prüfen, ohne sie zu ändern. **Beleg:** Screenshots vom Gerät.

### Phase B · V1-Funktionen ohne Apple-Konto
Reihenfolge nach Nutzen für den Erstkontakt:
1. **Reisewahl und Neue Reise** (Referenzbild des Nutzers): Reiseliste auf Home, Reise anlegen mit Name, Ziel, Zeitraum, Foto; Onboarding ohne Prag-Vorgaben. Größte Lücke, **L**.
2. **Ideen komplett:** Ortsvorschläge beim Tippen, Bestätigen und Verbinden, Fotos ohne Ort, Kamera im Fan-Menü (`PLAN-IDEEN-ORTSVORSCHLAEGE.md`). Teilweise in Arbeit, **M**.
3. **Bildauswahl-Rest** (`PLAN-BILDAUSWAHL.md`): 14 Testfälle von Hand labeln, KI-Prüfung der besten Kandidaten, Laufzeitbilder von Google/Tripadvisor/Yelp nur mit Namensnennung und ohne Speicherung (Nutzerentscheidung vom 22.10.). Vorher Messlauf gegen die Testliste, **L**.
4. **Entdecken V1 abnehmen:** vier Städte mit echter Datenqualität, WDQS-Timeouts, Quellenbegrenzung, dann bewusst aktivieren (`ENTDECKEN-QA.md`), **M**.
5. **Kontingent sichtbar machen:** „Noch N Fragen“, Meldung bei 0, Probe-Kontingent. Die Serverlogik für Credits ist Welle 2 und braucht Phase D, **S**.
6. **Backend-Hygiene (C1):** B1-Drift in `assistant_validation.ts` auflösen, QA-Migrationen ersetzen, `compare-live-functions.sh`. Deploys nur mit Go, **S**.

### Phase C · App-Store-Hygiene ohne Konto
Datenschutz-Texte und Nutzungsbeschreibungen, `PrivacyInfo.xcprivacy` gegen den echten Datenfluss prüfen, Konto- und Datenlöschung, sichtbare Bild-Quellenangaben, Dunkelmodus in Grün prüfen, Fehler- und Offline-Zustände, VoiceOver-Labels, Dynamic Type, App-Icon, Launch Screen, Screenshots, Support- und Datenschutz-URL. **M**. Prüfskripte aus A1 (`verify-ios.sh`, `verify-backend.sh`, `lanes.sh`) liegen geparkt auf `17ef72b` im Sicherungs-Bundle und sollten zuerst zurückgeholt werden.

### Phase D · braucht das bezahlte Apple-Developer-Konto (Nutzeraktion)
Sign in with Apple, App Attest/DeviceCheck, StoreKit 2 mit Reise-Pass, App Store Server Notifications V2, TestFlight, App-Review. Das hat die längste Wartezeit und blockiert den Rest nicht. **Empfehlung:** Konto jetzt anlegen, damit Phase D parallel zu B und C vorbereitet werden kann. Auth und Zahlung nur mit ausdrücklicher Freigabe je Teil.

### Phase E · Abnahme auf echten Geräten
Kamera, fühlbare Haptik, VoiceOver, Sync und Offline-Rückkehr zwischen zwei iPhones, Gruppe einladen und beitreten, Fremdgerät ohne Prag-Daten. Danach TestFlight-Runde mit 3–5 Personen.

## 3. Arbeitsweise

- Der Hauptchat plant und prüft. Sol plant und reviewt, Luna setzt um (Nutzerpräferenz vom 02.10.). Unabhängige Pakete laufen parallel, nie zwei Schreiber an denselben Dateien.
- Jedes Paket gilt erst nach eigenem Diff, Build und Test als erledigt. E2E-Tests bevorzugt, keine nachträglichen Unit-Tests.
- Nach jedem Meilenstein ein kurzer Eintrag in `PROGRESS.md`.

## 4. Entscheidungen (26.10.2026, Nutzer)

1. **Ziel:** App Store V1 für fremde Nutzer mit Reise-Pass.
2. **Apple-Developer-Konto:** erst nach den Funktionen. Phase D (Anmeldung, Bezahlung, TestFlight) rückt ans Ende; Phase B und C laufen ohne Konto.
3. **Start:** Reisewahl und Neue Reise.

## 5. Ursprüngliche Fragen

1. Stimmt die Definition von „fertig“ in Abschnitt 0 (App Store, fremde Nutzer, Reise-Pass)?
2. Apple-Developer-Konto jetzt anlegen (Empfehlung) oder erst nach Phase B?
3. Phase B ab Punkt 1 (Reisewahl) beginnen, weil sie die größte Lücke ist?

## 6. Start: Reisewahl und Neue Reise (Planentwurf, 26.10.2026)

**Befund.** `AlbumApp` besitzt genau einen `AlbumStore` (eine `album.json`, eine `AlbumData` mit einem `TripInfo`). Mehrere Reisen gibt es nur im alten WIP-Commit `0f02198` (liegt im Sicherungs-Bundle): `TripLibrary.swift` (385 Zeilen), `TripLibraryView.swift`, `TripLibraryTests`, `TripLibraryUITests`, `Design/Trip-Library/PLAN.md` mit Issue-Entwürfen ML-01 bis ML-06. Dieser Code stammt aus der Zeit vor B1, vor dem nativen Port und vor dem weißen/grünen Design. **Er wird von Hand nach `main` portiert, nicht gemerged** (`AlbumStore.swift` wurde dort um 1.059 Zeilen umgebaut und kollidiert mit B1).

**Bestätigte Produktregeln (aus dem Plan vom 16.10.):** eigene Gruppe je Reise; Kaltstart öffnet die zuletzt geöffnete gültige Reise, sonst die Übersicht; „Alle Reisen“ aus jedem Tab erreichbar; Reiseübersicht ohne Assistent; offene Termine erlaubt.

**Pakete in Reihenfolge**
1. **Bibliothek (ML-01).** Versionierter Index, pro Reise eigenes Verzeichnis und eigener Store, Fabrik für neue Stores, sichere Übernahme der bestehenden `album.json` samt Bildern und PDFs (erst Kopie, dann Prüfung, dann Umschalten). Dateien: neu `TripLibrary.swift`, Änderung `AlbumApp.swift`, `AlbumStore.swift` (nur Init/Pfad). Risiko: Datenverlust der echten Prag-Reise. Prüfung: Migrationstest auf einer Kopie, defekter Index, volle Platte.
2. **Übersicht (ML-02).** Native Karten wie dein Referenzbild (Foto, Ziel, Zeitraum oder „Zeitraum offen“, Mitglieder) in Weiß/Dunkelgrün. Einstieg über Home, „Alle Reisen“ in den Tabs. Dateien: neu `TripLibraryView.swift`, Änderung `AlbumExperienceRoot.swift`, `AlbumExperienceViews.swift`. Prüfung: UI-Test Öffnen/Zurück/Neustart, 20 Reisen, große Schrift, VoiceOver.
3. **Neue Reise und Einladung (ML-03).** Bestehenden `TripEditor` für eine neue Store-Instanz nutzen, Onboarding ohne Prag-Vorgaben, Einladung doppelt öffnen ergibt einen Eintrag, Abbruch ändert nichts. Dateien: `TripDocumentsView.swift`, Routing in `AlbumApp.swift`/`AlbumExperienceRoot.swift`.
4. **Sync je Reise isolieren (ML-04).** Eigener Sync und Realtime je Store, späte Antworten (KI, Fotos, Geocoding) bleiben an ihrer Reise. Dateien: `SupabaseSync.swift`, `AssistantSession.swift`, `PlaceImageStorage.swift`. Risiko: kollidiert mit der uncommitteten Foto-Arbeit, daher erst nach Phase A.
5. **Gruppen und Entscheidungen (ML-05).** Echte Mitglieder statt Namen, stabile Mitglieds-IDs für Stimmen, alte Namensstimmen erhalten. Braucht eine **Produktregel für „alle dafür“** (siehe Entscheidung unten) und voraussichtlich Backend-RPCs. Migration nur zuerst auf Testprojekt, live nur mit Go.
6. **Abnahme (ML-06).** E2E: Prag und Paris anlegen, Ideen je Reise, wechseln, Neustart, Einladung zu dritter Reise, späte KI-Antwort bleibt in der richtigen Reise.

**Vorher (Phase A):** Working Tree ordnen. 10 Dateien, +703/−182, überwiegend Foto-, Ortsvorschlags- und Fan-Arbeit von Codex, teils mit gemischten Änderungen in denselben Dateien. Plan: ein Commit je erkennbarem Thema, bei vermischten Hunks ein gemeinsamer Commit. Dann voller Testlauf.

**Rollen:** Sol prüft Plan und Diffs, Luna setzt um, ich integriere und prüfe selbst (Diff, Build, Test). Pakete 1 und 2 nacheinander, weil beide am Einstieg ändern.

**Entscheidung für später (blockiert Paket 5, nicht 1 bis 4):** Was heißt „gemeinsam beschlossen“ in einer Gruppe mit mehr als zwei Personen: alle stimmen zu, oder Mehrheit?
