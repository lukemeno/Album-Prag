# Album auf zwei iPhones – ohne bezahlten Apple Developer Account

Stand 04.10.2026, Branch `claude/ready-to-land` (baut auf `design/album-visual-refresh` auf).

## Das Wichtigste vorab

- Ihr braucht **einen Mac mit Xcode** und **beide iPhones per Kabel**. Ohne Mac lässt sich die App nicht installieren, auch nicht in Prag.
- Eine kostenlose Apple-ID reicht (in Xcode heißt das „Personal Team“). Eine Installation läuft **7 Tage**. Wer am 4. oder 5. Oktober installiert, kommt ohne Erneuern durch die ganze Reise bis zum 9. Oktober.
- Deine Partnerin braucht **keine** eigene Apple-ID in Xcode. Ihr iPhone wird am selben Mac mit deiner Apple-ID installiert.
- Läuft die App ab, startet sie nicht mehr. **Nicht löschen**, sondern nur neu aufspielen: Die Daten bleiben erhalten.

## Was in diesem Branch neu ist

Diese Änderungen konnte ich in der Cloud ohne Xcode weder bauen noch testen. Bitte zuerst bauen und kurz prüfen (siehe Prüfliste unten).

1. **Fotos in Ideenkarte, Ortsdetail und Vollbild**
   - Diese großen Ansichten luden Wikimedia-Fotos in 1600 px Breite. Wikimedia liefert aber nur feste Breiten aus (120, 250, 330, 500, 960, 1280, 1920), andere enden mit HTTP 400. Das steht auch in `PROGRESS.md`.
   - Folge: Kleine Vorschaubilder funktionierten, große zeigten „Foto nicht verfügbar“ oder nur die Karte.
   - Jetzt laden große Fotos 1280 px. Das gilt auch für ältere, schon gespeicherte Bilder ohne Anbieterangabe.
   - Dateien: `Album/Design.swift`, `Album/Models.swift`, Test in `AlbumTests/DayPlanTests.swift`.
2. **Fotos bei wackligem Netz:** Schlägt ein Foto fehl, versucht die App es nach 1 und nach 3 Sekunden noch zweimal. Vorher blieb es sofort bei „Foto nicht verfügbar“. Datei: `Album/Design.swift`.
3. **Server, optional:** Die Bildsuche fragt Wikimedia jetzt direkt nach 1280 px statt 1600 px (`supabase/functions/_shared/wikimedia_photos.ts`). Der App-Fix funktioniert auch ohne diese Änderung. Wer sie live haben will: `supabase functions deploy place-photo`.
4. **Einladung ohne antippbaren Link**
   - Der Einladungslink hat die Form `album://join/…`. Messenger machen solche Links oft nicht antippbar.
   - Unter **Teilen** gibt es jetzt **„Link kopieren“**.
   - Auf dem anderen iPhone gibt es **„Einladung bekommen?“** mit Feld und **„Album beitreten“**. Der Link wird auch dann erkannt, wenn er mitten in einer weitergeleiteten Nachricht steht.
   - Datei: `Album/AlbumSettings.swift`.

## Schritt für Schritt

### 1. Mac vorbereiten (einmalig, ca. 10 Minuten)
1. Xcode öffnen, unter **Xcode → Settings → Accounts** mit deiner Apple-ID anmelden.
2. Im Terminal:
   ```sh
   cd Album-Prag
   git fetch origin
   git checkout claude/ready-to-land
   xcodegen generate   # nur nötig, wenn project.yml geändert wurde; schadet nicht
   open Album.xcodeproj
   ```
3. **Product → Build** (⌘B). Wenn der Build fehlschlägt, schick mir oder ChatGPT die Fehlermeldung. Notfalls `git checkout design/album-visual-refresh`: Das ist der letzte geprüfte Stand.
4. Unter **Signing & Capabilities**, bei den Targets **Album** und **AlbumShare**, ist das Team `X7K385PZ68` eingetragen. Das sollte dein Personal Team sein, denn damit wurde schon auf deinem iPhone installiert. Falls Xcode etwas anderes meldet: dort dein Team wählen.

