# Album — autonome Abnahme am 03.10.2026

Übernahme ab 12:53 CEST, Zeitrahmen maximal 30 Minuten. Bestehende Änderungen bleiben erhalten; kein Commit, Push oder Deployment.

## Ergebnis
Die Abnahme ist nicht vollständig grün. Drei gezielte Korrekturen sind umgesetzt: breite, vertikale Editoraktionen bei Accessibility-Schrift, skalierte Reisetagskarten und vollständige Serverbereitschaft vor dem ersten Realtime-Abgleich. Der Nachtest am aktuellen Produktcode umfasst 36 bestandene Speicher-/Sync-/Download-Regressionsfälle und zwei erfolgreiche echte Swift-Live-Läufe mit jeweils zwei isolierten Teilnehmern. Der Maximalschrift-Bedientest besteht; der Editor-Audit bleibt mit drei Befunden offen.

## Prüfungen und Belege
Alle folgenden Pfade beziehen sich auf `qa-night/20261003T121547+0200/`.

| Prüfung | Ergebnis | Beleg |
| --- | --- | --- |
| Übernommene Gesamtsuite, Version vor den neuen Korrekturen | 144 bestanden, 9 fehlgeschlagen, 4 übersprungen; unterbrochen | final-full-suite.xcresult, final-full-suite-summary.json |
| Aktuelle App + Testbundles bauen | Bestanden, zweimal | autonomous-build.log, autonomous-build-2.log |
| Speicher, veraltete Antworten, Sync, Downloads, neue Readiness-Regressionen | 36 bestanden, 0 Fehler, 0 Skips | autonomous-regressions.xcresult |
| Realtime: Ort, Beitrag, Kommentar, Herz, Reiseänderung | Zwei erfolgreiche unabhängige Läufe | autonomous-live-2.xcresult, autonomous-live-3.xcresult |
| Dokument hinzufügen, PDF herunterladen, Metadaten ändern | In beiden Live-Läufen bestanden | Live-Receipts, Phasen document-add/document-update |
| Abgleich stoppen, Änderung beim Partner, neu starten und nachladen | In beiden Live-Läufen bestanden; ein Kanal, nach Stop kein Kanal | Live-Receipts, subscription.restart.catchup |
| Tatsächliche maximale iOS-Schrift: Reise-/Ideenlayout, vier Rand-Touchproben, Editor abbrechen, Entscheidungen nach Scrollen | Bestanden | autonomous-max-type.xcresult |
| Editor-Audit mit maximaler Schrift | Weiterhin drei Befunde: Custom-Titel Dynamic Type/Clipping, Kontrast des deaktivierten Speichern-Knopfs | autonomous-editor-evidence, autonomous-max-type.xcresult |
| Karte: Höhen, kurzer/langer Zug, schließen, wieder öffnen, Auswahl, Rotation | Bestanden am aktuellen Stand, rein funktional ohne zusätzlichen Audit | autonomous-map-motion.xcresult, autonomous-map-evidence |

Die Gesamtsuite meldete sieben fehlgeschlagene Accessibility-Auditfälle sowie einen Layouttest mit einer falschen Annahme über den Scrollbereich bei normaler Schrift. Den festhängenden Screen-Tour-Test habe ich nach rund drei Minuten im betroffenen Schritt mit SIGINT beendet; seine neun Fehler enthalten diesen Abbruch. Dieser Lauf ist kein vollständiger finaler Pass. Nachfolgende Tests sind gezielte Nachtests, keine zweite Komplettabnahme.

