# ADR-021: automatiserad verifiering och databasrelease

- Status: Accepterad
- Datum: 2026-09-20

## Kontext

ADR-012 satte en medvetet manuell releasegräns för piloten. Sedan dess har flödet gått i skarp
drift och två saker har gått fel på riktigt:

1. En pull request mergades innan en rättning hann pushas, så `main` hade under några minuter kod
   som anropade en databasfunktion som inte fanns i produktion. Det räddades bara av att ingen
   tränare råkade använda funktionen under tiden.
2. En mergad migration låg okörd mot produktion i tre dygn. Ingenting varnade, och den upptäcktes
   av en slump.

Samtidigt saknas automatiska kontroller helt. Det finns inga GitHub Actions, `main` är oskyddad,
och de gröna bockarna på en pull request kommer enbart från Vercels bygge. `pnpm release:preflight`
är tänkt som grinden men är frivillig, och den har varit röd på ett falsklarm utan att någon
märkt det. Verifieringsrutorna i pull request-mallen fylls i för hand och kan inte kontrolleras.

ADR-012:s villkor för att ompröva staging — *"när fler personer utvecklar, releaser sker ofta
eller piloten får högre konsekvens vid fel"* — är därmed uppfyllt av det tredje ledet.

## Beslut

- **Verifiering automatiseras och blir en grind.** `.github/workflows/verify.yml` kör repots
  guards, lint, typkontroll, enhetstester, bygge och hela databassviten inklusive pgTAP och de sju
  samtidighetsskripten. `main` skyddas så att en pull request krävs och båda jobben måste vara
  gröna före merge.
- **Databasmigrering automatiseras genom Supabases GitHub-integration.** Migrationer i
  `supabase/migrations/` körs vid merge till `main`. Integrationen rör bara migrationer; API-,
  Auth- och seedkonfiguration ignoreras, så `seed.sql` kan inte nå produktion.
- **Stoppunkten flyttas från deploy till granskning.** ADR-012 krävde en synlig dry-run och en
  stoppunkt före produktionsmigrering. Den kontrollen sker nu i pull requesten, där
  migrationsfilen läses i sin helhet av en människa och av den oberoende granskaren, i stället för
  som ett godkännandeklick vid deploy.
- **Ordningen mellan app och databas blir en regel, inte en spärr.** Supabase och Vercel startar
  på samma merge, så appen kan vara någon minut före databasen. Additiva migrationer är ofarliga i
  det glappet. Destruktiva migrationer körs i en egen merge efter att koden som slutat använda det
  borttagna är live.
- **Previewmiljön får en egen databas.** Ett andra Supabase-projekt på Free-planen, som Vercels
  Preview pekar på. Det är inte en utökning av ADR-012 utan ett uppfyllande av dess krav att
  previews aldrig får skarp åtkomst.
- **Egen migreringspipeline väljs bort.** Ett eget arbetsflöde med godkännandesteg och deploy hook
  hade gett exakt ordning och en stoppunkt, men till priset av flera hundra rader arbetsflöde,
  tre hemligheter och en avstängd Vercel-integration. Supabases nativa väg ger merparten av nyttan
  utan något av det underhållet.

`pnpm db:reset` är enligt autonomikontraktet en stoppunkt lokalt eftersom den raderar Auth-konton.
Den regeln avser en utvecklares maskin. I en efemär CI-runner finns ingen användardata och
kommandot är ofarligt.

## Konsekvenser

- En migration kan inte längre glömmas bort, och `main` kan inte längre mergas med röda tester.
- Ingen automatisk stoppunkt finns kvar före produktionsmigrering. En destruktiv migration som
  passerar granskningen körs oövervakat. Supabase Free saknar backup och PITR, så runbookens krav
  på manuell dataexport före riskfyllda ändringar gäller fortsatt och skärps snarare av det här
  beslutet.
- Verifieringsrutorna i pull request-mallen blir kontrollerbara i stället för självrapporterade.
- Arbetsflödet får aldrig hemligheter. Databastesterna körs mot en efemär lokal Supabase i
  runnern, aldrig mot ett skarpt projekt, och `SUPABASE_SERVICE_ROLE_KEY` finns inte i CI.
- Beslutet omprövas om releasetakten ökar så att den kvarvarande kapplöpningen mellan app och
  databas börjar märkas, eller om laget går till Supabase Pro, där branching ger en databas per
  pull request och gör preview-projektet överflödigt.

## Alternativ

### Egen GitHub Actions-pipeline med godkännandesteg

Ger exakt ordning och en synlig dry-run före ett godkännandeklick. Avvisas eftersom underhållet
inte står i proportion till nyttan för ett lag med tre tränare, och eftersom ett godkännandeklick
i praktiken blir en gummistämpel jämfört med att läsa migrationen i granskningen.

### Supabase Branching

Ger en riktig databas per pull request och automatisk synk av miljövariabler till Vercel.
Avvisas eftersom det kräver Pro för 25 dollar i månaden plus timkostnad per branch, vilket inte är
motiverat för en icke-kommersiell pilot. Omprövas om laget ändå går till Pro.

### Behålla manuell migrering och bara lägga till en varning

Ger lägst risk men löser inte grundproblemet: steget glöms fortfarande bort, och varningen kommer
efter att koden redan är live.

### Låta ADR-012 stå oförändrad

Avvisas. Beslutet fattades innan piloten var i drift och innan de två incidenterna. Att låta det
stå hade betytt att den dokumenterade processen och den faktiska avviker, vilket är sämre än att
ompröva beslutet uttryckligen.
