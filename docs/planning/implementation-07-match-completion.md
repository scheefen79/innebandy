# Implementation 07: genomför match och registrera deltagande

- Status: Godkänd
- Godkänd: 2026-08-24

## Syfte

Låt en behörig tränare avsluta en spelad match och samtidigt registrera vilka uttagna spelare som faktiskt deltog:

```text
Matchens starttid har passerat
  → tränaren väljer Genomför match
  → alla ordinarie och extra uttagna föreslås som deltagande
  → tränaren avmarkerar återbud eller frånvaro
  → granskar och sparar
  → deltagande och matchstatus sparas atomiskt
  → ordinarie historik och extrarotation uppdateras
```

Matchen är fortsatt `Planerad` tills deltagandet har sparats. Det finns ingen separat status `Bekräftad` före matchen.

## Beslutad omfattning

### När en match kan genomföras

- Matchen ska tillhöra lagets aktiva säsong, ha status `upcoming` och dess `starts_at` ska ha passerat när skrivningen sker.
- Matchen ska ha en komplett sparad ordinarie uttagning: antal `regular/selected` ska motsvara `target_players`.
- Extra inhoppare är valfria och ligger utanför ordinarie target.
- Inaktiv spelarstatus efter uttagningen blockerar inte registrering. En redan uttagen spelare ska kunna registreras historiskt även om den senare deaktiverats.
- En framtida, inställd, redan genomförd med annat resultat, okänd eller RLS-dold match får inte ändras.

### Deltagandeunderlag

- Endast aktuella `match_players` med `selection_status='selected'` ingår i formuläret.
- Det omfattar automatiska och manuellt tillagda ordinarie spelare samt planerade extra inhoppare.
- Manuellt borttagna ordinarie spelare visas inte som deltagare och förblir `played=false`.
- Alla valbara deltagare är markerade som `Spelade` som standard. Tränaren avmarkerar dem som inte deltog.
- Formuläret skickar ett komplett beslut för varje vald uttagningsrad, inte bara avvikelser. Dubbletter, saknade, okända eller extra spelar-id stoppas.
- Spelarnivå, ordinarie rättvisa och extrarankning påverkar inte deltagarregistreringen.

### Atomisk persistens

- En server-only PostgreSQL-funktion uppdaterar alla berörda `played`-värden och sätter matchstatus till `completed` i samma transaktion.
- Match, aktiva uttagningsrader och manuella par låses i stabil ordning före validering.
- Ett versionsmärkt fingeravtryck omfattar matchens status, starttid, target och samtliga uttagningsrader med typ, källa, status, `played`, koppling och `updated_at`.
- Ändrat underlag mellan visning och save ger `STALE_SELECTION` utan partiell förändring.
- Kontrollordningen är lås → behörighet och målidentitet → strukturell inputvalidering → completed-gren → domänvillkor för ny completion → stale → exakt setvalidering → mutation. Strukturell validering kräver en lista med unika UUID:n och riktiga booleska värden; exakt setvalidering kräver sedan samma spelar-id som matchens aktuella selected-rader.
- I completed-grenen jämförs det inskickade fullständiga beslutet med det sparade. En identisk retry returnerar samma resultat trots att det gamla fingeravtrycket inte längre matchar. Ett annat deltagandebeslut stoppas med `MATCH_ALREADY_COMPLETED`; den första skrivningen ändras inte. För en ännu inte genomförd match valideras därefter passerad `upcoming`, komplett ordinarie uttagning och övriga domänvillkor.
- Implementation 07 öppnar inte redigering av en redan genomförd match. En framtida korrigeringsfunktion kräver ett separat produkt- och revisionsbeslut.

### Manuella ordinarie par

- Det manuella paret bevaras för att visa vem som ursprungligen stod över och vem som lades till.
- Integritetsregeln ändras så att en `regular/manual/selected`-rad får ha `played=true` endast när den kopplade matchens slutläge i samma transaktion är `completed`. Den uppskjutna triggern validerar matchstatus tillsammans med parets slutläge.
- En `regular/manual/removed`-rad måste alltid ha `played=false`.
- Paret ska fortsatt vara ömsesidigt, tillhöra samma match/lag/säsong och ha motsatta selection-statusar.
- Genomförda manuella par kan inte återställas eller kedjebyta eftersom matchen inte längre är `upcoming`.

### Historik och rättvisa

- En genomförd ordinarie match räknas endast för `regular/selected/played=true`.
- En uttagen ordinarie spelare med `played=false` redovisas som `Deltog inte` och räknas inte i genomförd ordinarie historik.
- Ett extra inhopp räknas endast för `extra/selected/played=true` i en `completed`-match.
- En planerad extra spelare med `played=false` redovisas som `Deltog inte` och ökar inte extraräknaren.
- Ordinarie och extra historik fortsätter vara separata. Genomförande utlöser ingen automatisk omfördelning av framtida matcher.
- Extrahistorikens senaste tidpunkt fortsätter vara den genomförda matchens `starts_at` enligt ADR-009.

