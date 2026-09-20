# Aktuell milstolpe: Implementation 17 – automatiserad verifiering och databasrelease

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
