# Zukunftsfeature: Social-Media-Trends am Reiseziel

Stand: 23.10.2026. Status: geparkt für eine spätere Version, ohne Termin. Nach ausdrücklicher Nutzerentscheidung kein Bestandteil und keine Voraussetzung der ersten App-Version. Noch nicht implementieren.

## Ziel und Nutzerablauf

Öffentliche Instagram- und TikTok-Beiträge sollen aktuell diskutierte Orte am Reiseziel sichtbar machen. In „Ideen → Entdecken“ erscheinen Vorschläge mit Interessenbezug, Originalquellen und Aktualisierungszeit. Nutzer übernehmen einzelne Orte bewusst als gemeinsame Idee; Abstimmung und Tagesplanung bleiben separate Schritte.

Die allgemeine Entdecken-Funktion ist inzwischen ausdrücklich für Version 1 geplant: Sehenswürdigkeiten, persönliche feste Interessen pro Reise und Einstieg unter Ideen. Details: PLAN-ENTDECKEN-V1.md. Social-Trends bleiben davon unabhängig zurückgestellt. Der vorhandene Import einzelner geteilter Links bleibt unabhängig.

## Technischer Ansatz für die spätere Planung

- Öffentliche Beiträge anhand von Reiseziel, lokalen Namensvarianten und Themen suchen. Konkrete Orte mit der vorhandenen Ortsauflösung prüfen; Creator-Herkunftsland ist kein Beleg für den Aufnahmeort.
- Quellen, Veröffentlichungs-/Erfassungszeit und verfügbare Kennzahlen festhalten. Wiederholte Beobachtungen, neue unabhängige Creator und zunehmende Interaktionen zur Trendbewertung verwenden; fehlende Werte bleiben unbekannt.
- Ergebnisse je Reiseziel im Backend gemeinsam aufbereiten und zwischenspeichern. Keine eigene kostenpflichtige Recherche bei jedem App-Aufruf.
- Ohne ausreichende Signale nur „Auf Social Media entdeckt“ anzeigen. Keine vollständige Plattform-Rangliste behaupten und alte virale Beiträge nicht als aktuelle Trends ausweisen.
- Ortsfotos aus der vorhandenen Bildsuche verwenden. Originalbeiträge zunächst verlinken; Einbettung/Weiteranzeige erst nach Klärung der jeweiligen Nutzungsrechte.

## Lokale Issue-Entwürfe

### ST-1 · Datenpilot und Anbieterentscheidung

**Ziel/Umfang:** Nach separater Freigabe eines Kostenlimits einen siebentägigen Pilot für Prag, Tokyo und Lissabon durchführen. Offizielle Zugänge erneut prüfen; Apify und Bright Data sind Prüfkandidaten, keine festgelegten oder aktivierten Anbieter.

**Akzeptanz:** Aktualität, korrekte Ortszuordnung, unabhängige Creator, zeitliche Entwicklung, regionale Lücken, Ausfälle und tatsächliche Kosten dokumentiert. Zugangsbedingungen, Datenspeicherung und Darstellungsrechte vor Produktbetrieb geklärt. Bei unzureichender Qualität bleibt das Feature geparkt.

**Abhängigkeiten/Prüfung:** Kostenobergrenze, Abfragetakt und Qualitätsgrenzen vor Pilotbeginn festlegen. Stichproben manuell gegen Originalbeiträge und reale Orte abgleichen, einschließlich mehrdeutiger, alter und werblicher Treffer. Kein automatischer Start des Piloten durch diesen Plan.

### ST-2 · Quellenanbindung und Trendaufbereitung

**Ziel/Umfang:** Nach erfolgreichem ST-1 austauschbare Datenanbindung, Zusammenführung gleicher Beiträge/Orte, zeitlicher Vergleich und belegte Empfehlungen bereitstellen.

**Akzeptanz:** Quellen und Datenlücken nachvollziehbar; geografisch unklare Treffer nicht automatisch empfehlen; Plattformwerte getrennt bewerten; Kostenlimit/Abschaltung wirksam. Ausfälle erzeugen keine erfundenen oder unmarkiert veralteten Trends.

**Abhängigkeiten/Prüfung:** Akzeptierter Pilot, Anbieter-/Rechteentscheidung und Betriebsbudget. Tests für Duplikate, falsche Ortsbelege, einzelne virale Altbeiträge, fehlende Kennzahlen, manipulierte Häufungen, Quellenausfall und Budgeterschöpfung.

### ST-3 · Empfehlungen in Entdecken integrieren

**Ziel/Umfang:** Geprüfte Vorschläge mit Interessenbezug, Quellen, Aktualität und bewusster Übernahme als Idee anzeigen.

**Akzeptanz:** Interessen änderbar; vorhandene Ideen nicht doppelt anlegen; kein automatisches Abstimmen oder Planen; verständliche Zustände bei fehlenden/veralteten Daten; barrierefreie Bedienung.

**Abhängigkeiten/Prüfung:** ST-2 und abgestimmter allgemeiner Entdecken-Ablauf. Persönliche/gemeinsame Interessen sowie Themen/Freitext bei Wiederaufnahme entscheiden. UI-Tests für Quellenöffnung, Übernahme, Duplikate, Fehler und Neustart; anschließend eigene Prüfung mit echten Daten.

## Recherchebasis und offene Entscheidungen

Offizielle Zugänge decken den gewünschten weltweiten lokalen Trendfeed nicht vollständig ab: TikTok Display bezieht sich auf Nutzerkonten, Research schließt kommerzielle Nutzer aus und Commercial Content fokussiert Werbung/kommerzielle Inhalte. Instagram bietet begrenzte Hashtag-Zugänge. Datenanbieter dokumentieren alternative Suchzugänge; Qualität, Konditionen und Rechte sind gesondert zu prüfen.

- [Meta Instagram API](https://www.postman.com/meta/instagram/documentation/6yqw8pt/instagram-api?entity=request-23987686-af579d08-121e-4897-8f45-5fd41ace49df)
- [TikTok Display](https://developers.tiktok.com/docs/en/display-api-overview), [Research FAQ](https://developers.tiktok.com/docs/en/research-api-faq), [Commercial Content](https://developers.tiktok.com/products/commercial-content-api)
- [Apify Instagram](https://apify.com/apify/instagram-scraper), [TikTok](https://apify.com/clockworks/tiktok-scraper), [Bright Data Instagram](https://brightdata.com/products/datasets/instagram/hashtags)

Bei Wiederaufnahme Quellen und Preise erneut verifizieren. Anbieter, Kostenlimit, Takt, Trend-Schwellen und Interessenumfang bleiben spätere Entscheidungen. Es wurden keine Linear-Issues angelegt, Anbieter aktiviert oder Erfassungsjobs eingerichtet.