### Behörighet

- Webbläsaren får inte uppdatera `matches` eller `match_players` direkt.
- Den skyddade Next.js-routen verifierar sessionen och vidarebefordrar användar-id.
- Databasfunktionen accepterar endast `service_role` och verifierar aktivt medlemskap i laget.
- `anon`, `authenticated`, outsider och inaktiv medlem får inte direkt anropa completion-funktionen.
- Servernyckeln förblir isolerad till serverkod och får aldrig exponeras i klienten eller Git.

### Gränssnitt

- Matchdetaljen visar `Genomför match` när matchen är `Planerad`, starttiden har passerat och ordinarie uttagning är komplett.
- Completion-vyn delar deltagarna i `Ordinarie` och `Extra inhoppare`.
- Varje spelare har en tydlig checkbox `Spelade` som är markerad som standard.
- Sammanfattningen visar antal spelade ordinarie, frånvarande ordinarie, genomförda extra inhopp och frånvarande extra.
- Före save visas en tydlig bekräftelse om att matchen låses som genomförd.
- Matchdetaljen visar efteråt `Spelade`, `Deltog inte` och `Extra inhoppare` utan att tekniska statusfält exponeras.
- Loading, empty, error, stale, success och obehörig/not-found hanteras med svensk microcopy.

## Ingår inte

- redigera deltagande efter att matchen genomförts
- ställa in eller återöppna match
- permanent radering av match
- matchresultat, mål eller annan statistik
- automatisk omfördelning av framtida matcher
- aviseringar eller kommunikation
- spelarhistorikens fullständiga profilsida

## Acceptanskriterier

### Domän och data

- Alla selected ordinarie och extra föreslås som spelade, medan manuellt borttagna aldrig ingår.
- Save kräver exakt ett booleskt deltagandebeslut per aktuell selected-rad.
- Matchstatus och samtliga `played`-värden ändras atomiskt.
- Manuellt tillagd ordinarie spelare kan markeras spelad utan att parintegriteten bryts; manuellt borttagen kan aldrig markeras spelad.
- Genomförd ordinarie historik och extra historik räknar bara respektive typ med `played=true`.
- Frånvaro påverkar ingen historikräknare och ordinarie/extra förblir separata.
- Matchens target, selection type/source/status och manuella kopplingar förändras inte.

### Säkerhet och samtidighet

- Direkt UPDATE och direkt RPC från `authenticated` och `anon` nekas.
- Serverrollen med outsider eller inaktivt vidarebefordrat användar-id nekas.
- Framtida, inställd, fel lag/säsong och ofullständig ordinarie uttagning nekas generiskt.
- Ändrad uttagning mellan formulär och save ger `STALE_SELECTION` utan ändrade rader.
- Två identiska samtidiga saves konvergerar till samma genomförda resultat.
- Två olika samtidiga saves ger first-write-wins; förloraren får `MATCH_ALREADY_COMPLETED` och får inte skriva över deltagandet.
- Databasfel lämnar både matchstatus och alla deltaganderader oförändrade.

### UI

- Flödet kan genomföras med tangentbord och vid 390 px utan horisontell scroll.
- Defaultvalet är begripligt och varje spelare kan markeras som `Deltog inte` före save.
- Ordinarie och extra deltagare visas separat.
- Genomförd match visar det sparade deltagandet och döljer planeringsmutationer.
- Stale- och konfliktfel ger en svensk återhämtningsväg till aktuell match.

## Verifiering

1. `git diff --check`, lint, typkontroll, Vitest och produktionsbygge.
2. Enhetstester för exakt deltagandeinput, defaults, sammanfattning och svensk felmappning.
3. pgTAP för manuella par efter completion, historikseparation, fullständig input, grants, medlemskap, matchstatus och atomisk rollback. Negativa fall ska visa att `manual/selected/played=true` nekas på både `upcoming` och `cancelled`; ett positivt fall ska visa att selected-raden och matchstatus kan övergå atomiskt till `played=true`/`completed` i samma transaktion.
4. Negativa tester för saknad/dubblerad/okänd spelare, manuellt borttagen spelare och ogiltigt booleskt värde.
5. Databasnära samtidighetstest med identiska respektive olika deltagandebeslut.
6. Regressionstest av ordinarie baseline och extrakandidatordning efter completion med både deltagande och frånvaro.
7. Lokal användarresa: default alla spelade, markera frånvaro, spara, verifiera status och historik.
8. Mobil 390 px, tangentbord, inga konsolfel eller horisontell scroll.
9. Oberoende skrivskyddad agentgranskning av hela diffen mot `main`.

## Definition av klar

Implementation 07 är integrationsklar när en aktiv tränare kan registrera faktiskt deltagande och genomföra en spelad match atomiskt, historiken uppdateras separat och korrekt och inga oaccepterade granskningsfynd återstår.
