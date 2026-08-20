# Implementation 05: manuella justeringar av ordinarie lag

- Status: Godkänd
- Godkänd: 2026-08-20

## Syfte

Ge en behörig tränare möjlighet att flytta en ordinarie matchplats mellan två spelare utan att blanda in extra inhopp:

```text
Tränaren öppnar en planerad match
  → väljer Justera ordinarie lag
  → väljer en ordinarie uttagen spelare som ska stå över
  → väljer en aktiv spelare som ska läggas till
  → granskar och bekräftar bytet
  → hela bytet sparas atomiskt
  → matchen visar Manuellt borttagen och Manuellt tillagd
```

Tränaren ska även kunna återställa bytet. Då återgår de två platserna till automatisk status och fördelningsmotorn får åter bestämma dem vid nästa uttryckliga omfördelning.

## Beslutad omfattning

### Giltigt manuellt byte

- Matchen ska tillhöra lagets aktiva säsong, ha status `upcoming` och ligga i framtiden när skrivningen sker.
- Spelaren som tas bort ska ha en aktuell `regular/automatic/selected`-plats i matchen. En manuellt tillagd spelare kan inte kedjebyta i Implementation 05; det befintliga bytet återställs först.
- Spelaren som läggs till ska vara aktiv i samma lag och säsong.
- Den tillagda spelaren får inte redan vara ordinarie eller extra uttagen i matchen.
- Ett byte ersätter exakt en ordinarie plats med exakt en annan spelare. Matchens antal ordinarie uttagna förändras inte.
- Spelarnivå används inte när tränaren väljer det manuella bytet.

### Persistensmodell

Ett manuellt byte representeras av två ömsesidigt kopplade `match_players`-rader:

- borttagen spelare: `regular`, `manual`, `removed`, `played=false`
- tillagd spelare: `regular`, `manual`, `selected`, `played=false`
- båda raderna använder `replaced_player_id` för att peka på den andra spelaren

Den tidigare automatiska raden för den borttagna spelaren ersätts inom samma transaktion. Den tillagda manuella raden räknas som en ordinarie tilldelning.

Parintegriteten garanteras av en `DEFERRABLE INITIALLY DEFERRED` constraint-trigger som validerar tillståndet vid transaktionens slut. För varje `regular/manual`-rad ska exakt en ömsesidig motpart finnas i samma match, lag och säsong, med en annan spelare och motsatt `selection_status`. En ensam insert, update eller delete, en korskoppling eller flera rader som pekar på samma motpart ska därför underkännas vid commit. När båda raderna skapas eller tas bort i samma transaktion är slutläget giltigt.

### Återställning

- `Återställ manuellt byte` verkar på ett exakt identifierat, fortfarande giltigt par.
- De två manuella raderna tas bort atomiskt.
- Den tidigare borttagna spelaren återinförs som `regular`, `automatic`, `selected`, `played=false` för den aktuella matchen.
- Den tidigare borttagna spelaren måste fortfarande vara aktiv i samma lag och säsong. Annars stoppas återställningen med ett stabilt fel utan att paret förändras.
- Återställning förändrar inga andra matcher eller extra inhopp.
- Vid nästa uttryckliga omfördelning finns inget manuellt beslut kvar och motorn får välja fritt.

### Bevarande vid generering

- Implementation 04:s kanoniska underlag fortsätter skicka manuella `include`- och `exclude`-beslut till fördelningsmotorn.
- En ny generering får inte radera eller skriva över manuella bytesrader.
- Ett manuellt tillägg räknas som ordinarie, medan en manuell borttagning inte gör det.
- Extra uttagningar och genomförda extra inhopp påverkas inte.

### Atomik och stale-skydd

- Webbläsaren får inte mutera `match_players` direkt.
- Två server-only PostgreSQL-funktioner används: en för att skapa ett byte och en för att återställa ett byte.
- Funktionerna anropas endast genom skyddade Next.js-routes med samma server-only-klientmönster som ADR-007.
- Serverrouten verifierar sessionen. Databasfunktionen accepterar endast `service_role` och verifierar vidarebefordrat användar-id mot aktivt lagmedlemskap.
- Match, berörda uttagningsrader och spelare låses i stabil ordning innan validering och skrivning.
- Formuläret bär ett serverberäknat fingeravtryck av matchens aktuella ordinarie och extra uttagningar, matchstatus, starttid samt berörda spelares aktiva status.
- Om underlaget ändrats stoppas operationen med `STALE_SELECTION` utan partiell förändring.
- Upprepning av exakt samma redan genomförda operation ska returnera det aktuella resultatet utan dubbletter.