### 2. Dein iPhone
1. Per Kabel anschließen, entsperren, „Diesem Computer vertrauen“.
2. Auf dem iPhone den Entwicklermodus einschalten: **Einstellungen → Datenschutz & Sicherheit → Entwicklermodus → An**. Danach startet das iPhone neu.
3. In Xcode oben das iPhone als Ziel wählen und auf **Run** (▶) klicken.
4. Beim ersten Mal auf dem iPhone: **Einstellungen → Allgemein → VPN & Geräteverwaltung → deine Apple-ID → Vertrauen**. Dann die App öffnen.

### 3. iPhone deiner Partnerin
Dieselben Schritte wie bei Abschnitt 2, am selben Mac. Xcode registriert das iPhone automatisch in deinem Personal Team.

### 4. Album teilen
1. Auf **deinem** iPhone: **Reise → Einladen** (Personensymbol oben) → **Einladung erstellen** → **Einladung senden**.
2. Wenn der Link drüben nicht antippbar ist: Auf deinem iPhone **„Link kopieren“** tippen und per Nachricht schicken. Deine Partnerin kopiert ihn und fügt ihn bei sich unter **Einladen → „Einladung bekommen?“** ein, dann **„Album beitreten“**.
3. Prüfen: Eine Idee auf dem einen iPhone einwerfen. Sie sollte nach kurzer Zeit auf dem anderen erscheinen. Herunterziehen auf „Reise“ gleicht sofort ab.

### 5. Optional: Erneuern ohne Kabel
In Xcode unter **Window → Devices and Simulators** bei jedem iPhone **„Connect via network“** einschalten. Danach genügt es, wenn Mac und iPhone im selben WLAN sind, und ihr klickt einfach wieder auf Run.

## Prüfliste nach dem Bauen (ca. 5 Minuten)

- [ ] **Ideen:** Ideenkarten mit Wikimedia-Foto zeigen das Foto und nicht „Foto nicht verfügbar“.
- [ ] **Karte → Ort antippen:** Das große Foto im Ortsdetail lädt.
- [ ] **Foto antippen:** Das Vollbild lädt.
- [ ] **Flugmodus kurz an, dann wieder aus:** Fotos laden nach wenigen Sekunden von selbst.
- [ ] **Teilen:** „Link kopieren“ erscheint unter „Einladung senden“. Auf dem zweiten iPhone erscheint „Einladung bekommen?“, solange es noch nicht verbunden ist.
- [ ] **Unit-Tests:** `⌘U` oder nur `DayPlanTests`. Neu ist der Test `testLargeWikimediaPhotosUseAnAllowedWidth`.

## Typische Meldungen und was hilft

| Meldung | Lösung |
|---|---|
| „Developer Mode disabled“ | Entwicklermodus am iPhone einschalten (Schritt 2.2). |
| „Untrusted Developer“ / App öffnet nicht | VPN & Geräteverwaltung → Vertrauen (Schritt 2.4). |
| „Failed to register bundle identifier“ | In `project.yml` `bundleIdPrefix` und beide `PRODUCT_BUNDLE_IDENTIFIER` auf ein eigenes Präfix ändern, z. B. `de.deinname.album` und `de.deinname.album.share`. Die App-Group `group.de.privatealbum.prague` (in `project.yml` und beiden `.entitlements`) genauso anpassen. Dann `xcodegen generate`. |
| „Maximum number of apps for free development profiles“ | Eine andere selbst installierte App vom iPhone löschen. Kostenlose Konten erlauben nur wenige gleichzeitig. |
| App startet nach einer Woche nicht mehr | Normal beim kostenlosen Konto: einfach erneut auf Run klicken. Nicht löschen. |
| iPhone in Xcode „nicht verfügbar“ | Entsperren, Kabel neu stecken, „Vertrauen“ bestätigen. |

## Später, falls das Erneuern nervt

Mit dem Apple Developer Program (99 € pro Jahr) gilt eine Installation 1 Jahr, und ihr könnt über TestFlight ohne Mac installieren.
