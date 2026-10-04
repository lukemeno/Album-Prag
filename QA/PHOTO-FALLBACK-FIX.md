# Bildfehler Speculum Alchemiae · 04.10.2026, 11:19 MESZ

## Ursache
Die ursprünglich gespeicherte Seed-Idee enthielt weder Adresse noch Koordinaten. refreshPlaceImages ignorierte sie; AlbumPhoto hatte kein Asset und konnte keine ortsgebundene Ersatzansicht erstellen. Erfolgreiche allgemeine Tests belegten diesen konkreten Seed-Fall zuvor nicht.

## Umsetzung
- Verifizierte Seed-Lage: Haštalská 795/1, Prag; 50.0907544, 14.4224672.
- Bestehende unveränderte Seed-Kopien werden beim Laden und Refresh über upsert repariert. Geänderte Titel, Quellen, abweichende Adressen oder bereits gesetzte Koordinaten bleiben erhalten; Daten werden nicht zurückgesetzt.
- Sichtbare Ideenkarte lädt gezielt ihren Ort. Bei bestätigter Lage kann die Bildansicht sofort eine gekennzeichnete Apple-Kartenansicht laden, während die eigentliche Bildsuche läuft.
- Ohne Koordinaten versucht der Einzel-Refresh eine Quellen-Linkvorschau. Nur vorhandene Thumbnail-Metadaten werden übernommen, keine Ortslage aus Videos erfunden. HTTP-Seiten werden für die Anfrage auf HTTPS gehoben, ATS nicht abgeschaltet. Fehlende Metadaten bleiben als fehlend behandelt.
- Generierte lokale Straßen-/Kartenansichten tragen sichtbar Apple-Karten-Credit.
- Primäre Aktionsfläche bleibt auch im Dunkelmodus Navy mit weißer Schrift. Offen-Aktion hat Abstand zum schwebenden KI-Kreis.

## Prüfung
- /tmp/album-photo-fix.xcresult: 15 bestanden, 0 Fehler, 0 ausgelassen (14 Unit-Regressionen und der neue konkrete UI-Fall).
- Nach zusätzlichem Schutz geänderter Adressen und Abstandskorrektur: /tmp/album-photo-fix-final.xcresult, 3 bestanden, 0 Fehler, 0 ausgelassen.
- UI-Test startet mit einer bereits gespeicherten Speculum-Idee ohne Lage/Bild, injiziert eine leere Backend-Bildantwort und deaktiviert Look Around. Echte Apple-Kartenansicht wird sichtbar und fotografiert. Screenshot: QA/one-hour-screenshots/speculum-fallback.png. Screenshot zeigt Hellmodus; der Startargument-Versuch für Dunkelmodus wurde vom Simulator nicht übernommen, daher keine visuelle Dark-Mode-Abnahme behauptet.
- Simulator und signierter iPhone-Build erfolgreich; /tmp/album-photo-fix-final-build.log, /tmp/album-photo-fix-final-device.log. git diff --check bestanden.
- Build: /tmp/album-hour-device-build/Build/Products/Debug-iphoneos/Album.app.
- Installation des neuen Fixes noch NICHT erfolgt: iPhone15Pro unavailable, devicectl CoreDeviceError4016. /tmp/album-photo-fix-install.log. Nutzer um erneute Verbindung/Entsperren gebeten. Der zuvor installierte Stundenlauf enthält diesen neuen Fix noch nicht.

## Ortsbelege
- https://prague.eu/en/objevujte/speculum-alchemiae-mirror-of-alchemy-zrcadlo-alchymie/
- https://alchemiae.cz/cs/kontakty-a-informace
- https://www.praguecityline.cz/misto/speculum-alchemiae-alchymisticka-dilna

Ein echtes Museumsfoto wurde in diesem Lauf nicht behauptet. Der UI-Nachweis betrifft den sicheren Kartenfallback; Live-Backend-Ortsfotos hängen weiterhin von verfügbarer verifizierter Bildquelle ab.

## Quellenbilder und direkte Links · 04.10.2026, 11:28 MESZ

- Erweiterung auf Nutzerwunsch: Quellen- und Kartenlink sind direkt in der Ideenkarte erreichbar, mit 44-pt-Tippflächen und expliziten Accessibility-Labels. Ohne Quelle bleibt die Kartensuche anhand Name/Adresse erreichbar; Koordinaten werden nur mitgegeben, wenn bestätigt.
- Einzelrefresh liest Webseiten-OG/Twitter-Bildmetadaten sowie JSON-LD image aus ortsbezogenen Typen wie Museum/LocalBusiness/Restaurant. WebSite/Organization-Logos werden nicht als Ortsbild verwendet. Quellenbilder bleiben als linkPreview mit Herkunft unterscheidbar; persönliche und verifizierte vorhandene Fotos werden nicht durch den Quellenfallback überschrieben. Leere Ortsfotoantwort ersetzt die Quellenvorschau nicht durch eine Karte.
- Reale Quelle für Speculum: https://prague.eu/en/objevujte/speculum-alchemiae-mirror-of-alchemy-zrcadlo-alchymie/ liefert HTTP200 und og:image=https://cdn.praguecitytourism.city/2024/12/09123341/alchemi-fb-2.jpg. Bild HEAD HTTP200, image/jpeg, 284000 Bytes. Die alte Museumsquelle war im Webabruf nicht erreichbar; alte unveränderte Seed-Kopien werden auf die Stadtseite migriert, auch wenn Koordinaten bereits gespeichert sind. Geänderte persönliche Werte bleiben erhalten.
- /tmp/album-source-links.xcresult: 20 Tests bestanden, 0 Fehler, 0 ausgelassen. Enthält 18 Unit-Regressionen und zwei UI-Prüfungen. Live-UI-Test liest echte Stadtseitenmetadaten und lädt das echte Remote-Foto; nur der alternative Ortsfoto-Backendpfad wird für diesen Beleg leer injiziert. Zweiter UI-Test erzwingt keine Quellthumbnail-Metadaten und belegt den Kartenfallback. Quellen- und Kartenknopf sind hittable.
- Screenshot aus echtem Simulator: QA/one-hour-screenshots/speculum-source-photo.png. Kein bloßer Screenshot-Entwurf und keine fest eingebaute Bilddatei.
- Erster Testbuild scheiterte an zwei fehlenden Raw-String-Abschlusszeichen in neuen Parsertests. Korrigiert, neuer Testbuild erfolgreich; signierter Gerätebuild ebenfalls erfolgreich: /tmp/album-source-links-build.log und /tmp/album-source-links-device.log. git diff --check bestanden.
- Geräteinstallation weiterhin offen: iPhone15Pro unavailable. Aktueller installierbarer Build /tmp/album-hour-device-build/Build/Products/Debug-iphoneos/Album.app, noch nicht auf dem iPhone aktualisiert. Kein Commit/Push.
- Live-Quellenfoto-Test ist opt-in ALBUM_LIVE_SOURCE_PHOTO=1, damit normale UI-Läufe nicht von externen Webseiten abhängig sind. Allgemeine Bildgarantie für blockierte/social/loginpflichtige Seiten wird nicht behauptet.
