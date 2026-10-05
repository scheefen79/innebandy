# Implementation 20 – matchplanering i två faser

- Status: Plan godkänd 2026-10-05. Återupptagen efter användarens paus; lokal implementation och verifiering genomförda. Full Supabase-grind återstår före integration.
- Arbetsgren: `codex/two-phase-match-planning`.
- Bas: `main`, commit `5fb65bc`.
- Beslut: ADR-023.
- Användaren har efter slutrapporten godkänt commit och push av arbetsgrenen. PR och produktionsändringar kräver separat godkännande. Verkliga matchdata har inte ändrats.

## Mål och godkänd omfattning

Generatorn skapar en rättvis grundplan för hela säsongen. Sanna registrerar externt skickade kallelser och svar, hanterar återbud och fyller på flexibelt. Efter matchen registrerar tränaren faktisk medverkan och låser deltagandet. Spelaröversikten ska ersätta behovet av ett separat spreadsheet för denna hantering.

1. **Grundplan:** normalt tio ordinarie platser per match; nivå används endast för balans. Rättvisan utgår från erbjudna ordinarie platser plus framtida planerade platser. Väntetid och fast rotation avgör lika kandidater.
2. **Matchvecka:** startas uttryckligen och fryser grundplanen. Status per spelare: ej kallad, inväntar svar, tackat ja, tackat nej eller kallelse indragen. Flera ändringar sparas atomiskt. Ingen omedelbar ersättare krävs vid återbud.
3. **Kapacitet:** ja och inväntar svar reserverar tillsammans högst tio platser, inklusive extra. Färre deltagare tillåts.
4. **Rättvisa:** en ordinarie kallelse räknas först när den markeras som skickad. Nej och indragen kallelse raderar inte erbjudandet. Återaktivering räknas inte igen. Inställda matcher räknas inte.
5. **Extra:** inkallade utanför grundplanen är extra. Endast faktiskt deltagande ökar extraräknaren. Ranking: genomförda extra, erbjudna ordinarie, senaste extra, fast rotation. Nej/indragen kallelse måste återaktiveras uttryckligen.
6. **Deltagande:** truppen kan ändras även efter matchstart fram till låsning. Ett till tio faktiska deltagare kan låsas efter start; noll hanteras som inställd match. Obesvarade kallelser måste hanteras före låsning.
7. **Rättning:** coach kan rätta låst deltagande med obligatorisk anledning och bevarad historik. Ingen automatisk ändring av framtida grundplan.
8. **Översikt:** erbjudna ordinarie, spelade ordinarie, spelade extra, totalt spelade och framtida planerade. Sökning och sortering; mobilkort och jämförbar desktopvy. Kandidatval visar relevanta antal direkt.
9. **Äldre matcher:** befintliga uttagningar föreslås men är inte bevis för skickade kallelser. Manuell komplettering och bekräftelse krävs innan nya generatorn används. Matchveckans hantering kan användas under tiden.
10. **Behörighet:** coach hanterar flöden och individuell statistik. Viewer behåller begränsad matchvy. Ingen extern integration eller utskick ingår.

## Avbockningsbar utvecklingsplan

En ruta kryssas först när steget är verifierat, inte bara när kod finns.

### Steg 1 – beslut och grund

- [x] Godkänd plan och produktval sammanställda.
- [x] Befintliga fördelnings-, rättvise-, behörighets- och persistenskontrakt genomgångna.
- [x] Separat arbetsgren skapad från synkad `main`.
- [x] ADR-023 dokumenterar godkända beslut och tekniskt upplägg.
- [x] Berörda äldre ADR:er uppdaterade med ersatta beslut.
- [x] Produktspecifikation, öppna frågor och arkitekturöversikt uppdaterade.

### Steg 2 – databas och rättvisa

