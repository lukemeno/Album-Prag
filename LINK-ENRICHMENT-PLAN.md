# Link-Vorschauen und Ortsvorschläge

Freigegeben am 03.10.2026: bestehende Sammlung anreichern, ohne API-Schlüssel oder Video-Download.

1. TikTok oEmbed mit HTML-/Apple-Metadaten-Fallback; öffentlich verfügbare Titel, Beschreibung und Bilder laden. Kurze Links auflösen, Loginseiten nicht als Inhalt übernehmen.
2. Fehlende Vorschauen beim Öffnen der Sammlung begrenzt nachladen, erneut abrufbar machen und Änderungen wie bisher synchronisieren. Vorhandene Notizen erhalten, asynchrone Ergebnisse gegen zwischenzeitliche Änderungen absichern.
3. Aus verfügbarem Text plausible benannte Orte ableiten und mit Apple Maps im Reisekontext prüfen. Vorschläge zeigen Namen und Adresse. Speichern nur nach Bestätigung im vorhandenen Ortseditor.
4. Parsing, fehlende Metadaten und Ortskandidaten deterministisch testen; Sammlung-Regressionsfälle prüfen, Gerätebuild erstellen und auf das verbundene iPhone 15 Pro installieren.

Grenzen: private/gesperrte Beiträge, abgelaufene Bildadressen, fehlende Plattformmetadaten. Keine Auswertung des gesprochenen oder eingeblendeten Videoinhalts. Keine Zusage vollständiger Ortserkennung.

Live-Stichprobe: Nutzer-TikTok /@cari_homeandabroad/video/7614843797150698774 liefert HTTP 200 mit ausführlicher Beschreibung und thumbnail_url.
