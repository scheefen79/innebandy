# Implementation 13: rollbaserad tränar- och besökarvy

- Status: Implementerad lokalt
- Föreslagen: 2026-09-03
- Produktunderlag: `docs/product/FBC_P17_DESIGN_TECH_SPEC.md`
- Arkitekturbeslut: `docs/architecture/decisions/ADR-016-role-based-coach-and-viewer-access.md`

## Syfte

Ge laget en säker, inloggad läsyta för besökare utan att exponera spelarnivåer, spelarprofiler eller ändringsmöjligheter:

```text
Användaren loggar in
  → aktivt lagmedlemskap och roll verifieras
  → coach får hela tränarverktyget
  → viewer får Kommande, Träningar och Matcher
  → viewer ser namn i matchuttagningen men ingen annan individuell spelardata
```

## Scope

- Utöka medlemsrollen med `viewer`.
- Returnera roll i lagkontexten och representera den typat i applikationen.
- Skapa minimerade, rollmedvetna läsmodeller för gemensamma vyer.
- Kräva `coach` för spelarresurser och samtliga mutationer.
- Anpassa navigation, routes, knappar och skrivskyddade tillstånd efter rollen.
- Migrera befintliga coachmedlemskap utan beteendeförändring.

## Ingår inte

- anonym eller publik åtkomst
- självregistrering, inbjudningar eller medlemsadministration
- koppling mellan en besökare och en särskild spelare
- fältkonfigurerade eller egna roller
- ändrad rättvise- eller uttagningslogik

## Leveransordning

### 1. Behörighetsinventering och kontrakt

- Lista alla direkta tabelläsningar, RPC:er, API-routes och servermutationer.
- Klassificera varje returvärde och åtgärd som `coach`, `viewer` eller båda.
- Lägg kontraktstester för tillåten och förbjuden data innan UI:t ändras.

### 2. Databas och lagkontext

- Migrera `team_members.role` från endast `coach` till `coach | viewer` utan att ändra befintliga rader.
- Uppdatera lagkontexten så att aktiv medlemsroll returneras atomiskt med lag och säsong.
- Inför en gemensam databasregel för att kräva aktiv `coach` vid skrivning.
- Uppdatera varje skrivande funktion så att `viewer`, outsider, inaktiv medlem och anonym användare nekas.

### 3. Minimerade läsmodeller

- Översikt och träningsläsning får returnera den laginformation som båda rollerna behöver.
- Matchlistor och matchdetaljer får returnera uttagna spelares id och namn till `viewer`.
- Spelarnivå, generell statistik och historik returneras endast till `coach`.
- Ta bort generell spelar- och deltagandeläsning för `viewer`; undvik att förlita säkerheten på klientfiltrering.

### 4. Routes och UI

- Gör `AppShell` rollmedvetet: `viewer` ser Kommande, Träningar och Matcher men inte Spelare.
- Dölj samtliga skapande, redigerande, omfördelande och avslutande kontroller för `viewer`.
- Rendera matchuttagningen utan nivåer eller historikmått för `viewer`.
- Kräv `coach` för `/players`, spelarprofiler och tillhörande API-routes. Direkt navigation ska ge en begriplig nekad vy eller säker omdirigering.
- Behåll loading, empty, error och populated states för båda rollerna.

### 5. Slutlig verifiering

- Kör lint, typkontroll, hela Vitest-sviten, hela pgTAP-sviten och produktionsbygge.
- Verifiera coach- och viewer-resan på mobil vid 390 px och desktop.
- Inspektera nätverkssvar som `viewer` och bekräfta att nivåer och historik aldrig skickas.
- Låt en oberoende skrivskyddad agent granska hela diffen mot `main`.

## Acceptanskriterier

### Coach

- Ser samma data och kan utföra samma åtgärder som före ändringen.
- Ser nivåer, spelarlista, spelarprofiler och spelarhistorik.

### Viewer

- Kan logga in med eget konto och aktivt `viewer`-medlemskap.
- Kan läsa Kommande, Träningar, Matcher och spelarnamn i matchuttagningar.
- Ser inte navigation eller redigeringskontroller som endast gäller coacher.
- Kan inte nå spelarlista, spelarprofil eller spelarhistorik genom direkt URL eller dataanrop.
- Tar aldrig emot spelarnivåer i HTML, RSC-payload, JSON eller Supabase-svar.
- Nekas av databasen vid varje direkt eller indirekt skrivförsök.

### Negativa säkerhetsfall

- `viewer`, outsider, inaktiv medlem och anonym användare nekas alla skrivfunktioner.
- `viewer` nekas generell läsning av spelar- och deltagandetabeller.
- Ett annat lags coach eller viewer kan inte läsa lagets data.
- Manipulerad klientnavigation eller rollparameter kan inte höja behörigheten.

## Verifiering

1. Migrationstest som bevarar befintliga `coach`-rader och accepterar endast `coach | viewer`.
2. pgTAP-matris för båda rollerna, outsider, inaktiv medlem, annat lag och anonym användare.
3. Kontraktstester som visar att viewer-svar innehåller namn i uttagning men saknar nivå och historik.
4. Tester av alla skrivande RPC:er med `viewer` som negativt fall.
5. Route- och komponenttester för rollanpassad navigation, direktåtkomst och dolda mutationer.
6. Regressionstester för coachens befintliga användarresor.
7. Mobil och desktop användarresa med separata coach- och viewer-sessioner.
8. Nätverksinspektion som verifierar dataminimering, inte bara visuellt dolda fält.

## Risker och återställning

- Den största risken är en befintlig medlemskontroll som oavsiktligt ger `viewer` coachrätt. Inventering och negativa tester ska därför föregå UI-arbetet.
- Ändrade grants kan bryta en befintlig coachläsning. Coachregressioner verifieras per läsmodell innan generell åtkomst tas bort.
- Migrationen ska kunna återställas genom att först konvertera eventuella `viewer`-medlemskap till `coach` eller inaktivera dem och därefter återställa rollbegränsningen. Återställningen får inte radera medlemskap.

## Definition av klar

Implementation 13 är integrationsklar när coachens befintliga funktionalitet är oförändrad, viewer endast kan läsa de beslutade lagvyerna, namn i matchuttagning är synliga, spelarnivåer och individuell spelardata aldrig exponeras och alla skrivvägar är verifierat coach-only.

## Genomförd verifiering

- ESLint: godkänd.
- TypeScript: godkänd.
- Vitest: 39 testfiler och 134 tester godkända.
- pgTAP: 11 testfiler och 302 tester godkända, inklusive separat coach/viewer-matris.
- Supabase databaslint: inga schemafel.
- Next.js produktionsbygge: godkänt och Proxy registrerad.
- Oberoende skrivskyddad granskning: ursprungliga P1- och P2-fynd rättade; inga kvarvarande P0–P2.

Kvarvarande manuell verifiering före integration: en verklig coach- och viewer-session på mobil och desktop med nätverksinspektion. Ingen commit, push eller deployment ingår i den lokala implementationen.
