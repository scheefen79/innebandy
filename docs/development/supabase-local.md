# Lokal Supabase-utveckling

Projektet använder Supabase CLI och Docker för en reproducerbar lokal databas. Migrationer ligger i `supabase/migrations/`, testdata i `supabase/seed.sql` och pgTAP-tester i `supabase/tests/database/`.

## Start och verifiering

```bash
pnpm db:start
pnpm db:reset
pnpm db:test
pnpm db:lint
```

Hämta de publika lokala värdena med `pnpm exec supabase status` och lägg URL samt publishable key i en ignorerad `.env.local`:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<LOKAL_PUBLISHABLE_KEY>
```

Stoppa miljön när den inte används:

```bash
pnpm db:stop
```

`db:reset` återskapar den lokala databasen, kör alla migrationer och laddar exempeldata. Kommandot ska endast användas mot den lokala Supabase-miljön.

## Koppla de tre tränarna till laget

Skapa först tränarnas tre konton via Supabase Auth. Hämta sedan deras UUID:n från Auth-vyn eller med följande fråga i SQL Editor:

```sql
select id, email
from auth.users
order by created_at;
```

Lägg därefter till medlemskapen med tränarnas riktiga UUID:n. Kör inte exempelkoden förrän platshållarna har ersatts:

```sql
insert into public.team_members (team_id, user_id, role)
values
  ('10000000-0000-4000-8000-000000000001', '<TRAINARE_1_UUID>', 'coach'),
  ('10000000-0000-4000-8000-000000000001', '<TRAINARE_2_UUID>', 'coach'),
  ('10000000-0000-4000-8000-000000000001', '<TRAINARE_3_UUID>', 'coach');
```

Vanliga autentiserade användare har avsiktligt inte rätt att ändra `team_members`. Initial koppling görs därför av projektägaren i SQL Editor eller genom en kontrollerad serveradministrativ process. Lägg aldrig service role-nyckeln i webbläsarkod eller i Git.

## Exempeldata

Seed-filen innehåller endast syntetiska namn: ett lag, en säsong och tre exempelspelare på nivå 1–3. Riktiga spelarnamn eller tränaruppgifter ska inte läggas i repot.
