# Aktuell milstolpe: Implementation 20 – matchplanering i två faser

Planen godkändes 2026-10-05 och arbetet återupptogs efter användarens paus. Lokal implementation är genomförd. Full Supabase-verifiering återstår före integration.

- Arbetsgren: `codex/two-phase-match-planning`, bas `5fb65bc`.
- [Utvecklingsplan, avbockning och återupptagningspunkt](implementation-20-two-phase-match-planning.md).
- [ADR-023: grundplan, externa kallelser och låst deltagande](../architecture/decisions/ADR-023-two-phase-match-planning.md).

## Status

- [x] Produktval, godkänd plan och arbetsgren.
- [x] Databas, atomiska åtgärder, fryst grundplan och erbjudandebaserad rättvisa.
- [x] Matchveckans server- och UI-flöden integrerade.
- [x] Historikkomplettering och spelaröversikt med sökning och sortering.
- [x] ADR-023, nio berörda äldre ADR:er, produktspecifikation och arkitektur uppdaterade.
- [x] 194 automatiska applikationstester och 451 databasassertions på isolerad PostgreSQL via adapter.
- [x] Mobilresa 390 px och desktopjämförelse med syntetiska data.
- [x] Första oberoende granskningen; tre P2 rättade.
- [x] Slutlig uppföljande granskning; inga nya P0–P2-fynd.
- [ ] Full Supabase/pgTAP/db lint och samtidighet i två PostgreSQL-sessioner.
- [x] Separat godkännande för commit och push av arbetsgrenen.
- [ ] Separat godkännande för PR och produktionsändringar.

Det nya samtidighetstestet ingår i befintlig CI och release-preflight. Docker/Supabase-runtime saknas på denna maskin; den återstående grinden får inte ersättas med adapterresultatet. Ingen verklig matchdata har ändrats.

---

# Föregående milstolpe: Implementation 19 – flera byten och extra inhoppare i ett steg

## Mål

Tränaren kan byta flera ordinarie spelare och lägga till flera extra inhoppare i ett atomiskt steg.

Scope och acceptanskriterier finns i `docs/planning/implementation-19-batch-squad-adjustments.md`. Beslutet finns i ADR-022.

## Leverabler

- [x] Atomiska databasfunktioner `create_manual_regular_adjustments` och `add_extra_substitutes` med negativa tester.
- [x] Server-, route- och UI-lager för flera byten (kryssrutor och par) och flera extra (kryssrutor).
- [x] Spec, öppna frågor och ADR:er uppdaterade.
- [x] Lint, typkontroll, Vitest, bygge, databastester och db lint passerar.
- [ ] Lokal mobil användarresa med ett syntetiskt Auth-konto.
- [ ] Oberoende skrivskyddad granskning.

## Föregående milstolpe: Implementation 18 – extra spelare vid genomförd match

## Mål

När en match genomförs ska tränaren kunna registrera exakt vilka som deltog, inklusive en eller flera extra spelare som inte lades till före matchstart.

Scope och acceptanskriterier finns i `docs/planning/implementation-18-completion-extra-players.md`. Det atomiska beslutet finns i ADR-010.

## Leverabler

- [x] Genomförandevyn kan välja flera nya extra spelare.
- [x] Befintliga ordinarie och extra deltagare kan fortfarande markeras som spelade eller frånvarande.
- [x] Nya extra rader, deltagande och matchstatus sparas atomiskt.
- [x] Ordinarie rättvisa och extrastatistik förblir separata.
- [x] Automatiska kontroller, databasens negativa tester och oberoende granskning är genomförda.
- [ ] Lokal mobil användarresa är genomförd med ett syntetiskt Auth-konto.

## Föregående milstolpe: Implementation 17 – automatiserad verifiering och databasrelease

## Mål

Ingen ändring ska kunna nå `main` utan att testerna bevisligen körts, och ingen migration ska kunna glömmas bort.

Scope och acceptanskriterier finns i `docs/planning/implementation-17-release-automation.md`. Beslutet finns i ADR-021, och den operativa ordningen i `docs/deployment/production-runbook.md`.

## Leverabler

- [x] Verifierande arbetsflöde som kör guards, lint, typkontroll, tester, bygge och hela databassviten på varje pull request.
- [x] Guarderna har en enda definition som både lokal preflight och CI använder.
- [x] `pnpm release:preflight` går igenom.
- [x] `main` skyddad med krav på pull request och på båda checkarna.
- [x] Supabases GitHub-integration påslagen så att migrationer körs vid merge. Fungerar först bevisad vid nästa merge som innehåller en migration.
- [x] Preview-databas kopplad. Projekt `uwmmxbovzhvgvdfyqzzd` i `eu-north-1` med samtliga migrationer och syntetisk seed; Vercels Preview-variabler pekar dit.

## Föregående milstolpe: Implementation 10 – produktionssättning och pilot

## Mål

Gör den verifierade applikationen säker och reproducerbar att använda för de tre tränarna med verkliga data i en skarp Supabase- och Vercelmiljö.

Detaljerat föreslaget scope och acceptanskriterier finns i `docs/planning/implementation-10-production-pilot.md`. Miljöstrategin finns i ADR-012 och den operativa ordningen i `docs/deployment/production-runbook.md`.

## Leverabler

- [x] Implementation 10 och ADR-012 granskade och godkända.
- [x] Produktionscheck och releasekommandon dokumenterade och verifierade.
- [x] Skarp Supabase-miljö skapad och länkad.
- [x] Migrationer applicerade utan utvecklingsseed.
- [ ] Lag, aktiv säsong och tre tränarkonton skapade kontrollerat.
- [ ] Vercel Production konfigurerad med rätt miljövariabler.
- [ ] Skarp smoke test och mobil acceptans genomförda.
- [ ] Återställningsväg och ägarskap dokumenterade.
- [ ] Oberoende skrivskyddad granskning genomförd.

## Stoppunkter

- Skapande av molnprojekt, länkning, `db push`, Auth-konton, Vercel-konfiguration och deployment kräver uttryckligt godkännande.
- Riktiga tränaruppgifter och säsongsdata måste bekräftas innan bootstrap.
- `supabase db reset --linked` och `db push --include-seed` får aldrig köras mot produktion.

## Milstolpen är klar när

- de tre tränarna kan logga in i den skarpa tjänsten
- verkliga spelare och matcher kan administreras utan exempeldata
- samtliga centrala användarresor fungerar på mobil
- produktionshemligheter endast finns i godkända secret stores
- RLS, loggar, backup och rollback har kontrollerats
- piloten har en namngiven ägare och en enkel incidentväg
