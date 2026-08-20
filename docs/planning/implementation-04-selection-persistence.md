# Implementation 04: generera och spara ordinarie laguttagningar

- Status: Godkänd
- Godkänd: 2026-08-20

## Syfte

Koppla den verifierade fördelningsmotorn till den aktiva säsongens framtida matcher:

```text
Tränare väljer Generera fördelning
  → servern läser ett behörigt och versionsbestämt underlag
  → den rena motorn skapar ordinarie lag
  → tränaren ser resultat och varningar
  → hela fördelningen sparas atomiskt
  → matchvyer visar Lag och Står över
```

Implementation 04 är den första persistensen av ordinarie uttagningar. Manuella ändringar, extra inhopp och genomförd match levereras separat.

## Beslutad omfattning

### Genereringsgräns

- Genereringen omfattar alla framtida matcher med status `upcoming` i lagets aktiva säsong.
- Matcher sorteras deterministiskt efter `starts_at` och därefter `id`.
- Genomförda och inställda matcher ingår inte.
- Endast aktiva spelare med giltig nivå ingår automatiskt.
- Fördelningen genereras gemensamt för hela återstående schemat, inte match för match, så att säsongsrättvisan kan optimeras.

### Förhandsgranskning

- `Generera fördelning` skapar först en serverberäknad förhandsgranskning utan databasskrivning.
- Förhandsgranskningen visar antal matcher per spelare, lag per match och strukturerade varningar på svenska.
- Strukturerade fel stoppar flödet och lämnar befintliga uttagningar oförändrade.
- Tränaren väljer därefter `Spara fördelning`.

### Datamodell

En migration skapar `match_players` med minst:

- `id`
- `team_id`
- `season_id`
- `match_id`
- `player_id`
- `selection_type`: `regular` eller `extra`
- `selection_source`: `automatic` eller `manual`
- `selection_status`: `selected` eller `removed`
- `played`
- `replaced_player_id`, valfritt
- `created_at`
- `updated_at`

Databasen ska använda sammansatta foreign keys för att garantera att match, spelare, säsong och lag hör ihop. Migrationen får lägga den kompletterande unika referensnyckeln `(id, team_id, season_id)` på `players` som den starka foreign keyn kräver. En spelare får högst en uttagningsrad per match.

Implementation 04 skriver endast:

- `selection_type = regular`
- `selection_source = automatic`
- `selection_status = selected`
- `played = false`

Övriga värden reserveras för senare godkända flöden och får inte kunna skrivas godtyckligt av klienten.

### Atomisk persistens och samtidighet

- Webbläsaren får aldrig skriva `match_players` direkt.
- En behörighetskontrollerad PostgreSQL-funktion sparar hela fördelningen i en transaktion.
- Funktionen låser berörda framtida matcher innan befintliga automatiska rader ersätts.
- Förhandsgranskningen får ett versionsmärkt, serverberäknat underlagsfingeravtryck som omfattar aktiva spelare, nivåer, rotationsordning, framtida matcher, target och befintliga uttagningar.
- Fingeravtryckets kanoniska JSON-format och sorteringsordning definieras gemensamt och testas med samma fixtures i TypeScript och PostgreSQL.
- Vid sparande låser databasfunktionen berörda källrader, bygger om samma kanoniska underlag och jämför fingeravtrycket innan någon uttagning ändras. Om underlaget har ändrats stoppas skrivningen med ett stabilt stale-preview-fel.
- Fel får aldrig lämna ett partiellt nytt resultat.
- Databasfunktionen validerar dessutom att payloaden fyller exakt target med unika, aktiva och behöriga spelare i varje match. Den litar inte enbart på fingeravtrycket från klienten.
- Upprepat sparande av samma aktuella resultat ska konvergera till samma laguttagningar.

### Behörighet

