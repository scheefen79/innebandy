# ADR-002: Lagmedlemskap och Row Level Security

- Status: Accepterad
- Datum: 2026-08-13

## Kontext

Tre tränare ska använda appen. De behöver egna inloggningar men åtkomst till samma lag. MVP behöver ingen generell roll- eller medlemsadministration.

## Beslut

Varje tränare har ett eget Supabase Auth-konto. Tabellen `team_members` kopplar användare till lag:

```text
auth.users → team_members → teams
```

MVP använder endast rollen `coach`. De första tre medlemskapen skapas vid initial uppsättning. Ingen inbjudnings- eller medlemssida byggs i MVP.

RLS för lagägda tabeller tillåter åtkomst endast när den inloggade användaren har ett aktivt medlemskap i det berörda laget.

## Konsekvenser

- Tränarna behöver inte dela inloggningsuppgifter.
- Flera tränare kan arbeta med samma lag.
- Datamodellen klarar fler tränare senare utan att en ny behörighetsmodell krävs.
- RLS-policyer behöver negativa tester som visar att andra användare nekas åtkomst.

## Alternativ

- Ett gemensamt konto: avvisas av säkerhets- och spårbarhetsskäl.
- `owner_user_id` direkt på laget: avvisas eftersom tre tränare ska dela laget.
- Avancerad RBAC: avvisas som onödigt för MVP.

## Uppdatering

ADR-016 utökar medlemsmodellen med den begränsade läsrollen `viewer`. Beslutet om individuella konton, aktivt lagmedlemskap, ingen medlemsadministration och RLS som auktoritativ gräns är oförändrat. Formuleringen att MVP endast använder `coach` är därmed ersatt.
