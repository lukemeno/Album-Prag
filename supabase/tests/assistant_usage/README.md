# Tests für die Assistenten-Limits

- `00_auth_stub.sql` + `10_behavior_test.sql`: lokal gegen ein leeres Postgres 17 (ohne Supabase), Stub für `auth`.
- Am 21.10.2026 zusätzlich auf einem echten Supabase-Testprojekt (`prag-album-test-welle1`) geprüft:
  13 Verhaltensprüfungen (Reservieren, Duplikat, Abrechnung, Rückbuchung, hängende Reservierung,
  Solo-Kontingent, Stunden-/Monatslimit, Not-Aus, Betragsprüfung, Status aus Tabelle, service_role-Pflicht)
  und sechs REST-Angriffe mit dem öffentlichen Schlüssel (Limits lesen/ändern, Preise ändern,
  Zähler zurücksetzen, RPCs direkt) → alle HTTP 401 / 42501.
- Vor dem Live-Rollout: Live-Funktionen hatten dieselbe MD5 wie `202610030001_assistant_usage.sql`.
  Reihenfolge: erst Migration `202610210001`, dann Edge Function `assistant-chat` deployen.
