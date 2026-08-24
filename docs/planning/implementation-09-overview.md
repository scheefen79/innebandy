# Implementation 09: översikt

- Status: Föreslagen

## Syfte

Gör den avsedda startsidan användbar för de tre tränarna. På några sekunder ska de kunna se nästa match, öppna laget, överblicka de närmaste matcherna och förstå om den ordinarie fördelningen har en tydlig avvikelse.

```text
Översikt
  → nästa framtida match
  → öppna matchens lag
  → se upp till fem kommande matcher
  → se ordinarie rättvisefördelning
  → gå vidare till matcher eller spelare
```

## Föreslagen omfattning

### Routing och navigation

- `/` blir Översikt och markeras som aktiv i navigationen.
- Spelarlistan flyttas från `/` till `/players`.
- Befintliga länkar tillbaka till spelarlistan uppdateras till `/players`.
- Matcher ligger fortsatt på `/matches`.
- Direktlänkar till befintliga spelar- och matchdetaljer ska fortsätta fungera.

### Översiktsunderlag

- Underlaget hämtas i ett behörighetskontrollerat databasanrop för tränarens lag och aktiva säsong.
- Match-, uttagnings- och rättviseräknare ska komma från samma databassnapshot så att UI inte kan kombinera ett matchstatusläge med ett annat deltagandeläge.
- Endast aktiva lagmedlemmar får läsa underlaget.
- Annat lag, saknad aktiv säsong och obehörig användare ger generiska, användarsäkra fel.
- Svaret innehåller endast beslutad persondata: spelarnamn, matchkoppling och aggregerade antal.

### Nästa match

- Nästa match är den första `upcoming`-matchen vars `starts_at` ligger efter databasens aktuella tid.
- Kortet visar motståndare, datum, tid, valfri plats samt antal uttagna mot målantal.
- Antal uttagna omfattar valda ordinarie spelare och valda extra inhoppare, men inte manuellt borttagna spelare.
- CTA `Visa laget` går till matchdetaljen.
- Om uttagning saknas visas `0 / målantal` utan att appen antyder att laget är färdigt.

### Kommande matcher

- Visa nästa högst fem framtida `upcoming`-matcher i kronologisk ordning.
- Nästa match får ingå även i listan; kortet ovan är den framhävda genvägen.
- Varje rad visar datum och motståndare och länkar till matchdetaljen.
- Genomförda, inställda och passerade `upcoming`-matcher visas inte som kommande.
- Länk `Visa alla matcher` går till `/matches`.

### Matchfördelning

- Visa en kompakt fördelning grupperad som `N ordinarie matcher – X spelare`.
- En spelares ordinarie rättviseantal består av:
  - genomförda ordinarie matcher där spelaren faktiskt spelade
  - ännu ej genomförda ordinarie uttagningar där spelaren är vald
- Manuellt borttagna rader, inställda matcher, genomförd frånvaro och extra inhopp räknas inte.
- Alla aktiva spelare visas i fördelningen, även de som har noll ordinarie matcher.
- Grupper sorteras stigande efter antal matcher.
- Visa en varning när skillnaden mellan högsta och lägsta ordinarie antal överstiger ett. Varningen är informativ och länkar till förhandsgranskningen av omfördelning.
- Extra inhopp visas inte i denna rättviseindikator och får aldrig påverka varningen.

### Tillstånd och microcopy

- Loading state använder en stabil skelettvy utan layoutskifte.
- Saknas kommande matcher visas en tydlig empty state med CTA `Skapa match`.
- Saknas aktiva spelare visas rättvisesektionen med CTA `Lägg till spelare` i stället för en missvisande fördelning.
- Om översiktsunderlaget inte kan hämtas visas svensk feltext och länkar till Matcher och Spelare; inga partiella räknare presenteras som säkra.

## Ingår inte

- skapa, ändra, ställa in eller radera match direkt från översikten
- automatisk omfördelning
- val av startmatch för omfördelning
- extra inhoppsstatistik på översikten
- träningsnärvaro, resultat, tabell eller avancerade KPI:er
- medlems- eller säsongsadministration

## Acceptanskriterier

### Data och säkerhet

- Nästa match och kommande lista använder samma serverbestämda tidsgräns.
- Översiktsräknarna läses atomiskt och följer kanonisk match- och deltagandestatus.
- Aktiv medlem kan bara läsa sitt lags aktiva säsong.
- `anon`, outsider och inaktiv medlem nekas.
- Extra inhopp, inställda matcher, borttagna val och frånvaro påverkar inte ordinarie rättviseantal.

### UI

- `/` visar Översikt och `/players` visar spelarlistan.
- Alla tre navigationsval fungerar med tangentbord och anger aktiv sida korrekt.
- Nästa match kan öppnas via `Visa laget`.
- Högst fem kommande matcher visas i korrekt ordning.
- Rättvisegrupperna inkluderar aktiva nollspelare och använder begriplig svensk singular/plural.
- Loading, empty, error och populated states fungerar vid 390 px utan horisontell scroll.

## Verifiering

1. `git diff --check`, lint, typkontroll, Vitest och produktionsbygge.
2. Enhetstester för gruppering, sortering, singular/plural och varningsgräns.
3. Routetester för navigation och skyddad spelarlista efter flytten till `/players`.
4. pgTAP för medlemskap, aktiv säsong, gemensam tidsgräns och samtliga inkluderings-/exkluderingsregler.
5. Regressionstest att extra inhopp aldrig påverkar ordinarie rättvisegrupper eller varning.
6. Lokal användarresa: logga in, öppna Översikt, nästa match, Matcher och Spelare.
7. Mobil 390 px, tangentbord, inga konsolfel eller horisontell scroll.
8. Oberoende skrivskyddad agentgranskning av hela diffen mot `main`.

## Definition av klar

Implementation 09 är integrationsklar när tränaren kan använda startsidan för att förstå nästa aktivitet och ordinarie rättvisa utan att extra inhopp eller inkonsekventa snapshots ger en missvisande bild och utan öppna P0–P1-fynd.
