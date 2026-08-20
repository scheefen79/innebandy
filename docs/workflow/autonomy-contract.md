# Autonomikontrakt för utvecklingsarbetet

## Syfte

Codex ska kunna genomföra en godkänd implementation från plan till integrationsklart resultat utan att Anders behöver verifiera varje delsteg. Kvalitetskontrollen flyttas till reproducerbara tester, dokumenterade acceptanskriterier och oberoende agentgranskning.

## När mandatet aktiveras

Mandatet aktiveras när Anders uttryckligen godkänner en implementationsplan eller ber Codex att bygga ett tydligt avgränsat scope.

Godkännandet omfattar hela det dokumenterade scopet, inklusive normala följdändringar som krävs för att acceptanskriterierna ska kunna uppfyllas.

## Codex får göra utan nya delgodkännanden

- skapa och byta till en arbetsgren
- läsa projektfiler och lokal dokumentation
- ändra kod, tester, migrationer och dokumentation inom scopet
- göra små, reversibla teknik- och UI-val som följer produktspecifikation och ADR:er
- köra lint, typkontroll, tester, build och andra icke-destruktiva lokala kontroller
- applicera nya migrationer inkrementellt i den lokala utvecklingsdatabasen när befintliga lokala data bevaras
- genomföra lokal UI- och tillgänglighetsverifiering när verktygen tillåter det
- ge en separat agent ett strikt skrivskyddat granskningsuppdrag
- bedöma och rätta verifierade P0-, P1- och P2-fynd inom samma scope
- upprepa verifiering och granskning tills ändringen är integrationsklar

## Codex ska stoppa och fråga

- när ett odokumenterat produktval materiellt ändrar användarbeteende eller rättviseregler
- när datamodellen har flera rimliga alternativ med olika framtida konsekvenser som inte täcks av planen
- när arbetet kräver väsentligt utökat scope
- före lokal databasreset som raderar Auth-konton eller annan användardata
- före destruktiva eller svåråterställbara operationer
- före commit, push, pull request, merge eller deployment
- före externa skrivningar, produktionsändringar, kostnader eller hantering av riktiga personuppgifter
- när användarens egna ändringar inte säkert kan separeras från uppgiften

## Kvalitetsgrind

Anders behöver inte manuellt verifiera varje implementation för att den ska kunna presenteras som integrationsklar. Codex måste i stället:

1. verifiera planens acceptanskriterier
2. köra relevanta automatiska kontroller
3. verifiera RLS negativt när dataåtkomst berörs
4. genomföra lokal användarresa när UI berörs, eller redovisa exakt varför den inte kunde utföras
5. låta en oberoende skrivskyddad agent granska hela diffen
6. rätta eller uttryckligen motivera samtliga P2-fynd; P0 och P1 får inte vara öppna
7. redovisa kvarvarande osäkerheter och rekommendera `committa` eller `avvakta`

## Integrationsgrind

När kvalitetsgrinden är passerad rekommenderar Codex commit och push. Anders ger då ett kort godkännande, exempelvis `committa och pusha`.

Detta är en avsiktlig mänsklig kontrollpunkt: lokalt genomförande är delegerat, men publicering till GitHub och andra externa miljöer är det inte.

## Hur mandatet kan utökas senare

Om flödet fungerar stabilt kan kontraktet senare ändras så att även commit till arbetsgren sker automatiskt efter ren granskning. Push, merge och deployment bör fortsatt vara separata kontrollpunkter eftersom de ändrar delat eller externt tillstånd.
