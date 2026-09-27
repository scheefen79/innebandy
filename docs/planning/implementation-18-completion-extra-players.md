# Implementation 18: extra spelare vid matchcompletion

- Status: Lokalt implementerad; mobil användarresa återstår
- Beslutad: 2026-09-27

## Syfte

Låt tränaren registrera det faktiska deltagandet efter en spelad match även när en eller flera extra spelare inte hann läggas till i den planerade uttagningen.

## Beslutad omfattning

- Genomförandevyn visar befintliga ordinarie och registrerade extra spelare som tidigare.
- Tränaren kan välja noll, en eller flera aktiva spelare utan befintlig rad i matchen som nya extra deltagare.
- En ny extra deltagare sparas som `extra/manual/selected/played=true`.
- En redan registrerad extra spelare kan markeras som frånvarande och räknas då inte i extrastatistiken.
- Samtliga deltagandebeslut, nya extra rader och matchens status sparas i en transaktion.
- Matchens ordinarie target och ordinarie uttagningsrader ändras inte.
- Redigering efter att matchen har sparats som genomförd ingår inte; det kräver revisionsspår och ett separat produktbeslut.

## Acceptanskriterier

- Flera nya extra spelare kan väljas med tangentbord och på 390 px utan horisontell scroll.
- Endast aktiva spelare i samma lag och säsong, utan befintlig matchkoppling, kan läggas till.
- Manuellt borttagna, redan uttagna, inaktiva och främmande spelare nekas som nya extra deltagare.
- En ny extra rad måste ha `played=true`; frånvaro skapar inte en ny historikrad.
- Ett stale underlag eller ogiltig input lämnar match, deltagande och extra rader oförändrade.
- Identisk retry konvergerar även när completion skapade nya extra rader; en avvikande retry får inte skriva över resultatet.
- Genomförda extra spelare påverkar bara extrastatistik och aldrig ordinarie rättvisa.
- Coachbehörighet krävs i både serverlager och databas; viewer och anonyma användare nekas.

## Verifiering

1. Enhetstest av source-parsning, komplett deltagandeinput, flera extra spelare och ogiltiga dubbletter.
2. Routetest som visar att flera extra id:n skickas till server-only-gränsen och att överlappande id:n stoppas.
3. pgTAP för kandidatunderlag, atomisk insert, typ/status, historikseparation, ogiltiga extra spelare och retry.
4. `git diff --check`, lint, typkontroll, Vitest, bygge, databastester och db lint.
5. Lokal mobil användarresa för genomförande med flera extra spelare.
6. Oberoende skrivskyddad granskning av hela diffen mot `main`.
