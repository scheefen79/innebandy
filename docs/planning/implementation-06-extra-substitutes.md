# Implementation 06: extra inhoppare

- Status: Godkänd
- Godkänd: 2026-08-21

## Syfte

Ge en behörig tränare ett separat flöde för att lägga till extra inhoppare utan att påverka den ordinarie matchfördelningen:

```text
Tränaren öppnar en planerad match
  → väljer Lägg till extra inhoppare
  → ser en rättvist rangordnad kandidatlista
  → väljer rekommenderad eller annan tillgänglig spelare
  → bekräftar valet
  → extra inhoppare sparas atomiskt
  → matchen visar Extra inhoppare
```

Tränaren ska kunna ta bort en planerad extra inhoppare före matchstart. Förfrågningar och avböjanden lagras inte i MVP; endast den aktuella planerade extra uttagningen finns kvar.

## Beslutad omfattning

### Separat rättvisa

- Ordinarie uttagningar och extra inhopp är två oberoende rättvisesystem.
- Kandidater rangordnas med Implementation 02:s deterministiska extrafunktion:
  1. lägst antal genomförda extra inhopp
  2. lägst antal ordinarie matcher
  3. längst tid sedan senaste genomförda extra inhopp
  4. säsongens fasta `rotation_order`
- Det ordinarie antalet används endast när spelarna har lika många genomförda extra inhopp. Separata extraräknare är därför fortfarande det primära rättvisekriteriet.
- Spelarnivå används inte och visas inte som skäl för rekommendationen.
- Endast `extra`-rader i genomförda matcher där `played=true` räknas i historiken.
- `lastCompletedExtraAt` hämtas kanoniskt från den senaste räknade matchens `starts_at`, inte från uttagningsradens `created_at`, `updated_at` eller tidpunkten då deltagandet sparades.
- Planerade extra uttagningar påverkar inte historikräknaren och blockerar inte samma spelare från att rekommenderas till en annan framtida match.

### Giltiga kandidater

- Matchen ska tillhöra lagets aktiva säsong, ha status `upcoming` och ligga i framtiden när skrivningen sker.
- Kandidaten ska vara aktiv i samma lag och säsong.
- Kandidaten får inte ha någon befintlig uttagningsrad i den aktuella matchen. Det utesluter ordinarie uttagna, manuellt borttagna och redan registrerade extra inhoppare och följer tabellens unika `(match_id, player_id)`-kontrakt.
- Kandidatlistan beräknas på servern från det aktuella databasläget. Klienten får inte skicka egen historik eller prioritet.
- Tränaren får välja vilken valbar kandidat som helst; rekommendationen är vägledning och inte en spärr.
- Flera extra inhoppare stöds genom att samma flöde upprepas en spelare i taget.

### Persistensmodell

En planerad extra inhoppare lagras i `match_players` som:

- `selection_type='extra'`
- `selection_source='manual'`
- `selection_status='selected'`
- `played=false`
- `replaced_player_id=null`

Extra raden ökar inte matchens `target_players`, ersätter ingen ordinarie plats och får inte tas bort eller skrivas över av ordinarie generering eller manuella ordinarie byten.

### Lägg till och ta bort

- Lägg till och ta bort implementeras som separata atomiska server-only PostgreSQL-funktioner.
- Webbrouten verifierar sessionen och vidarebefordrar användar-id. Databasfunktionen accepterar endast `service_role` och verifierar aktivt lagmedlemskap.
- Match, kandidat och berörda uttagningsrader låses i stabil ordning före validering och skrivning.
- Tillägg och borttagning identifieras stabilt av match- och spelar-id; tabellens unika `(match_id, player_id)` gör kombinationen entydig. Formuläret bär dessutom ett serverberäknat fingeravtryck av matchstatus, starttid, spelarens aktiva status och matchens aktuella uttagningar.
- Kontrollordningen är: lås → behörighet och stabil målidentitet → actionspecifika domänvillkor → exakt uppnått sluttillstånd → stale-jämförelse → mutation.
- Båda operationerna kräver fortfarande en framtida `upcoming`-match även vid retry. Tillägg kräver dessutom att kandidaten fortfarande är aktiv i samma lag och säsong. Borttagning kräver inte att spelaren fortfarande är aktiv, eftersom en ogiltig planerad extra rad annars inte skulle kunna städas bort.
- Först därefter prövar funktionen om exakt önskat sluttillstånd redan är uppnått. Ett upprepat tillägg returnerar den befintliga extra raden utan dubblett. En upprepad borttagning är ett ofarligt resultat om spelaren inte längre har någon rad i matchen; en annan befintlig radtyp ger däremot `INVALID_EXTRA_SELECTION`.
- Endast om sluttillståndet inte redan är uppnått jämförs fingeravtrycket. Ändrat valbarhetsunderlag ger då `STALE_SELECTION` utan partiell förändring.
- Extrahistorik och kandidatordning ingår inte i stale-fingeravtrycket. Rekommendationen är ett rådgivande snapshot och tränaren får alltid välja en annan valbar kandidat; ny genomförd historik mellan visning och save stoppar därför inte ett fortfarande giltigt manuellt val.
- Borttagning får endast radera den exakta `extra/manual/selected/played=false`-raden och får aldrig röra ordinarie eller genomförd historik.

### Behörighet