## Korrekturen
- `Album/PlaceEditor.swift`: Bei Accessibility-Schrift stehen Abbrechen und Speichern jetzt untereinander über die volle Breite; stabile IDs entsprechen der normalen Toolbar. Der exportierte Screenshot zeigt beide Wörter vollständig und zentriert.
- `Album/Stitch/ReiseView.swift`: Breite der Accessibility-Tageskarten skaliert mit Dynamic Type; Wochentag und Datum behalten ihre intrinsische horizontale Größe.
- `Album/SupabaseSync.swift`: Nicht mehr jedes beliebige system-ok akzeptieren. Erst sowohl postgres_changes als auch system/replication-ready bestätigen, dann Startup-Catchup starten. Regressionen prüfen Reihenfolge, doppelte Bestätigungen, unbekannte Nachrichten und Fehler.
- `AlbumTests/SyncRegressionTests.swift`: Drei neue Readiness-Regressionen.
- `AlbumTests/SupabaseSwiftIntegrationTests.swift`: Dokument-Live-Gate des übernommenen Laufs um expliziten Stop-/Restart-Catchup ergänzt; Testadapter vor Neustart korrekt zurück auf den produktiven Sync-Service gesetzt. Der erste autonome Live-Lauf scheiterte allein an diesem zunächst nicht zurückgestellten Testadapter. Orte und Dokumente kamen bereits in diesem Lauf an.
- `AlbumUITests/AccessibilityScreenUITests.swift`: Normale Schrift darf ohne ScrollView auskommen; alle Touch-, Editor-, Sichtbarkeits- und Same-Card-Prüfungen bleiben erhalten.

Die Serverbestätigungen folgen dem [Supabase-Realtime-Protokoll](https://supabase.com/docs/guides/realtime/protocol). Keine festen Startverzögerungen hinzugefügt, keine neuen Audit-Unterdrückungen.

## Offen und Grenzen
1. Verbleibende Accessibility-Audits auf Reise, Ideen und Karte sind nicht vollständig behoben. Ein Teil betrifft Custom-Schriften oder native Elemente; konkrete Befunde müssen weiter einzeln bewertet werden. Die deaktivierte Aktion ist sichtbar, aber ihre Audit-Ausnahme wurde nicht pauschal unterdrückt.
2. Direkte CUA-Abnahme: Device Hub war kurz erreichbar und zeigte die Karte, danach meldete CUA ausdrücklich die Mac-Sperre. Kein Umgehen der Sperre, keine menschliche Fließigkeits- oder Haptikabnahme behauptet.
3. Systemweites Reduce Motion bleibt ungetestet; ein Umgebungsflag würde keine echte OS-Einstellung beweisen.
4. Ein echter unerwarteter Netzausfall bleibt ungetestet. Stop-/Restart-Catchup ist geprüft, ersetzt aber keinen Ausfalltest mit realer Verbindungstrennung.
5. Echte Buchungs-PDF fehlt; synthetische PDF-Übertragung und Parsing sind geprüft. Dokumentlöschen/Realtime-Entfernen ist mit dem vorhandenen Produktpfad nicht abgenommen.
6. Physische Haptik und Installation auf dem iPhone benötigen den Gerätecheck; kein Gefühl/FPS-Versprechen aus Simulatorbildern.

## Bereinigung
Alle drei eigenen Live-Testreisen, sechs QA-Nutzer und ihre synthetischen PDFs wurden über Receipt-/Membership-Guards bereinigt; PDFs zuerst über die Supabase Storage API (CLI), keine direkten Storage-SQL-Löschungen. Backend danach: exakt 1 Reise, 3 Mitglieder, 0 Collection-Einträge, 0 QA-Nutzer, 0 eigene Storage-Objekte. Die fehlende DELETE-Policy für trip-files erforderte den bereits konfigurierten administrativen CLI-Zugang; keine Rechte oder Policies erweitert.

Schriftgröße wieder `large`; Testplan bytegleich zum gesicherten Ausgangsstand nach jedem Lauf zurückgestellt. Reduce Motion nicht geändert. Fremde Simulatoren unangetastet. AppGroup-Endzustand kontrolliert: keine Queue-Dateien. Der bereits vor den eigenen Nachtests vorhandene Kontext (Album-ID E0ED0CF4-BE29-4C08-A832-A75F5925A720) ist unverändert und wurde nicht gelöscht. Die alte Fortschrittsautomation ist pausiert, da die Prüfung hier übernommen wurde.
