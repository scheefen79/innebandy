# Implementation 08: spelarhantering och spelarhistorik

- Status: Godkänd
- Godkänd: 2026-08-24

## Syfte

Gör spelarytan användbar för de tre tränarna genom att låta en behörig tränare skapa, öppna, ändra och deaktivera spelare samt förstå spelarens ordinarie och extra matchhistorik.

```text
Spelarlista
  → separata ordinarie och extra antal
  → öppna spelarkort
  → se kommande och tidigare matcher
  → ändra namn eller nivå
  → deaktivera med tydlig konsekvens
  → omfördela framtida matcher uttryckligen vid behov
```

## Föreslagen omfattning

### Spelarlista

- Visa endast aktiva spelare för lagets aktiva säsong.
- Lägg till sökning på spelarens för- och efternamn.
- Varje rad länkar till spelarens spelarkort.
- Visa nivå samt separata antal för:
  - planerade ordinarie matcher
  - genomförda ordinarie matcher
  - planerade extra inhopp
  - genomförda extra inhopp
- Ordinarie och extra får inte summeras till ett gemensamt rättvisemått.
- Visa CTA `Lägg till spelare` i både empty och populated state.

### Skapa spelare

- Fält: förnamn, efternamn valfritt och nivå 1–3.
- Namn trimmas och valideras med befintliga databasgränser.
- Den nya spelaren kopplas alltid till tränarens lag och aktiva säsong.
- `rotation_order` tilldelas atomiskt som nästa permanenta ordning i säsongen.
- Formuläret skapar ett stabilt `request_id` som skickas oförändrat vid retry och lagras på den skapade spelaren.
- Samma `request_id` med samma normaliserade spelaruppgifter returnerar den redan skapade spelaren. Samma id med andra uppgifter stoppas utan ny rad.
- Samtidigt skapande av två spelare får inte ge samma rotationsplats eller tappad skrivning.
- Skapandet ändrar inte befintliga uttagningar automatiskt.

### Spelarkort och historik

- Visa namn, nivå och aktiv status.
- Visa sammanfattningen ordinarie och extra separat.
- `Kommande matcher` visar endast `upcoming` där spelaren är `selected`, märkt `Ordinarie` eller `Extra inhoppare`.
- `Tidigare matcher` visar endast `completed` där spelaren var `selected` och skiljer:
  - `Ordinarie · Spelade`
  - `Ordinarie · Deltog inte`
  - `Extra inhoppare · Spelade`
  - `Extra inhoppare · Deltog inte`
- Manuellt borttagna rader och inställda matcher räknas inte som spelarens matcher.
- Historiska kopplingar finns kvar även om spelaren senare deaktiveras.

### Ändra spelare

- Tränaren kan ändra förnamn, efternamn och nivå från spelarkortet.
- Nivå 1 är högst och nivå 3 lägst.
- Ändringen påverkar inte redan sparade uttagningar.
- Om spelaren har framtida automatiska ordinarie uttagningar visas att fördelningen kan behöva omfördelas.
- Nivåändringen används först vid nästa uttryckliga omfördelning och får aldrig påverka extrarotationen.

### Deaktivera spelare

- Deaktivering är soft delete genom `is_active=false`; spelarraden och all historik bevaras.
- Åtgärden kräver en tydlig bekräftelse som förklarar att spelaren försvinner från nya uttagningar.
- Befintliga uttagningsrader ändras inte automatiskt.
- Före deaktivering visar UI varje framtida manuellt ordinarie par och extra inhopp som måste hanteras.
- Deaktivering blockeras så länge spelaren har någon framtida `regular/manual`-rad, oavsett om den är `selected` eller `removed`. Tränaren måste först återställa bytet från matchen. Därmed kan inte ett manuellt par lämnas i ett tillstånd där båda sidor är inaktiva och återställning är omöjlig.
- Deaktivering blockeras också så länge spelaren är framtida `extra/manual/selected`; den extra inhopparen tas först bort från matchen.
- Framtida `regular/automatic/selected` blockerar inte deaktivering. Efteråt visas de berörda matcherna och CTA för omfördelning från nästa planerade match.
- UI får inte påstå att framtida fördelning är uppdaterad innan omfördelningen är sparad.
- En deaktiverad spelare får inte bli kandidat i ny ordinarie fördelning eller som extra inhoppare.
- Återaktivering ingår inte i denna implementation.

### Atomiska mutationer och samtidighet

- Skapa, ändra och deaktivera går genom server-only PostgreSQL-funktioner.
- Webbläsaren får endast läsa `players` direkt och får inte infoga eller uppdatera spelarrader.
- Next.js-routen verifierar session och vidarebefordrar användar-id; databasen verifierar `service_role`, aktivt lagmedlemskap, aktiv säsong och målidentitet.
- Ett versionsmärkt spelar-fingeravtryck skyddar ändring och deaktivering mot gamla formulär. Skapande använder i stället sitt unika `request_id`.
- Identiska retries konvergerar. Create jämför request-id och normaliserad input; edit jämför det redan uppnådda fältläget; deactivate godkänner ett exakt redan uppnått inaktivt sluttillstånd. Ett annat beslut mot ändrad spelare ger `STALE_PLAYER` utan partiell ändring.
- Deactivate följer kontrollordningen lås → behörighet och stabil målidentitet → exakt redan uppnått sluttillstånd → stale → mutation. Regeln att en inaktiv målspelare nekas gäller edit och nya åtgärder, inte en verifierbar identisk deactivate-retry.
- Säsong respektive spelare låses i stabil ordning. Nästa `rotation_order` beräknas under säsongslåset.

