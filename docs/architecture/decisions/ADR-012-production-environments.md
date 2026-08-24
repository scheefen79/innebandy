# ADR-012: produktionsmiljöer och releasegräns

- Status: Godkänd
- Godkänd: 2026-08-24
- Datum: 2026-08-24

## Kontext

Appen är byggd för tre tränare och har ännu ingen skarp miljö. Produktionssättning kräver Supabase, Vercel och en serverhemlighet med stor behörighet. En full stagingmiljö minskar viss releaserisk men ökar kostnad, konfiguration och drift för en liten pilot.

## Beslut

Piloten använder två nivåer:

1. lokal utvecklings- och testmiljö
2. en skarp Supabase- och Vercel Production-miljö kopplad till `main`

Vercel Preview får publika konfigurationsvärden endast om den pekar mot en separat icke-produktionsdatabas. Produktionsvärdet för `SUPABASE_SERVICE_ROLE_KEY` får aldrig exponeras för Preview. Databasschema släpps manuellt från versionerade migrationer efter dry-run och separat godkännande; frontenddeploy får inte automatiskt migrera databasen.

Utvecklingsseed används aldrig i produktion. Initialt lag, säsong och medlemskap skapas genom ett separat idempotent bootstrapsteg med bekräftade värden.

Piloten startar på Supabase Free i North EU (Stockholm), `eu-north-1`, och Vercel Hobby med Vercels genererade domän. Piloten är bekräftat icke-kommersiell. Projektägaren accepterar Free-planens risk för paus vid låg aktivitet samt avsaknad av automatisk backup/PITR.

## Alternativ

### Separat staging från start

Ger en mer produktionslik testyta men dubblerar initial miljö- och datakonfiguration. Införs när fler personer utvecklar, releaser sker ofta eller piloten får högre konsekvens vid fel.

### Vercel Preview mot produktionsdatabasen

Avvisas. Branchkod skulle kunna få skarp service-role-åtkomst och skriva i verklig data innan merge.

### Automatisk databasmigrering vid varje deploy

Avvisas i pilotfasen. Frontend och databas har olika rollbackegenskaper och produktionsmigrationer ska ha en synlig dry-run och stoppunkt.

## Konsekvenser

- Releasen innehåller tydliga separata steg för databas och frontend.
- Pilotens första deploy kräver mer manuell kontroll men får en liten och begriplig driftmodell.
- Previewmiljöer kan inte testa servermutationer utan en separat Supabase-miljö.
- Stagingbeslutet omprövas när team, releasetakt eller risknivå växer.
- Supabase-planen omprövas om pausrisken, backupbehovet eller pilotens tillgänglighetskrav ökar.
- Vercel-planen omprövas före varje kommersiell användning.