- Aktiv lagmedlem får läsa lagets uttagningar.
- Icke-medlem, inaktiv medlem och `anon` får inte läsa uttagningar.
- `authenticated` får inte direkt `insert`, `update` eller `delete` på `match_players`.
- Persistensfunktionen verifierar aktivt medlemskap, aktiv säsong, framtida `upcoming`-matcher och att varje spelare tillhör samma lag och säsong.
- Funktionen accepterar aldrig ett godtyckligt lag-id som ensam behörighetsgrund; `auth.uid()` och medlemskapet är auktoritativa.

### Applikationslager

Ett use case ansvarar för att:

1. läsa aktivt lag och aktiv säsong
2. läsa aktiva spelare
3. läsa alla framtida planerade matcher med explicit `now`
4. bygga `RegularAllocationInput`
5. anropa `generateRegularAllocation`
6. översätta stabila fel och varningar till svensk text
7. skapa förhandsgranskning och underlagsfingeravtryck
8. spara via den atomiska databasfunktionen

Domänmotorn förblir fri från Supabase-, Next.js- och React-typer.

### Gränssnitt

- Matchlistan får en tydlig CTA för att generera fördelningen.
- En förhandsgranskningssida visar planerade lag innan sparande.
- Efter sparande visar matchraden verkligt `antal uttagna / target`.
- Matchdetaljen får flikarna `Lag` och `Står över`.
- Spelarrader visar namn och nivå. Tekniska id:n exponeras inte.
- Loading, empty, error, preview och saved states hanteras.
- Varningar blockerar inte sparande; strukturerade fel gör det.

## Ingår inte

- manuella spelarbyten eller återställning av manuella val
- extra inhoppare och extrarekommendation
- markera match som genomförd eller inställd
- deltagandestatus och spelarhistorik
- omfördelning från en valfri framtida match
- ändra eller radera matcher
- produktionsdata eller deployment

## Acceptanskriterier

### Domänkoppling

- Alla framtida `upcoming`-matcher i aktiva säsongen skickas till motorn i stabil ordning.
- Varje aktiv spelare mappas med nivå, rotationsordning och korrekt baseline.
- Extra inhopp påverkar inte ordinarie input.
- Motorfel ger ingen persistens.
- Varningar visas på svenska och kan sparas efter tränarens uttryckliga val.

### Databas och säkerhet

- Migrationerna kan appliceras från tom lokal databas.
- Sammansatta foreign keys stoppar korskoppling mellan lag, säsong, match och spelare.
- Endast aktiv medlem kan läsa lagets uttagningar och anropa persistensfunktionen.
- Direkta klientmutationer av `match_players` nekas.
- Felaktig target, okänd spelare, dubblett eller fel lag stoppas atomiskt.
- Ett ändrat underlag mellan preview och save ger stale-preview-fel utan ändrade rader.
- Samma giltiga resultat kan sparas igen utan dubbletter eller ändrat innehåll.
- Samtidiga sparförsök kan inte lämna blandade eller partiella fördelningar.

### UI

- Förhandsgranskningen visar exakt target unika ordinarie spelare per match.
- Sparad matchlista visar korrekt uttaget antal.
- `Lag` visar uttagna spelare; `Står över` visar övriga aktiva spelare.
- En obehörig användare kan inte avgöra om ett annat lags uttagning finns.
- Centrala states fungerar vid 390 px utan horisontell scroll och kan användas med tangentbord.

## Verifiering

1. `git diff --check`, lint, typkontroll och hela Vitest-sviten.
2. Deterministiska mapper-/use-case-tester för input, baseline, fel och varningar.
3. pgTAP för schema, sammansatta foreign keys, grants, RLS och negativa mutationer.
4. Databasnära transaktionstester för stale preview, idempotent save, samtidiga försök och rollback vid fel.
5. Produktionsbygge.
6. Lokal användarresa för preview, save, matchlista, Lag/Står över och 390 px.
7. Oberoende skrivskyddad agentgranskning av hela diffen mot `main`.

## Definition av klar

Implementation 04 är integrationsklar när en aktiv tränare kan generera, förhandsgranska, spara och läsa en komplett ordinarie fördelning; obehöriga nekas; persistensen är atomisk och skyddad mot stale input; och inga oaccepterade granskningsfynd återstår.
