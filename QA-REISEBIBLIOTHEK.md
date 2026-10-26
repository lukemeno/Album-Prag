# Reisebibliothek – Abnahme 27.10.2026

## Verhalten

- Neuinstallation: leere Bibliothek. Neue Reise: eigener Name, Ziel und optionale Termine, keine Beispielorte oder erfundenen Reiseinformationen.
- Zur Bibliothek zurückkehren und weitere Reisen anlegen. Ideen, Unterlagen, Ausgaben, Erinnerungen und lokale Fotos liegen im jeweiligen Reiseordner.
- Vorhandene persönliche Daten werden kopiert und geprüft; der bisherige Album-Ordner bleibt erhalten. Nur vollständig unveränderte frühere Beispieldatensätze werden entfernt; eigene Änderungen, Fotos und Abstimmungen sind geschützt.
- Einladungen werden separat geladen und erst nach erfolgreicher Vorbereitung als Reise übernommen; derselbe geteilte Trip erscheint einmal.
- Automatische Ortsfotos nutzen den Kontext der geöffneten Reise und die bereits geprüfte kostenlose Bildpipeline. Ein Foto kann fehlen, wenn kein verlässlicher Treffer verfügbar ist.

## Selbst testen

1. `Album.xcodeproj` öffnen, Schema **Album**, iPhone-Simulator wählen, ⌘R.
2. Bei vorhandenem Album oben links zur Reisebibliothek zurückgehen. **Neue Reise** wählen, Namen und Ziel eingeben und ohne Termine speichern.
3. Eine Idee einwerfen, einen MapKit-Ort bestätigen und das automatisch geladene Foto prüfen. Eine weitere Idee ohne eindeutigen Treffer darf einen Platzhalter behalten.
4. Ein PDF und eine Ausgabe ergänzen. Zur Bibliothek zurückgehen und eine zweite Reise anlegen: Sie muss leer sein.
5. Zur ersten Reise wechseln: Idee, Foto, PDF und Ausgabe müssen erhalten sein. App beenden und wieder öffnen.
6. Auf zwei signierten echten iPhones später Einladungslink, gegenseitige Änderungen, PDF-/Foto-Download und Offline-Abgleich prüfen.

## Grenzen

Simulatorprüfungen ersetzen keine Haptik-, Kamera-, VoiceOver- oder Zwei-iPhone-Abnahme. iOS 18 wurde in dieser Nacht nicht geprüft. Unsigned Simulator-Builds besitzen keine dauerhaft nutzbare Schlüsselbund-Sitzung; echte Supabase-Synchronisierung daher mit signierten Builds prüfen. Eine App-Store-Freigabe ist nicht Bestandteil dieses Auftrags. Die weitergehenden Foto-Pilot-/Rechtepunkte stehen in QA-AUTOMATISCHE-ORTSFOTOS.md.

## Prüfprotokoll

- Vollständige finale Unit-Suite: `/tmp/album-night-final-units-20261027.xcresult`, **285 Tests, 278 bestanden, 7 bewusst übersprungen, 0 Fehler**. Enthält echte geschützte Legacy-Kopie sowie Migration/Fehlerpfade, leere Defaults, getrennte PDF-/Ausgabenablage, Einladungs-Deduplizierung und gestoppte Sync-/Fotoantworten.
- Sechs Kern-UI-Abläufe im Integrationslauf `/tmp/album-night-final-v2-20261027.xcresult` bestanden: Tabs, Bogen-Menü→Unterlagen, automatisches Foto→Neustart, Erstellen/Abbrechen/Wechseln, Erststart mit Namen, Ideen-Isolation→Neustart. Der Gesamtstatus dieses Zwischenlaufs war wegen drei anschließend behobener Unit-/Testharness-Fehler rot; die sechs UI-Ergebnisse waren grün. Die finale Unit-Suite oben prüft die Korrekturen.
- Separater opt-in Lauf `/tmp/album-night-real-copy-photo-20261027.xcresult`: 11 Begleitdateien bytegleich, 30 geschützte Orte geprüft; zusätzlich reales Knedlín-Foto automatisch geladen und nach Neustart erhalten. Originales Simulator-Album vor abschließender Installation erneut gegen das geschützte Backup geprüft: alle12 Dateien unverändert. Keine privaten Albuminhalte oder Einladungs-Tokens im Bericht.
- Sol: fokussiertes Code-GO d6a3889, nach letztem Lifecycle-/Migration-Patch erneut GO für ca57f90. Screenshot-Prüfung entdeckte zusätzlich festen PRAHA-Stempel; generische Stempel90d42ae verwenden jetzt ALBUM.
- Finale Library-UI-Suite `/tmp/album-night-ui-final-20261027.xcresult`: alle3 Abläufe bestanden, einschließlich Namenseingabe, Erstellen/Abbrechen/Wechsel und Ideen-Isolation nach Neustart. Aktuelle Screenshots unter `.qa-shots/night-library-20261027/`; leere Bibliothek, Formular, zwei echte QA-Reisen und gespeicherte Idee visuell geprüft. Der Ideen-Screenshot zeigt noch den letzten Rand der Sheet-Dismiss-Animation; er ist kein Nachweis einer dauerhaft stehenbleibenden Oberfläche. Zusätzliche ruhende Plan-Aufnahme separat gespeichert.
- Finaler Release-Build für arm64-Simulator erfolgreich: `/tmp/album-night-release-final-20261027.log`. Vorher auch universeller Release-Build erfolgreich. Keine Swift-Compilerfehler.
- Aktuelles Debug-Bundle auf bestehendem iPhone18Pro-Simulator installiert, ohne Deinstallation oder Containerlöschung. Persönliches Album dort nicht für einen Testlauf geöffnet. Xcode mit Schema Album und Ziel iPhone18Pro geöffnet; für eigenen Start **⌘R** drücken. Die isolierte QA-Reise im iPhone17-Simulator enthält absichtlich selbst erstellte Testdaten; sie ist keine Produktionsvorlage.
- Alle Änderungen lokal committet, nichts gepusht. Zwei vor Beginn vorhandene unversionierte Planentwürfe bleiben unangetastet. Die beiden eigenen Luna-Worktrees sind nach vollständiger Integration entfernt.

Bewusst übersprungene Tests benötigen ein echtes Booking-PDF, explizit aktivierte externe Fotoquellen oder signierte Live-Supabase-Sitzungen. Kein Erfolg für diese ausgelassenen Prüfungen behauptet. Die reale Foto-UI wurde im getrennten opt-in Lauf geprüft.
