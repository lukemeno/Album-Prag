# Album auf zwei iPhones – ohne bezahlten Apple Developer Account

Stand 05.10.2026, Branch **`claude/motion-flow`**. Er enthält alles aus `claude/ready-to-land` (Fotos, Einladung) und dazu Bewegung, Haptik und Abläufe, siehe `Design/MOTION-FLOW-PLAN.md`. Diesen Branch installieren.

## Das Wichtigste vorab

- Ihr braucht **einen Mac mit Xcode** und **beide iPhones per Kabel**. Ohne Mac lässt sich die App nicht installieren, auch nicht in Prag.
- Eine kostenlose Apple-ID reicht (in Xcode heißt das „Personal Team“). Eine Installation läuft **7 Tage**. Wer am 4. oder 5. Oktober installiert, kommt ohne Erneuern durch die ganze Reise bis zum 9. Oktober.
- Deine Partnerin braucht **keine** eigene Apple-ID in Xcode. Ihr iPhone wird am selben Mac mit deiner Apple-ID installiert.
- Läuft die App ab, startet sie nicht mehr. **Nicht löschen**, sondern nur neu aufspielen: Die Daten bleiben erhalten.

## Was in diesem Branch neu ist

**In der Cloud gebaut und getestet (05.10.2026):** GitHub Actions auf macOS 26 mit Xcode 26.6 (`.github/workflows/ios-build.yml`).
- App und Share Extension bauen für Simulator und iPhone ohne Fehler.
- Unit-Tests auf iPhone 17 Pro / iOS 26.5: 162 ausgeführt, 0 Fehler, 4 übersprungen (optionale Live-Supabase- und PDF-Tests).
- Accessibility-Audits auf Reise, Ideen, Karte und Editor: ohne Fund.
- 37 Screenshots (hell, dunkel, quer, große Schrift) einzeln durchgesehen.
- Noch rot sind nur UI-Tests, die Apples Fotos-Auswahl und das Teilen-Blatt fernsteuern, und ein Test, der einen vorbereiteten Datenstand vom Mac braucht. Alle scheitern auch auf dem Ausgangsstand.

Jeder Push auf `claude/**` baut automatisch neu. Bewegung und Haptik lassen sich nur auf dem echten iPhone prüfen: dafür ist die Prüfliste unten.

1. **Fotos in Ideenkarte, Ortsdetail und Vollbild**
   - Diese großen Ansichten luden Wikimedia-Fotos in 1600 px Breite. Wikimedia liefert aber nur feste Breiten aus (120, 250, 330, 500, 960, 1280, 1920), andere enden mit HTTP 400. Das steht auch in `PROGRESS.md`.
   - Folge: Kleine Vorschaubilder funktionierten, große zeigten „Foto nicht verfügbar“ oder nur die Karte.
   - Jetzt laden große Fotos 1280 px. Das gilt auch für ältere, schon gespeicherte Bilder ohne Anbieterangabe.
   - Dateien: `Album/Design.swift`, `Album/Models.swift`, Test in `AlbumTests/DayPlanTests.swift`.
2. **Fotos bei wackligem Netz:** Schlägt ein Foto fehl, versucht die App es nach 1 und nach 3 Sekunden noch zweimal. Vorher blieb es sofort bei „Foto nicht verfügbar“. Datei: `Album/Design.swift`.
3. **TikTok-Vorschaubilder:** TikTok signiert die Bildadressen nur für etwa ein bis zwei Tage. Danach zeigten Ideen aus TikTok nur noch einen Platzhalter, auch auf dem zweiten iPhone. Jetzt holt die App dann ein frisches Vorschaubild, zuerst über TikTok (oEmbed), sonst von der Seite selbst, und merkt es sich, solange sie läuft. Datei: `Album/Design.swift`.
4. **Server, optional:** Die Bildsuche fragt Wikimedia jetzt direkt nach 1280 px statt 1600 px (`supabase/functions/_shared/wikimedia_photos.ts`). Der App-Fix funktioniert auch ohne diese Änderung. Wer sie live haben will: `supabase functions deploy place-photo`.
5. **Einladung ohne antippbaren Link**
   - Der Einladungslink hat die Form `album://join/…`. Messenger machen solche Links oft nicht antippbar.
   - Unter **Teilen** gibt es jetzt **„Link kopieren“**.
   - Auf dem anderen iPhone gibt es **„Einladung bekommen?“** mit Feld und **„Album beitreten“**. Der Link wird auch dann erkannt, wenn er mitten in einer weitergeleiteten Nachricht steht.
   - Datei: `Album/AlbumSettings.swift`.
6. **Ideen entscheiden:** Nach rechts wischen oder „Ja“ zählt sofort, ohne Speichern. Die Idee liegt danach auf der Karte. Fehlt ihr noch ein Kartenort, erscheint daneben „Ort ergänzen“. Datei: `Album/InboxView.swift`.

## Schritt für Schritt

### 1. Mac vorbereiten (einmalig, ca. 10 Minuten)
1. Xcode öffnen, unter **Xcode → Settings → Accounts** mit deiner Apple-ID anmelden.
2. Im Terminal:
   ```sh
   cd Album-Prag
   git fetch origin
   git checkout claude/motion-flow
   xcodegen generate   # nur nötig, wenn project.yml geändert wurde; schadet nicht
   open Album.xcodeproj
   ```
3. **Product → Build** (⌘B). Wenn der Build fehlschlägt, schick mir oder ChatGPT die Fehlermeldung. Notfalls `git checkout claude/ready-to-land` (nur Foto- und Einladungs-Fixes) oder `design/album-visual-refresh` (Stand vor dem Flug).
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
- [ ] **Ältere TikTok-Idee** (vor ein paar Tagen eingeworfen): Das Vorschaubild erscheint nach kurzer Zeit wieder.
- [ ] **Flugmodus kurz an, dann wieder aus:** Fotos laden nach wenigen Sekunden von selbst.
- [ ] **Teilen:** „Link kopieren“ erscheint unter „Einladung senden“. Auf dem zweiten iPhone erscheint „Einladung bekommen?“, solange es noch nicht verbunden ist.
- [ ] **Ideen:** Eine Idee nach rechts wischen. Sie gilt sofort als „Ja“, ohne Speichern.
- [ ] **Unit-Tests:** `⌘U` oder nur `DayPlanTests`. Neu ist der Test `testLargeWikimediaPhotosUseAnAllowedWidth`.
- [ ] Danach die Prüfliste für Bewegung und Haptik in `Design/MOTION-FLOW-PLAN.md`.

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
