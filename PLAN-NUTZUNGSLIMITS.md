# Plan: Assistenten-Nutzung fair begrenzen · Entwurf 21.10.2026

Status 21.10.2026: **Welle 1 lokal umgesetzt** (Migration `202610210001_assistant_usage_hardening.sql`, Edge Function, Tests), aber **nicht auf Live-Supabase angewendet und nicht deployt**. Reihenfolge beim Ausrollen: erst Migration, dann Function. Statt Pflicht-`trip_id` gibt es ein Solo-Kontingent (20 Anfragen/Monat), weil nicht geteilte Alben keine `trip_id` senden. Wellen 2–4 offen. Auth-, Abrechnungs- und Sicherheitslogik ändern wir erst nach ausdrücklicher Freigabe je Welle.

## 1. Ist-Stand (im Code geprüft)

**Was schon richtig ist:**
- Limits liegen **nur auf dem Server**. `assistant_reserve_usage` / `assistant_reconcile_usage` / `assistant_usage_status` sind `security definer`, nur für `service_role` ausführbar; die drei Usage-Tabellen sind für `anon` und `authenticated` komplett gesperrt (`supabase/migrations/202610030001_assistant_usage.sql:30-35, 200-205`).
- Ablauf: Reservieren (0,05 USD) → Anbieter aufrufen → tatsächliche Kosten verbuchen (`supabase/functions/assistant-chat/index.ts:180-202`). Gleichzeitige Anfragen sind per `FOR UPDATE` serialisiert, doppelte `request_id` wird abgewiesen.
- Kosten werden aus den Token-Zahlen des Anbieters plus **0,01 USD je Websuche** berechnet (`_shared/assistant_validation.ts:427-436`); max. 2 Websuchen, max. 2.000 Ausgabe-Tokens je Anfrage.

**Das Chris-Raroque-Problem** (laut deiner Beschreibung: Nutzer konnten ihr Credit-Limit selbst ändern) entsteht, wenn Limit oder Guthaben in einer Zeile stehen, die der Client per RLS selbst schreiben darf. **Das ist hier nicht der Fall**: Es gibt keine client-beschreibbare Spalte für Limit, Tarif oder Guthaben. Den konkreten Fall von Chris habe ich nicht nachrecherchiert.

**Lücken, die bei vielen Nutzern relevant werden:**

| # | Lücke | Beleg | Folge |
|---|---|---|---|
| L1 | Kontingent hängt am **anonymen** Supabase-Nutzer | `AssistantService.swift:35` `signInAnonymously()` | App neu installieren / Session löschen = neues Kontingent (Sybil) |
| L2 | `trip_id` ist optional, ohne Reise entfällt jede Mitgliedschaftsprüfung | `_shared/assistant_membership.ts` `if (!request.trip_id) return;` | Mit dem öffentlichen Anon-Key per Skript nutzbar, ohne die App |
| L3 | Ein **globaler** Topf von 9 USD/Monat für alle | Migration Zeile 53 | Ein Missbraucher leert den Topf → Assistent für **alle** aus |
| L4 | Limits und Preise fest im Code (SQL-Konstanten, `0.10/0.50` USD je Mio. Tokens) | Migration 53-55, 191; Validation 435 | Modellwechsel über `OPENAI_MODEL` ohne Preisanpassung verfälscht die Abrechnung; jede Limitänderung braucht Migration |
| L5 | Nutzerlimit zählt **Anfragen**, nicht Kosten | Migration 97 | Seit Web-Recherche Standard ist (Commit `d60c732`), kostet eine Anfrage grob 20× mehr (≈0,02 statt ≈0,001 USD, geschätzt aus den Konstanten im Code) |
| L6 | Fehlgeschlagene Anfrage bleibt voll verbucht; abgestürzte Funktion hinterlässt dauerhaft `reserved` | Migration 149-151 | Nutzer verliert Kontingent ohne Antwort; Topf schrumpft schleichend |

## 2. Zielbild (Prinzipien)

1. **Server ist die einzige Wahrheit** für Tarif, Guthaben und Verbrauch. Der Client zeigt nur an, was der Server meldet.
2. **Credits statt Anfragen**: 1 Credit ≈ Kosten einer einfachen Anfrage; Web-Recherche kostet mehr Credits. Verbrauch = tatsächliche Kosten.
3. **Stabile Identität** für volles Kontingent (Sign in with Apple); anonym nur ein kleines Probe-Kontingent.
4. **Mehrere Schutzschichten**: pro Nutzer, pro Reise, pro Stunde, globaler Not-Aus, Budget-Alarm beim Anbieter.
5. **Bezahlte Stufen nur über verifizierte App-Store-Transaktionen** (App Store Server Notifications V2 an eine Edge Function). Nie ein Flag, das die App setzt.

## 3. Datenmodell (Vorschlag)