### Omfördelningssignal

- Implementation 08 ändrar aldrig uttagningar automatiskt.
- Efter skapande eller nivåändring visas en kort förklaring och länk till befintlig förhandsgranskning av fördelningen.
- Före deaktivering visas separata matchlänkar för manuella par och extra rader som måste återställas eller tas bort. Efter lyckad deaktivering visas omfördelningslänken för kvarvarande automatiska rader.
- Den generella funktionen att välja en valfri framtida startmatch för omfördelning ligger kvar till en separat implementation.
- Ordinarie omfördelning får inte presenteras som lösning på manuella par eller extra rader; dessa måste vara lösta innan deaktivering kan sparas.

### Behörighet och persondata

- Endast aktiva lagmedlemmar får läsa eller mutera lagets spelare.
- `anon`, `authenticated`, outsider och inaktiv medlem får inte direkt anropa mutationsfunktionerna.
- Annat lag, annan säsong och okänd spelare ger generiskt fel. Inaktiv spelare nekas för edit men en identisk deactivate-retry konvergerar enligt den dokumenterade kontrollordningen.
- Endast namn, nivå och matchkopplingar lagras; ingen ytterligare persondata införs.

## Ingår inte

- återaktivera spelare
- flytta spelare mellan lag eller säsonger
- ändra rotationsordning manuellt
- nivåhistorik
- foto, kontaktuppgifter, födelsedata eller medicinsk information
- vald startmatch för omfördelning
- automatisk omfördelning efter spelarändring
- korrigera deltagande i genomförd match

## Acceptanskriterier

### Domän och data

- En aktiv tränare kan skapa en spelare med giltigt namn och nivå.
- Två samtidiga skapanden får unika, deterministiska rotationsplatser.
- En identisk create-retry med samma `request_id` skapar aldrig en dubblett.
- Namn och nivå kan ändras utan att befintliga `match_players` förändras.
- Deaktivering bevarar spelaren och samtliga historiska och framtida matchkopplingar.
- Deaktivering kan inte skapa ett framtida manuellt eller extra beslut utan åtgärdsväg; automatiska rader har en tydlig omfördelningsväg.
- Planerad och genomförd ordinarie historik redovisas separat från planerade och genomförda extra inhopp.
- Frånvaro räknas inte som genomförd match men visas på spelarkortet.
- Manuellt borttagen och inställd match påverkar inga spelarantal.

### Säkerhet och samtidighet

- Direkt INSERT/UPDATE på `players` och direkta mutations-RPC från `authenticated` och `anon` nekas.
- Serverrollen med outsider eller inaktivt vidarebefordrat användar-id nekas.
- Fel lag/säsong, stale formulär och ogiltig input lämnar spelare och uttagningar oförändrade.
- Identiska retries konvergerar och olika samtidiga ändringar följer first-write-wins.
- Ingen servernyckel eller persondata utöver beslutat scope exponeras.

### UI

- Spelarlistan kan sökas och öppna ett spelarkort.
- Empty, loading, error och populated states har svensk microcopy.
- Skapa, ändra och deaktivera fungerar med tangentbord och vid 390 px utan horisontell scroll.
- Nivåskalan förklaras konsekvent.
- Deaktivering kräver tydlig bekräftelse och eventuell omfördelningssignal är begriplig.

## Verifiering

1. `git diff --check`, lint, typkontroll, Vitest och produktionsbygge.
2. Enhetstester för validering, sökning, etiketter och separata historikantal.
3. Routetester för session, input, stale, success och generiska fel.
4. pgTAP för grants, medlemskap, lag-/säsongsidentitet, rotation, soft delete, blockering vid båda sidor av framtida manuella par och extra rader, historik och atomisk rollback.
5. Databasnära samtidighetstest för två skapanden, identisk create-retry och två olika uppdateringar.
6. Regressionstest som spelarändringar aldrig muterar befintliga uttagningar och att framtida allocation-källa reagerar på aktiv status/nivå.
7. Lokal användarresa: skapa, sök, öppna, ändra nivå, kontrollera historik och deaktivera.
8. Mobil 390 px, tangentbord, inga konsolfel eller horisontell scroll.
9. Oberoende skrivskyddad agentgranskning av hela diffen mot `main`.

## Definition av klar

Implementation 08 är integrationsklar när tränarna kan underhålla spelartruppen och förstå varje spelares ordinarie och extra matchhistorik utan att spelarändringar tyst skriver om en uttagning och utan öppna P0–P1-fynd.
