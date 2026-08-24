# Produktionsrunbook

Denna runbook är en checklista. Kommandon som skriver till Supabase, Vercel eller GitHub körs först efter uttryckligt godkännande och efter att målprojektet har verifierats.

## 1. Bekräfta produktionsvärden

- [ ] Supabase organisation och projektref; plan är Free och regionen är North EU (Stockholm), `eu-north-1`
- [x] befintligt Vercel Hobby-konto och Production Branch `main`
- [x] `Höstterminen 2026`: 2026-08-01 till 2026-12-31
- [x] tre tränarmejl bekräftade utanför Git
- [x] projektägaren ansvarar för pilot och kontoåterställning
- [x] Vercels genererade domän används i piloten
- [x] piloten är bekräftat icke-kommersiell enligt Vercel Hobby-villkoren

Skriv inte lösenord, tokens eller service-role-nycklar i denna fil.

## 2. Lokal releasekontroll

```bash
pnpm release:preflight
```

Preflighten kör kod-, databas-, samtidighets-, bootstrap-, build- och secret-kontroller lokalt. Den skriver inte till något fjärrsystem.

## 3. Supabase-migrering

```bash
pnpm exec supabase login
pnpm exec supabase link --project-ref <BEKRÄFTAD_PROJECT_REF>
pnpm exec supabase db push --dry-run
pnpm exec supabase db push
```

Kör aldrig följande mot produktion:

```text
supabase db reset --linked
supabase db push --include-seed
```

## 4. Bootstrap

1. Kopiera `supabase/bootstrap/01_team_and_season.sql.example` till en ignorerad temporär fil utanför repot, ersätt samtliga platshållare och kör den i Supabase SQL Editor.
2. Skapa tre användare i Supabase Auth.
3. Verifiera att exakt de tre bekräftade e-postadresserna finns i Auth. Kopiera inte lösenord eller användaruppgifter till repot.
4. Kopiera `supabase/bootstrap/02_coach_memberships.sql.example` till en ignorerad temporär fil, ersätt samtliga platshållare och kör den i SQL Editor.
5. Stäng `Allow new users to sign up`.
6. Kontrollera att varje tränare kan logga in och att outsider nekas.

Mallarna är transaktionella och idempotenta. De ska kunna köras om med exakt samma värden utan dubbletter. Lägg aldrig den ifyllda kopian i repot.

## 5. Vercel

Konfigurera endast Production med:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
SUPABASE_SERVICE_ROLE_KEY
```

Importera GitHub-repot, välj `main` som Production Branch och verifiera första builden innan domänen delas.

## 6. Verklig data och smoke test

1. Lägg in spelare via appen.
2. Dubbelkontrollera namn och nivå 1–3 med en andra tränare.
3. Lägg in matcher via appen.
4. Generera och spara första fördelningen.
5. Testa de centrala flödena och 390 px.
6. Kontrollera Vercel- och Supabase-loggar.

## 7. Rollback

- Frontend: återpromota senast verifierade Vercel-deployment.
- Behörighet: inaktivera berört medlemskap och återkalla sessioner.
- Databas: gör ingen destruktiv reset. Stoppa nya skrivningar, säkra backup och skapa en forward-fix.
- Supabase Free saknar automatisk backup/PITR. Ta därför en manuell dataexport före varje riskfylld produktionsändring och kontrollera att exporten går att läsa.
- Free-projekt kan pausas vid låg aktivitet. Pilotägaren bevakar Supabases varningsmejl och återstartar projektet vid behov.
