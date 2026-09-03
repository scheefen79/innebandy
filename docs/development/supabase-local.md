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
SUPABASE_SERVICE_ROLE_KEY=<LOKAL_SERVICE_ROLE_KEY>
```

Service role-nyckeln används endast av Next.js-servern för den avgränsade atomiska sparfunktionen för uttagningar. Den får aldrig heta `NEXT_PUBLIC_*`, användas i webbläsarkod eller checkas in i Git. De lokala värdena visas av Supabase-statusen efter att miljön startats.

Stoppa miljön när den inte används:

```bash
pnpm db:stop
```

`db:reset` återskapar den lokala databasen, kör alla migrationer och laddar exempeldata, inklusive den syntetiska matchen. Kommandot ska endast användas mot den lokala Supabase-miljön. Det raderar även lokalt skapade Auth-konton, som därför behöver skapas och kopplas till laget igen efter en reset.

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

Vanliga autentiserade användare har avsiktligt inte rätt att ändra `team_members` direkt. Sedan Implementation 14 är det primära sättet att bjuda in, ändra roll för och inaktivera medlemmar adminvyn i appen (`/team`, coach-only) — den anropar Supabase Admin Auth och de coach-verifierade databasfunktionerna, inte tabellen direkt. SQL Editor-flödet ovan kvarstår som reservväg för den allra första kopplingen (innan någon coach finns) eller om adminvyn av någon anledning inte går att nå. Lägg aldrig service role-nyckeln i webbläsarkod eller i Git.

### Testa inbjudningsflödet lokalt

Lokal Supabase fångar utgående e-post i Mailpit (`pnpm exec supabase status` visar `MAILPIT_URL`, normalt `http://127.0.0.1:54324`) istället för att skicka riktiga mejl. Bjud in en testadress via adminvyn, öppna Mailpit och klicka länken i det mottagna mejlet för att komma till "Sätt ditt lösenord". Ingen custom SMTP-konfiguration behövs lokalt.

## Exempeldata

Seed-filen innehåller endast syntetiska namn: ett lag, en säsong, tre exempelspelare på nivå 1–3 och en kommande exempelmatch. Riktiga spelarnamn, motståndare, platser eller tränaruppgifter ska inte läggas i repot.