- [x] Migration för matchfas, fryst grundplan, kallelser, deltagande och revisionshistorik färdigställd.
- [x] Atomiska mutationer för start, svar, historik, låsning, rättning och inställning verifierade.
- [x] Högst tio reserverade platser och faktiska deltagare upprätthålls i databasen.
- [x] Rättviseunderlag räknar erbjudanden och bevarar påbörjade matchveckor.
- [x] Befintliga mutationsvägar kan inte kringgå frysning, låsning eller kapacitet.
- [x] Läsmodeller för match, spelarprofil, statistik och översikt ger konsekventa värden.
- [x] Negativa behörighetstester, atomicitet, stale och återförsök passerar.

### Steg 3 – server och matchveckans UI

- [x] Validerade typer och serverflöden med coachkontroll färdigställda och testade.
- [x] Starta matchveckan och bevara grundplanen.
- [x] Registrera flera kallelser och svar, återbud utan ersättare och explicit återaktivering.
- [x] Visa ja, väntande svar, lediga platser och rekommenderade extra.
- [x] Registrera deltagande, låsa och rätta med anledning och synlig historik.
- [x] Matchdetalj och matchlista använder det nya flödet och visar aktuell status.
- [x] Loading, empty, error, stale och populated states fungerar.

### Steg 4 – historik och spelaröversikt

- [x] Tillgänglig väg för att komplettera och bekräfta äldre matchkallelser.
- [x] Generatorns historikspärr visas begripligt med länk till komplettering.
- [x] Spelaröversikt med samtliga överenskomna antal, sökning och sortering.
- [x] Desktopjämförelse och mobilkort utan horisontell scroll.
- [x] Spelarkort, fördelningsöversikt och extra-ranking följer samma statistikdefinitioner.

### Steg 5 – verifiering och överlämning

- [x] Deterministiska domän- och featuretester samt routetester passerar.
- [x] Fulla migrationer och databastester passerar på isolerad PostgreSQL-motor med assertionsadapter (451 kontroller).
- [ ] Samma svit passerar i full lokal Supabase med riktig pgTAP och `db:lint`.
- [ ] Full Supabase/RLS och verklig samtidighet verifierade. Miljöbegränsningen och utförda negativa RLS-tester är dokumenterade nedan.
- [x] Lint, typkontroll, bygge, repository guards och `git diff --check` passerar.
- [x] Lokal användarresa på 390 px med syntetiska data, tangentbord och tillgänglighet verifierad.
- [x] Första oberoende skrivskyddade granskningen av hela diffen inklusive nya ospårade filer.
- [x] Uppföljande granskning av rättningar och slutlig dokumentation; inga nya konkreta P0–P2-fynd.
- [x] Verifierade P0–P2-fynd rättade eller P2 uttryckligen accepterade med motivering.
- [x] Slutlig lokal verifiering redovisad. Integration avvaktar full Supabase-grind.
- [x] Användarens separata godkännande för commit och push av arbetsgrenen.
- [ ] Separat godkännande för PR och produktionsändringar.

## Acceptansscenario

Tio spelare i grundplanen kallas ordinarie. Sex tackar nej. Fem andra kallas som extra och tackar ja. Nio spelare deltar. Resultatet ska vara tio erbjudna ordinarie platser, fyra spelade ordinarie och fem genomförda extra, utan att återbud förstör grundplanen eller tvingar fram parvisa byten.

Verifiera dessutom elfte reserverade platsen, färre än tio deltagare, obesvarade kallelser, indragen kallelse, återaktivering utan dubbelräkning, inställd match, historikkomplettering, omfördelning med frysta matcher, sena deltagare, fel lag/roll, samtidiga sparningar, identisk retry och rättning av låst deltagande.

## Utförd verifiering och kvarvarande integration

