# Native Übertragung · 19.10.2026

Freigegeben: „dann mach das bitte“. Vorlage ist der geprüfte HTML-Prototyp im Scratch-Projekt, Commit `22e2176`; Ausgangspunkt der nativen App ist `aa223ce` auf `design/designsystem-v2`.

## Ziel und Umfang
Die Oberfläche erhält die weiße/grüne Gestaltung des Prototyps sowie Home → Reise mit Plan, Ideen, Karte und Gruppe. Echte Reisedaten (Prag 4.–9.10.2026), Supabase, Bilder, PDF-Import und der echte Assistent bleiben Grundlage. Keine erfundenen Teilnehmer, Buchungen, Wetterwerte oder funktional vorgetäuschten Aktionen.

Die vorhandenen ungesicherten Änderungen in `AlbumStore.swift`, `InboxView.swift` und Expo bleiben erhalten. Umsetzung erfolgt durch Luna in zwei getrennten Arbeitskopien, anschließend Integration und Prüfung durch Sol.

## Arbeitspakete / Issue-Entwürfe
1. **Native Oberfläche und Navigation.** Neue SwiftUI-Startseite, Tagesplan, Ideenliste, Gruppenübersicht und Bogen-Menü mit Hold/Drag/Release. Bestehende Karte, Detailansicht, PDF-Import, Teilen, Sammlung und Assistent anschließen. Akzeptanz: alle Ziele erreichbar; Aktionen ändern echte Daten; keine Dopplung der schwebenden Buttons; min.44pt, VoiceOver-Aktionen und Reduce Motion; tatsächliche Fotos und Routen.
2. **Ausgaben und Erinnerungen.** Rückwärtskompatibles optionales Ausgabenbuch im vorhandenen Trip-Payload. Eurocent-Rechnung, validierte Beträge, explizite manuelle CZK-Umrechnung, Beteiligte, Ausgleich und Zusammenführung unabhängiger Einträge. Foto-Kamera und Mediathek über vorhandene Bildspeicherung/Synchronisierung; Ort bewusst zuordnen. Akzeptanz: Neustart erhält Ausgaben, alte Daten dekodieren, parallele Einträge überleben Merge, Abbruch/Fehler ersetzt kein Foto, Kamera ist keine vorgetäuschte Mediathek.
3. **Integration und Nachweis.** Xcode-Projekt aktualisieren, Simulator-Build, relevante Modell-/Synchronisierungstests und neue native Ablauftests. Akzeptanz: Build und gezielte Tests bestehen, Home/Plan/Ideen/Karte/Gruppe/Unterlagen/Ausgaben/Erinnerungen/Assistent visuell prüfen; ursprüngliche Nutzeränderungen bleiben unverändert. Kein Deployment oder Schreiben in die gemeinsame echte Reise zu Testzwecken.

Abhängigkeiten: Paket1 und2 haben getrennte Dateien; Paket3 integriert beide. Keine Linear-Issues erstellt, weil kein Zielprojekt festgelegt ist. Diese Datei enthält die Entwürfe.

## Integrierter Stand
- Native Home- und Reisenavigation, Plan, Ideen, Karte, Gruppe, Bogen-Menü, Unterlagen, Assistent, Ausgaben und Erinnerungen sind integriert. Die aktive Oberfläche folgt der weißen/grünen Vorlage mit Inter/Lora. Es gibt weiterhin genau die vorhandene Prag-Reise; keine neue Mehrreiseverwaltung.
- Kamera und Mediathek sind getrennte Aktionen. Fotos nutzen die vorhandene private Speicherung/Synchronisierung. Ausgaben werden lokal und im vorhandenen Trip-Payload gespeichert; unabhängige Einträge werden anhand ihrer IDs zusammengeführt.
- Xcode-Projekt samt Schriften und Tests aktualisiert. Keine neue Backend-Migration oder Veröffentlichung, keine kostenpflichtigen KI-Aufrufe und keine Änderung der echten gemeinsamen Reise zur Prüfung.

## Prüfung
- Simulator-Build erfolgreich; 147 Unit-Tests bestanden, 4 übersprungen. Enthalten sind Legacy-Decoding, Betragsvalidierung, manuelle CZK-Umrechnung, Cent-Verteilung und parallele Ledger-Einträge.
- Acht unterschiedliche UI-Abläufe bestanden: fünf unveränderte Abläufe im gemeinsamen Endlauf, danach die drei betroffenen Menütests gemeinsam nach der letzten Korrektur. Belege: /tmp/album-native-completion-qa.log und /tmp/album-native-fan-verified.xcresult (TEST SUCCEEDED).
- Bogen-Menü: Unterlagen antippen/schließen/zurückkehren, AI→Essen mit Fixture und Halten/Ziehen erfolgreich. Geschlossene Nodes sind vollständig aus View-/Accessibility-Baum entfernt. Finale Menü- und Assistentenbilder visuell geprüft.
- Ansichten visuell im iPhone-17-Simulator geprüft. Screenshots liegen lokal unter `.qa-shots/native-20261019/` (ignorierte QA-Dateien).
- Frühe Tests waren durch vollen Datenträger blockiert. Ein bestehender Test erwartete eine veraltete Anzahl von Beispieldaten; er prüft jetzt den tatsächlichen Ausgangsbestand und dessen Wiederherstellung.

## Noch auf echten Geräten prüfen
- Kameraaufnahme, VoiceOver und gemeinsame Foto-/Ausgabensynchronisierung zwischen zwei iPhones einschließlich Offline-Rückkehr. Diese Änderungen sind noch nicht auf ein physisches iPhone installiert.
- MapKit-Navigation und Kartenansicht sind angeschlossen; geladene Kartenkacheln waren im Simulator-Screenshot nicht nachweisbar.
- Die bestehenden Nutzeränderungen in AlbumStore.swift, InboxView.swift und Expo bleiben erhalten. Ihre Prüfsummen werden vor dem Abschluss mit dem gesicherten Ausgangsstand verglichen.

## Gerätetest bei nächster Verbindung
1. Den geprüften Build auf beiden iPhones installieren. Gemeinsame Prag-Reise auf dem zweiten Gerät über den privaten Einladungslink öffnen.
2. Auf beiden Geräten je eine unabhängige Ausgabe anlegen und nach dem Abgleich beide Einträge sowie die Salden vergleichen. Einen passenden manuellen Ausgleich erfassen und denselben Stand auf beiden Geräten prüfen.
3. Einem ausgewählten Ort ein Kamerafoto zuordnen; auf dem anderen Gerät das Foto nachladen. Mediathek, Abbrechen und bestätigtes Ersetzen separat prüfen.
4. Ein Gerät offline nehmen, eine Änderung speichern, wieder verbinden und den Abgleich auf beiden Geräten prüfen.
5. Bogen-Menü mit dem Daumen sowie VoiceOver auf dem Gerät prüfen.

Am 19.10. war das bekannte physische iPhone nicht verfügbar. Kein Gerätetest oder Deployment behauptet.
