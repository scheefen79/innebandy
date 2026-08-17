# Implementation 03: matchgrund

- Status: Godkänd
- Godkänd: 2026-08-17

## Syfte

Bygg nästa kompletta vertikala flöde:

```text
Tränare skapar en match
  → servern verifierar lag och aktiv säsong
  → databasen sparar matchen med RLS
  → matchen visas i listan
  → matchdetaljen kan öppnas
```

När implementationen är klar kan tränarna lägga in och läsa säsongens spelschema. Fördelningsmotorn kopplas inte in förrän matchgrunden är verifierad.

## Ingår

### Datamodell

En reproducerbar Supabase-migration för `matches` med minst:

- `id`
- `team_id`
- `season_id`
- `opponent`
- `starts_at`
- `location`, valfritt
- `target_players`
- `status`: `upcoming`, `completed` eller `cancelled`
- `request_id`, ett lag-scopat idempotens-id för create-formuläret
- `created_at`
- `updated_at`

Databasen ska garantera att matchens lag och säsong hör ihop. `target_players` ska vara ett positivt heltal. Nya matcher får endast skapas som `upcoming`, med databasdefault och RLS `WITH CHECK` som även skyddar direkt Data API-anrop.

Tabellen ska dessutom ha:

- `unique (team_id, request_id)` för lag-scopad idempotens
- `unique (id, team_id)` så Implementation 04 kan skapa en stark sammansatt foreign key från `match_players`
- en databas-trigger som sätter `updated_at = now()` vid varje update, även om authenticated ännu inte har update-grant

### Behörighet

- Endast autentiserade användare med aktivt medlemskap i matchens lag får läsa matcher.
- Endast aktiva lagmedlemmar får skapa matcher för lagets aktiva säsong.
- Insert-policy och databasdefault ska hindra authenticated från att skapa `completed` eller `cancelled` direkt.
- `anon` och autentiserade användare utan lagmedlemskap får inte läsa eller skapa matcher.
- Direkt `update` och `delete` ges inte i denna implementation eftersom motsvarande produktflöden inte ingår ännu.
- Ingen service role-nyckel används i applikationen.

### Skapa match

Ett mobile-first-formulär med:

- datum
- tid
- motståndare
- plats, valfritt
- antal spelare att kalla

Default för antal spelare är:

```text
ceil(antal aktiva spelare i den aktiva säsongen × 0,5)
```

Formuläret ska:

- validera obligatoriska fält på servern
- trimma textfält
- begränsa motståndare till 1–100 tecken och plats till högst 200 tecken
- avvisa ogiltigt datum/tid och target mindre än 1
- visa ett generiskt och praktiskt fel utan tekniska databasdetaljer
- inaktivera submit medan begäran pågår
- återanvända formulärets `request_id` så att upprepade identiska submit-försök returnerar samma match i stället för att skapa dubbletter
- omdirigera till den skapade matchdetaljen efter lyckat sparande

`request_id` ska vara en servervaliderad UUID och följa first-write-wins:

- första giltiga skrivningen skapar matchen
- identisk normaliserad payload med samma `team_id` och `request_id` returnerar den befintliga matchens id
- samma id med ändrad normaliserad payload returnerar ett stabilt konfliktfel och får aldrig uppdatera originalmatchen
- samma `request_id` får användas oberoende i två olika lag
- parallella identiska försök ska resultera i exakt en match

### Tidsmodell

- Formuläret tolkar datum och tid i `Europe/Stockholm`.
- Servern konverterar värdet till en entydig tidpunkt innan lagring.
- Lokala klockslag som inte existerar vid vårens omställning eller är tvetydiga vid höstens omställning avvisas med ett praktiskt valideringsfel; ingen dold offset väljs.
- PostgreSQL lagrar tiden som `timestamptz`.
- UI formaterar tiden på svenska i `Europe/Stockholm`.
- Tester ska täcka normal svensk vinter- och sommartid samt både obefintligt och tvetydigt klockslag vid tidsomställning.

### Matchlista

Route och navigation för `Matcher` med två filter:

- `Kommande`: matcher med status `upcoming` vars starttid inte har passerat, äldsta först
- `Alla`: alla matcher i den aktiva säsongen, senaste starttid först

Varje matchrad visar:

- datum
- tid
- motståndare
- antal uttagna / target
- status på svenska

Eftersom uttagningar ännu inte finns visas antal uttagna som `0 / target`.

Gränsen för vad som är kommande ska skickas in som en explicit aktuell tid till query/use-case så att tester och rendering inte får ett dolt klockberoende.

Listan ska hantera loading, empty, error och populated state. Empty state ska skilja mellan att säsongen saknar matcher och att filtret `Kommande` saknar träffar.

### Matchdetalj

En läsbar detaljsida som visar:

