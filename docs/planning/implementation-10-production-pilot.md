# Implementation 10: produktionssättning och pilot

- Status: Godkänd
- Godkänd: 2026-08-24

## Syfte

Ta appen från lokalt verifierad MVP till en liten, säker pilot för tre tränare. Implementation 10 ska göra releasen reproducerbar och revisionsbar utan att blanda utvecklingsseed, produktionshemligheter eller manuella schemaändringar.

## Rekommenderad miljömodell

- Lokal Supabase och Next.js används för utveckling och automatiska tester.
- Ett skarpt Supabase-projekt används av piloten.
- En Vercel Production-miljö deployas från `main`.
- Vercel Preview får inte produktionsvärdet för `SUPABASE_SERVICE_ROLE_KEY`.
- Separat stagingmiljö införs först när releasetakten, antalet utvecklare eller pilotens risknivå motiverar den.

## Bekräftade pilotbeslut

- Supabase använder Free-planen.
- Vercel använder projektägarens befintliga Hobby-konto.
- Vercels genererade `vercel.app`-domän räcker för piloten.
- Aktiv säsong heter `Höstterminen 2026` och gäller 2026-08-01 till 2026-12-31.
- Tre tränarkonton är bekräftade men deras e-postadresser lagras inte i Git.
- Projektägaren är pilotägare och ansvarar initialt för kontoåterställning.
- Supabase-region är North EU (Stockholm), `eu-north-1`.
- Piloten är uttryckligen icke-kommersiell och ryms därför inom Vercel Hobby-villkoren. Om användningen ändras behöver planen omprövas.

## Föreslagen omfattning

### Förbered repot

- Uppdatera README till aktuell funktionalitet och produktionsstatus.
- Dokumentera exakta preflight-, migrations-, bootstrap-, deploy-, smoke- och rollbacksteg.
- Lägg till en parameteriserad bootstrapmall för lag, säsong och tränarmedlemskap. Mallen får inte innehålla riktiga e-postadresser, UUID:n, lösenord eller spelarnamn.
- Verifiera att `.env*`, `.vercel/`, Supabase-token och service-role-nyckel är ignorerade.
- Dokumentera att `supabase/seed.sql` endast är syntetisk lokal data.

### Produktionsbeslut före externa skrivningar

Supabase-organisation och projektref väljs vid projektskapandet. Region, säsongsdatum och pilotens icke-kommersiella användning är bekräftade.

### Supabase

- Skapa projektet i vald region och skydda administratörskontot med MFA.
- Länka CLI till exakt projektref och verifiera målet innan varje fjärrskrivning.
- Kör lokal full verifiering och därefter `supabase db push --dry-run`.
- Applicera endast versionerade migrationer med `supabase db push`; använd aldrig `--include-seed` i produktion.
- Kör bootstrap av lag och säsong som en tydlig, idempotent transaktion efter att värdena bekräftats.
- Skapa de tre Auth-kontona administrativt, koppla dem till laget och stäng därefter publik signup.
- E-postbekräftelse och SMTP kan avvaktas under den manuellt skapade trepersonspiloten. Kontoåterställning hanteras då av pilotägaren via Supabase Dashboard och dokumenteras som en begränsning.
- Kontrollera Security Advisor, RLS på alla app-tabeller och att `anon`, outsider och inaktiv medlem nekas.
- Acceptera och dokumentera att Free-projekt kan pausas vid låg aktivitet och saknar betald backup/PITR. Pilotägaren bevakar pausmeddelanden och tar en manuell dataexport före riskfyllda produktionsändringar.

### Vercel

- Importera GitHub-repot och använd `main` som Production Branch.
- Lägg endast följande värden i Vercels krypterade Production-miljö:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY`
- Lägg inte service-role-nyckeln i Preview eller Development via Vercel.
- Kör första produktiondeployen först efter migrering, bootstrap och verifierad Auth-konfiguration.
- Använd Vercels genererade domän för piloten om inte egen domän uttryckligen beslutas.

### Verklig data

- Importera inte den lokala XLSX-filen eller utvecklingsseed automatiskt till produktion.
- Lägg in spelare via appens spelarflöde så att normal validering, rotationsordning och auditbar mutation används.
- Lägg in matcher via appen efter att spelartruppen har kontrollerats.
- Generera och spara den första fördelningen uttryckligen från appen.
- En tränare gör inmatningen och en annan tränare verifierar antal, nivåer och matchdatum innan piloten öppnas.

### Smoke test och pilotstart

- Testa login separat med vart och ett av de tre kontona.
- Verifiera Översikt, Spelare, Matcher, fördelning, manuellt byte, extra inhopp och genomförd match.
- Kontrollera 390 px, tangentbord, konsol- och nätverksfel.
- Verifiera att en obehörig användare inte kan läsa lagets data.
- Kontrollera Vercel-loggar och Supabase-loggar efter testen.
- Dokumentera känd MVP-begränsning: matchredigering/radering och valbar startmatch för omfördelning återstår.

### Rollback och drift

- Frontend återställs genom att återpromota senast verifierade Vercel-deployment.
- Databasmigrationer är forward-only efter att verklig data finns; produktion får aldrig återställas med `db reset`.
- Före framtida riskfyllda migrationer tas en verifierad manuell export. Automatisk backup/PITR kräver senare uppgradering från Free.
- Vid behörighetsincident inaktiveras berört `team_members`-medlemskap och sessioner återkallas.
- Pilotägaren ansvarar för konton, datakvalitet och första incidentbedömning.

## Ingår inte

- ny produktfunktionalitet
- generell onboarding eller självregistrering
- automatiserad import från XLSX
- CI/CD som automatiskt migrerar produktionsdatabasen
- separat stagingmiljö
- egen domän, SMTP eller självservice för lösenordsåterställning om det inte beslutas separat

## Acceptanskriterier

- Produktionsmigrationen är förhandsgranskad och appliceras utan seeddata.
- Inga hemligheter eller riktiga personuppgifter finns i Git.
- Endast `main` och Vercel Production har servernyckeln.
- Tre namngivna tränarkonton har aktivt medlemskap i rätt lag.
- Publik signup är avstängd efter kontoskapandet.
- En outsider och en inaktiv medlem nekas i skarp verifiering.
- Alla centrala pilotresor fungerar med verkliga data på mobil.
- Rollback, kontoåterställning, pilotägare och kända begränsningar är dokumenterade.

## Verifiering

1. Lokal full svit: diff-check, lint, typkontroll, Vitest, pgTAP, databaslint, samtidighetstester och build.
2. Secret scan av tracked filer och verifiering av `.gitignore`.
3. `supabase db push --dry-run` mot bekräftad projektref.
4. Efter uttryckligt godkännande: migration, bootstrap och negativa skarpa behörighetskontroller.
5. Vercel build och produktiondeploy från `main`.
6. Smoke test med alla tre tränarkonton och verkliga data.
7. Mobil kontroll vid 390 px och oberoende skrivskyddad releasegranskning.

## Definition av klar

Implementation 10 är klar när de tre tränarna kan använda den skarpa tjänsten med verkliga data, en obehörig användare fortfarande nekas och projektet kan återställas eller felsökas utan odokumenterade manuella steg.