| Tabelle | Inhalt | Schreibrechte |
|---|---|---|
| `assistant_plans` | `plan_id`, `monthly_credits`, `hourly_requests`, `web_search` | nur Service/Admin; Limits ändern ohne Migration |
| `assistant_entitlements` | `user_id`, `plan_id`, `source` (free/app_store/grant), `expires_at`, `original_transaction_id` | nur Webhook/Service |
| `assistant_credit_ledger` | append-only: `user_id`, `trip_id`, `delta`, `reason`, `request_id` | nur Service; Guthaben = Summe |
| `assistant_model_prices` | Preis je Modell (Input, Output, Websuche) | nur Service |

Bestehende Reservierungslogik bleibt im Kern (sie ist solide) und liest Limits künftig aus `assistant_plans`/`assistant_entitlements` statt aus Konstanten.

## 4. Identität und Missbrauch

- **Sofort:** Assistent nur mit `trip_id` und Mitgliedschaft (L2 schließen). Kleinster Schritt mit größter Wirkung.
- **Probe vs. voll:** anonym z. B. 10 Credits/Monat; nach **Sign in with Apple** volles Kontingent. Supabase kann die anonyme Identität mit Apple verknüpfen, die `user_id` (und damit Reisen) bleibt erhalten.
- **App Attest** (DeviceCheck): Die Edge Function akzeptiert nur Anfragen echter App-Installationen; DeviceCheck-Bits merken „Probe schon genutzt" über Neuinstallationen hinweg.
- **Globaler Topf aufteilen:** Not-Aus-Schwelle und Alarm bei 50/80/100 %; zahlende Nutzer bekommen eigenen Spielraum, damit Gratis-Missbrauch sie nicht blockiert.

## 5. Tarife (Beispiel, Annahmen markiert)

Kostenschätzung je Anfrage aus den Code-Konstanten (vor dem Festlegen mit echten Anbieterpreisen prüfen): ohne Web ≈ 0,001 USD, mit 2 Websuchen ≈ 0,021 USD. **Die Websuche dominiert die Kosten.**

Empfehlung: **Kontingent pro Reise als Gruppen-Topf** plus kleines persönliches Probe-Kontingent. Das passt zum Produkt (eine Gruppe plant eine Reise) und macht Sybil per Neuinstallation wertlos. Bezahlt wird über einen einmaligen **„Reise-Pass"** (In-App-Kauf), der den Topf dieser Reise auffüllt. Ein Abo passt schlecht zu saisonaler Nutzung. Die genauen Zahlen (Credits, Preis) legen wir fest, wenn echte Nutzungsdaten aus W1 vorliegen.

## 6. Oberfläche

- Im Assistenten: „Noch 24 Fragen in dieser Reise". Hinweis ab 20 % Rest, klare Meldung bei 0 mit Weg (Reise-Pass, Monatsbeginn).
- Web-Recherche bleibt umschaltbar; Hinweis, dass sie mehr Credits braucht.

## 7. Umsetzung in Wellen (je eine Freigabe)

| Welle | Inhalt | Risiko |
|---|---|---|
| **W1** Härten (ohne Bezahlen) | `trip_id` Pflicht; Limits/Preise in Tabellen; Credits statt Anfragen; Rückbuchung bei Fehlern; Aufräumen hängender Reservierungen; Alarm/Not-Aus | Migration auf Live-Supabase → vorher Backup, Test auf Branch-DB |
| **W2** Identität | Sign in with Apple + Verknüpfung der anonymen Identität; Probe-Kontingent; App Attest | Auth-Änderung, Bestandsnutzer behalten ihre Reisen |
| **W3** Bezahlen | StoreKit 2 + App Store Server Notifications V2 → `assistant_entitlements`; Reise-Pass | Abrechnung, App-Review |
| **W4** Betrieb | Übersicht für dich (Kosten, Top-Nutzer, Alarme), Freigaben für Tester | gering |

## 8. Prüfung (E2E, Fehlerfälle zuerst)

Wie es scheitern kann, und wie wir es belegen:
- Client schreibt direkt in Usage/Entitlement/Ledger mit Anon- oder User-Token → muss abgewiesen werden.
- Gefälschter Tarif im Request-Body → wird ignoriert.
- 20 parallele Anfragen am Limit → nie mehr als erlaubt verbucht.
- Neuinstallation (neuer anonymer Nutzer) → nur Probe-Kontingent, Reise-Topf unverändert.
- Webhook mit ungültiger Signatur oder wiederholter Transaktion → keine Gutschrift.
- Rückerstattung durch Apple → Gutschrift wird zurückgenommen.
- Anbieterfehler/Timeout → Credits zurück; Monatswechsel → korrekt neu.

## 9. Offene Entscheidungen für dich

1. Bezahlmodell: Reise-Pass (Empfehlung) oder Abo?
2. Ist Sign in with Apple für das volle Kontingent in Ordnung?
3. Wie groß darf der Gratis-Anteil pro Monat insgesamt sein (heute 9 USD global)?