- motståndare
- datum och tid
- plats om angiven
- target-antal
- status på svenska
- tydlig placeholder som förklarar att laguttagningen ännu inte har genererats

En användare utan lagbehörighet ska inte kunna avgöra om en match i ett annat lag existerar.

### Testdata och lokal användarresa

- Minst en syntetisk kommande match läggs till i seeddata.
- Testdata får inte innehålla riktiga motståndare, platser eller personuppgifter.
- Dokumentationen beskriver hur matchseed återställs lokalt.

## Ingår inte

- tabellen `match_players`
- generera, spara eller omfördela uttagningar
- anslutning till `generateRegularAllocation`
- `Lag`- och `Står över`-vyer
- ändra, radera eller ställa in en match
- manuella spelarbyten
- extra inhoppare
- markera match som genomförd
- deltagande eller spelarhistorik
- produktionsdata eller deployment

## Föreslagen kodstruktur

```text
src/
├── app/matches/                 routes, loading och error boundaries
├── features/matches/            query, validering, mutation och presentation
├── lib/supabase/                befintliga serverklienter
└── domain/allocation/           oförändrad i denna implementation

supabase/
├── migrations/                  matches-tabell, RLS och grants
├── seed.sql                     syntetisk match
└── tests/database/              schema- och RLS-tester
```

## Acceptanskriterier

### Databas och säkerhet

- Migrationerna kan appliceras från tom lokal databas.
- En match kan inte referera till en säsong i ett annat lag.
- Aktiv lagmedlem kan läsa och skapa lagets matcher.
- Icke-medlem kan varken läsa eller skapa lagets matcher.
- Anonym användare kan varken läsa eller skapa matcher.
- Aktiv medlem kan inte skapa match i en inaktiv säsong.
- Aktiv medlem kan inte skapa `completed` eller `cancelled` genom direkt Data API-insert.
- Autentiserad klient kan inte uppdatera eller permanent radera matcher.
- Schemat verifierar `unique (team_id, request_id)`, `unique (id, team_id)` och `updated_at`-triggern.

### Skapa match

- Giltigt formulär skapar exakt en `upcoming`-match i den aktiva säsongen.
- Tomt motståndarnamn, ogiltig tid och target under 1 avvisas utan databasskrivning.
- Uteslutet target-fält får det beräknade standardvärdet.
- Om target utelämnas och säsongen saknar aktiva spelare avvisas skapandet med ett praktiskt fel; ett positivt explicit target är fortfarande tillåtet.
- Plats kan utelämnas och lagras då som `null`.
- Två submit-försök med samma `request_id` skapar exakt en match och returnerar samma match-id.
- Samma `request_id` och ändrad payload ger konflikt utan att originalmatchen ändras.
- Samma `request_id` kan skapa varsin match i två olika lag när respektive användare är behörig.

### Läsvyer

- `Kommande` visar endast framtida `upcoming`-matcher i stigande ordning.
- `Alla` visar aktiva säsongens matcher i fallande ordning.
- Matchrad visar datum, tid, motståndare, `0 / target` och svensk status.
- Matchdetaljen visar rätt data för en behörig tränare.
- Okänd eller obehörig match ger samma generiska not-found-beteende.
- Loading, båda empty-varianterna, error och populated kan verifieras.
- Matchlista och formulär fungerar vid 390 px utan horisontell scroll.
- Formuläret kan användas med tangentbord och har kopplade labels samt tydliga fokusmarkeringar.

## Verifieringsplan

### Automatiskt

1. Kör `git diff --check`.
2. Kör lint och TypeScript-kontroll.
3. Testa validering, target-default, tidskonvertering och svensk presentation.
4. Kör pgTAP-test för schema, integritet, grants samt positiva och negativa RLS-fall.
5. Kör hela Vitest-sviten.
6. Kör produktionsbygget.

### Lokal användarresa

1. Öppna matchlistan som inloggad tränare.
2. Verifiera seedmatchen och båda filtren.
3. Skapa en match utan plats och med automatiskt target.
4. Verifiera omdirigering och matchdetalj.
5. Kontrollera matchen i listan.
6. Kontrollera mobil layout vid 390 px och tangentbordsflöde.
7. Verifiera att utomstående konto inte kan läsa eller skapa matchen.

### Oberoende granskning

En separat skrivskyddad agent granskar hela diffen mot `main`, inklusive ospårade filer, med fokus på RLS, dataintegritet, tidszon, formulärvalidering, state-hantering och scope.

## Stoppunkter

- Deployment och produktions-Supabase kräver separat godkännande.
- Ändring av matchstatus, permanent radering och uttagningspersistens kräver senare beslut/implementation.

## Definition av klar

Implementation 03 är klar när samtliga relevanta acceptanskriterier och projektets Definition of Done är verifierade, inga oaccepterade granskningsfynd återstår och genomförd verifiering har redovisats.