### Behörighet

- Endast aktiv lagmedlem får initiera byte eller återställning.
- `authenticated`, `anon`, outsider och inaktiv medlem får inte direkt anropa mutationsfunktionerna.
- Server-only-funktionerna verifierar att match och båda spelarna tillhör samma behöriga lag och aktiva säsong.
- Servernyckeln förblir isolerad till serverkod och får aldrig exponeras i klienten eller Git.

### Gränssnitt

- Matchdetaljen får `Justera ordinarie lag` för framtida planerade matcher med sparad uttagning.
- En enkel mobilvy visar automatiskt uttagna ordinarie spelare som kan bytas ut och aktiva valbara ersättare. Manuellt tillagda spelare hänvisas till återställning av sitt befintliga byte.
- Tränaren väljer först vem som ska stå över och sedan vem som ska läggas till.
- En sammanfattning visar `Ut: <spelare>` och `In: <spelare>` innan bekräftelse.
- Matchdetaljen märker raderna `Manuellt tillagd` och `Manuellt borttagen`.
- `Återställ manuellt byte` visas per manuellt par och kräver en tydlig bekräftelse.
- Loading, empty, error, stale, success och obehörig/not-found hanteras utan att tekniska id:n eller databasfel exponeras.

## Ingår inte

- extra inhoppare eller extrarekommendation
- markera match som genomförd eller inställd
- registrera faktisk närvaro
- flytta flera platser i en enda operation
- omfördela andra framtida matcher automatiskt efter ett byte
- ändra spelarnivå, match eller target
- manuellt lägga till en ordinarie plats utan att ta bort en annan

## Acceptanskriterier

### Domän och data

- Ett giltigt byte håller matchens ordinarie target oförändrat.
- Den tillagda spelaren räknas som ordinarie och den borttagna spelaren gör det inte.
- Manuella include/exclude-beslut överlever senare generering.
- Återställning återskapar exakt den tidigare automatiska platsen och tar bort hela det manuella paret.
- Dubbletter, själversättning, inaktiv spelare, manuellt utgående spelare, redan uttagen ersättare och extra uttagen ersättare stoppas.
- Återställning stoppas atomiskt om den tidigare borttagna spelaren inte längre är aktiv.

### Säkerhet och samtidighet

- Direkta mutationer och direkta RPC-anrop från `authenticated` och `anon` nekas.
- Serverrollen med outsider eller inaktivt vidarebefordrat användar-id nekas.
- Annat lag, annan säsong, genomförd/inställd match och passerad starttid nekas generiskt.
- Ändrat uttagningsunderlag mellan formulär och save ger `STALE_SELECTION` utan ändrade rader.
- Två samtidiga byten mot samma plats serialiseras; högst ett giltigt komplett par kan vinna.
- Fel eller avbruten operation lämnar varken en ensam `removed`-rad eller en ensam `selected`-rad.

### UI

- Flödet kan genomföras med tangentbord och vid 390 px utan horisontell scroll.
- Endast giltiga kandidater visas som ersättare.
- Matchdetaljen visar automatiska, manuellt tillagda och manuellt borttagna spelare begripligt.
- Stale- och valideringsfel ger en svensk återhämtningsväg tillbaka till aktuell match.

## Verifiering

1. `git diff --check`, lint, typkontroll, Vitest och produktionsbygge.
2. Enhetstester för kandidatfiltrering, formulärvalidering och svensk felmappning.
3. pgTAP för deferred parintegritet, ensam insert/delete/update, korskoppling, flera motparter, grants, RLS, serverroll, medlemskap och atomisk rollback.
4. Databasnära samtidighetstest med två separata sessioner mot samma plats.
5. Regressionstest som generering bevarar manuella include/exclude-rader.
6. Lokal användarresa: skapa byte, se märkning, generera preview, återställ byte.
7. Mobil 390 px, tangentbord, inga konsolfel eller horisontell scroll.
8. Oberoende skrivskyddad agentgranskning av hela diffen mot `main`.

## Definition av klar

Implementation 05 är integrationsklar när en aktiv tränare kan skapa och återställa ett atomiskt ordinarie byte, bytet bevaras av framtida generering, obehöriga och stale operationer nekas och inga oaccepterade granskningsfynd återstår.