- Endast aktiv lagmedlem får initiera tillägg eller borttagning.
- `anon`, `authenticated`, outsider och inaktiv medlem får inte direkt mutera `match_players` eller anropa mutationsfunktionerna.
- Server-only-funktionerna verifierar att match och spelare tillhör samma behöriga lag och aktiva säsong.
- Annat lag, annan säsong, okänd match och RLS-dold data ger samma generiska svar.
- Servernyckeln förblir isolerad till serverkod och får aldrig exponeras i klienten eller Git.

### Gränssnitt

- Matchdetaljen visar `Lägg till extra inhoppare` för framtida planerade matcher med sparad ordinarie uttagning.
- Kandidatvyn visar en tydligt märkt rekommendation först och därefter övriga valbara spelare i rättvis ordning.
- Varje kandidat visar namn, ordinarie matcher och genomförda extra inhopp. Vid behov visas kort text om väntetid, men ingen nivå.
- Tränaren väljer en spelare och ser en sammanfattning före bekräftelse.
- Matchdetaljen visar sparade spelare under en separat rubrik `Extra inhoppare`.
- Varje planerad extra inhoppare kan tas bort efter tydlig bekräftelse.
- Loading, empty, error, stale, success och obehörig/not-found hanteras med svensk microcopy utan tekniska id:n eller databasfel.

## Ingår inte

- markera match som genomförd eller inställd
- registrera faktisk närvaro eller öka extraräknaren
- lagra förfrågningar, avböjanden eller skäl
- aviseringar till spelare eller föräldrar
- separat tillgänglighetskalender
- nivåbalansering av extra inhoppare
- automatisk ändring av ordinarie uttagning eller target

## Acceptanskriterier

### Domän och data

- Kandidater rangordnas efter genomförda extra inhopp, ordinarie matcher, väntetid och `rotation_order` i den ordningen.
- Väntetiden använder `starts_at` från spelarens senaste genomförda match med `extra/played=true`, även om uttagningsradens skapande eller uppdatering skedde vid en annan tidpunkt.
- Ordinarie matcher används som sekundärt rättvisekriterium; spelarnivå påverkar inte extrarekommendationen.
- Endast faktiskt genomförda `extra/played=true`-rader påverkar historiken.
- En vald kandidat sparas exakt en gång som planerad extra och förändrar inga ordinarie rader eller `target_players`.
- Inaktiv, redan uttagen, manuellt borttagen eller redan extra spelare kan inte läggas till.
- Flera olika valbara extra spelare kan läggas till samma match genom separata operationer.
- Borttagning raderar endast vald planerad extra rad och påverkar inte historiken.

### Säkerhet och samtidighet

- Direkta mutationer och direkta RPC-anrop från `authenticated` och `anon` nekas.
- Serverrollen med outsider eller inaktivt vidarebefordrat användar-id nekas.
- Annat lag, annan säsong, genomförd/inställd match och passerad starttid nekas generiskt.
- Ändrat uttagningsunderlag mellan formulär och save ger `STALE_SELECTION` utan ändrade rader.
- Ändrad extrahistorik kan ändra rekommendationsordningen men ska inte ge stale om den valda spelaren fortfarande är valbar.
- Två samtidiga tillägg av samma spelare konvergerar till en rad; tillägg och borttagning mot samma rad serialiseras utan förlorad uppdatering.
- Fel eller avbruten operation förändrar varken extra eller ordinarie uttagningar.

### UI

- Flödet kan genomföras med tangentbord och vid 390 px utan horisontell scroll.
- Rekommenderad kandidat och övriga kandidater visas begripligt utan nivåstyrning.
- Tom kandidatlista förklarar att inga tillgängliga spelare finns.
- Matchdetaljen skiljer tydligt ordinarie spelare, manuella ordinarie ändringar och extra inhoppare.
- Stale- och valideringsfel ger en svensk återhämtningsväg tillbaka till den aktuella matchen.

## Verifiering

1. `git diff --check`, lint, typkontroll, Vitest och produktionsbygge.
2. Deterministiska tester för extrarankning, inklusive nollhistorik, olika antal, väntetid från matchens `starts_at` och rotationsordning; radens egna tidsstämplar ska inte påverka ordningen.
3. Tester som visar att ordinarie antal endast bryter lika extrahistorik och att nivå inte påverkar resultatet.
4. pgTAP för kanonisk historikkälla, radform, grants, serverroll, medlemskap, matchstatus, kandidatregler och atomisk rollback.
5. Databasnära samtidighetstest för dubbelt tillägg samt tillägg mot samtidig borttagning.
6. Test som visar att idempotent sluttillstånd prövas före stale och att ändrad historik inte stoppar ett fortfarande valbart manuellt val.
7. Negativa retry-tester efter att matchen blivit genomförd, inställd eller passerad samt add-retry efter att kandidaten blivit inaktiv; remove av en befintlig planerad extra rad ska fortfarande fungera för en inaktiv spelare i en framtida `upcoming`-match.
8. Regressionstest som ordinarie generering och manuella byten bevarar extra rader.
9. Lokal användarresa: rekommendation, välj annan kandidat, lägg till flera, ta bort en och verifiera oförändrat ordinarie lag.
10. Mobil 390 px, tangentbord, inga konsolfel eller horisontell scroll.
11. Oberoende skrivskyddad agentgranskning av hela diffen mot `main`.

## Definition av klar

Implementation 06 är integrationsklar när en aktiv tränare kan se en rättvis separat rekommendation, lägga till eller ta bort planerade extra inhoppare atomiskt, ordinarie fördelning förblir oförändrad och inga oaccepterade granskningsfynd återstår.