- Lint, typkontroll, produktionsbygge, repository guards, shellsyntax för samtidighetstestet och `git diff --check` passerar.
- Vitest: 51 filer, 194 tester passerar. Domän-, RPC-, route- och UI-renderingstester ingår.
- Hela migrationskedjan och samtliga 16 SQL-testfiler: 451 assertions, noll fel på isolerad PGlite/PostgreSQL med lokal assertionsadapter. Detta är inte en körning av riktig pgTAP eller full Supabase.
- Acceptansscenariot, kapacitet, atomicitet, stale, identiska återförsök, rättning och negativa behörighetsfall passerar i databastester. Inaktiva historiska spelare, oinbjudna äldre extra och markering av ofullständig erbjudandehistorik täcks också.
- Lokal webbläsarresa på 390 × 844 px med syntetisk Auth-adapter och isolerad PostgreSQL: start, tio skickade ordinarie, sex nej, fyra ordinarie ja, fem extra ja, nio deltagare låsta, rättning till åtta med anledning och synlig revisionshistorik. Spelaröversiktens uppdaterade antal, sökning, sortering och tom sökning kontrollerade.
- Matchveckan och spelaröversikten: dokumentbredd 390 vid viewport 390, alla synliga formulärfält har etiketter. Tab-navigering och Enter för låsning kontrollerade. Desktop 1280 px visar jämförbar tabell utan horisontell scroll. Loading och historikens bekräftade tomläge observerade. Detta är grundläggande kontroll, inte full skärmläsarrevision.
- Oberoende första granskning: tre P2, inga P0/P1. Alla tre rättade och regressionstäckta: äldre extra blir ej kallade, inaktiva historiska spelare kan väljas, ofullständig erbjudandehistorik märks i UI.
- Uppföljande oberoende slutgranskning av hela diffen mot `5fb65bc`, inklusive ospårade implementationsfiler: de tre rättningarna bekräftade, inga nya konkreta P0–P2-fynd. Granskaren körde också 194 tester, typkontroll, diffkontroll och shellsyntax.
- Nytt `db:test:workflow-concurrency` ingår i CI och release-preflight. Två verkliga PostgreSQL-sessioner ska verifiera identisk retry och svar som konkurrerar med deltagandelåsning. Skriptets shellsyntax är verifierad; körning återstår.

**Kvar före integration:** Docker/Supabase-runtime saknas lokalt. Kör full `db:reset`, `db:test`, `db:lint`, samtliga samtidighetstester inklusive det nya workflow-testet och övrig release-preflight i disponibel lokal Supabase/CI. Kontrollera också autentisering med riktig Supabase, som inte verifieras av den syntetiska UI-adaptern. Ingen migration har applicerats på verklig Supabase eller verkliga matchdata.

**Återuppta här:** återanvänd arbetsgrenen och läs denna status. Slutför ovanstående integrationskontroller, rätta verifierade fynd, uppdatera checklistan och redovisa resultat inför integration och separat godkännande för PR/produktion. Commit och push av arbetsgrenen är godkända. Börja inte om eller återställ de lokala ändringarna.

## Lokal miljö och bevarade filer

- Tillfällig PostgreSQL-verifiering finns i `/private/tmp/innebandy-db-verification/`. Testmotorn ersätter inte full Supabase. UI-testservrarna stoppas efter verifiering.
- Befintliga ospårade `.DS_Store`, `.pnpm-store/` och `node_modules.fore-aterinstallation-2026-10-02/` är bevarade. Arkivet undantas nu från lint, typkontroll och testupptäckt.
- Befintliga beroenden används med `pnpm --config.verify-deps-before-run=false <script>` för att undvika oavsiktlig återinstallation.
- Vid slutgranskningen var ändringen lokal och nya filer ospårade; granskningen omfattade även dessa. Användaren har därefter godkänt commit och push av hela ändringen.

## CI-uppföljning: rollval i databastest 10

Första riktiga Supabase/pgTAP-körningen för `9b1f83a` körde 451 tester. Ett fel: test 10 i SQL-fil 16 försökte nå frysnings-triggern som `service_role`, men rollen saknar direkt UPDATE på `match_players` och nekades korrekt med 42501 före triggern.

Testet separerar nu skrivbehörighet från frysningsskydd: tabellägaren verifierar `FROZEN_MATCH_PLAN`, och en ny assertion verifierar att `service_role` nekas direkt UPDATE. Inga produktionsbehörigheter, migrationer eller affärsregler ändras. Den tillfälliga PostgreSQL-adapterns breda efterhandsgrant till service-role har tagits bort; samma migrationsgrants används nu och 452 assertions passerar lokalt. Ny riktig CI-körning återstår för denna rättning.
