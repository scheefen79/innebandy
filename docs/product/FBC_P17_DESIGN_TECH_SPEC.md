# FBC Sollentuna P17 – Designspecifikation och teknisk arkitektur

## 1. Syfte

Bygg en mycket enkel, responsiv webbtjänst för tränare som ersätter ett spreadsheet för matchfördelning.

Tjänsten ska göra tre saker väldigt bra:

1. Ge snabb överblick över kommande matcher.
2. Fördela matchplatser rättvist mellan spelare och samtidigt balansera lagen utifrån spelarnivå.
3. Ge enkel historik per spelare över tidigare och kommande matcher.

Produkten ska kännas som ett litet, snabbt planeringsverktyg – inte som ett komplett lagadministrationssystem.

---

## 2. Produktprinciper

- Mobile first.
- Enkelhet före funktionstäthet.
- Översikt före administration.
- Automatisk fördelning ska vara standard.
- Tränaren ska kunna justera manuellt.
- Spelarnivå används för balans, inte för att vissa ska få fler matcher.
- Planerad tränarnärvaro för inloggade lagmedlemmar.
- Ingen chatt, betalning eller lagkassa.
- Ingen separat adminpanel i MVP.

---

## 3. Primära användare

### Tränare

Behöver kunna:

- se nästa match
- se kommande matcher
- se vilka som ska spela
- se vilka som står över
- lägga till eller ta bort spelare
- ändra en spelares nivå
- se hur många matcher varje spelare har
- justera ett matchlag manuellt
- lägga till eller ta bort matcher

MVP kan utgå från ett lag och en säsong.

### Besökare

En besökare är en inloggad lagmedlem med rollen `viewer`. Besökaren behöver kunna:

- läsa översikt, träningar och matcher
- se spelarnas namn i en matchuttagning, inklusive vilka som spelar och står över

Besökaren får inte:

- se spelarnivåer
- nå spelarlistan, ett spelarkort eller spelarhistorik
- skapa, ändra eller ta bort lagdata; undantaget är att ange eller ändra den egna planerade tränarnärvaron

Ett spelarnamn får exponeras för besökaren endast i sitt matchsammanhang. Besökaren får inte kunna hämta spelaren som en fristående resurs. Begränsningen ska upprätthållas i databas och serverlogik, inte enbart genom dold navigation.

---

## 4. Informationsarkitektur

Bottom navigation på mobil:

- Tränare: Översikt, Träningar, Närvaro, Matcher och Spelare
- Besökare: Översikt, Träningar, Närvaro och Matcher

Desktop använder samma rollanpassade huvudvyer i en enkel sidomeny eller toppnavigation.

---

# 5. Designriktning

Utgå visuellt från den godkända mobilskissen i konversationen.

## Stil

- modern sportapp
- ljus bas
- mörk marinblå header
- tydliga vita kort
- mycket luft
- minimalt antal färger
- tydliga statusindikatorer
- rundade kort och knappar
- diskreta skuggor

Designen får gärna ha samma premiumkänsla som CopaBet-referensen, men utan betting-associationer.

## Färger

- Primär marinblå: `#082B4C`
- Primär blå: `#1677FF`
- Bakgrund: `#F5F7FA`
- Kort: `#FFFFFF`
- Text primär: `#0F172A`
- Text sekundär: `#64748B`
- Grön: `#16A34A`
- Orange: `#F59E0B`
- Röd: `#DC2626`
- Border: `#E2E8F0`

## Typografi

Använd systemfont eller Inter.

- Page title: 24–28 px / semibold
- Card title: 18–20 px / semibold
- Body: 14–16 px
- Metadata: 12–14 px
- KPI/tal: 24–32 px / bold

## Spacing

- basenhet: 4 px
- mellan kort: 16 px
- padding i kort: 16–20 px
- större sektioner: 24 px
- mobil sidpadding: 16 px

## Radie

- cards: 16 px
- buttons: 10–12 px
- pills/status: 999 px

---

# 6. Mobilvyer

## 6.1 Översikt

Syfte: ge tränaren svar på “vad händer härnäst?” på några sekunder.

### Header

Visa:

- lag: P17
- säsong: Hösten 2026

### Nästa match

Stort kort med:

- matchrubrik i formatet `FBC vs. [motståndare]`
- FBC Sollentunas och motståndarens föreningslogotyper
- datum
- tid
- plats om angivet
- antal uttagna
- CTA: `Visa laget`

Exempel:

**Vallentuna IBK**  
Sön 27 sep 09:00  
Sollentunahallen  
18 spelare uttagna

### Kommande matcher

Visa nästa 4–5 matcher kompakt:

- datum
- motståndare med föreningslogotyp

### Matchfördelning

Visa en enkel fördelningsindikator, exempelvis:

- 4 matcher – 8 spelare
- 5 matcher – 15 spelare
- 6 matcher – 1 spelare

Visa varning bara om fördelningen avviker tydligt.

---

## 6.2 Matcher

### Header

- titel: `Matcher`
- plus-knapp för ny match

### Tabs

- Kommande
- Alla

### Matchrad

Visa:

- datum
- motståndare
- tid
- antal uttagna / målantal
- status

Klick öppnar matchdetalj.

---

## 6.3 Match – laguttagning

### Header

- tillbaka
- motståndare
- datum
- tid
- plats

### Tabs

- Lag
- Står över

### Spelarrad

Visa:

- namn
- nivå, endast för tränare
- eventuellt antal matcher hittills, endast för tränare

### Justera laget

CTA längst ned:

`Justera laget`

I redigeringsläge:

- välj spelare att ta bort
- välj ersättare
- visa direkt hur många matcher båda spelarna har

Fas 2 öppnas via `Starta matchveckan` och `Hantera matchveckan`. Den visar kallelser och svar, reserverade platser, kandidatstatistik och låsning/rättning. Kapacitet och behörighet upprätthålls även i databasen.

Besökare ser matchuttagningen utan redigeringskontroller och utan nivåer eller historikmått.

---

## 6.4 Spelare

Vyn är endast tillgänglig för tränare. Besökare ska nekas även vid direkt navigation.

### Header

- titel: `Spelare`
- plus-knapp

### Sök

En enkel sökruta.

### Spelarrad

Visa:

- namn
- nivå
- erbjudna ordinarie, spelade ordinarie, spelade extra, totalt spelade och framtida planerade
- tydlig markering när erbjudandehistoriken är ofullständig

Klick öppnar spelarkort.

---

## 6.5 Spelarkort

Vyn är endast tillgänglig för tränare. Besökare får inte kunna läsa spelarprofil eller spelarhistorik genom UI, route eller direkt dataanrop.

Visa:

- namn
- nivå
- CTA `Ändra`
- antal matcher totalt
- kommande matcher
- tidigare matcher

Nivå ändras här, inte i huvudlistan.

Ingen avancerad statistik.

---

# 7. Desktop

Desktop ska inte vara en separat produkt.

Samma informationsarkitektur används.

Rekommenderad layout:

- vänster navigation
- huvudkolumn
- sekundär kolumn för matchfördelning eller snabbinfo

Undvik stora dashboards med många KPI-kort.

---

# 8. Kärnflöden

## 8.1 Skapa säsong

1. skapa säsong
2. lägg till spelare
3. sätt nivå 1–3
4. lägg till matcher
5. generera fördelning

Efter detta ska det mesta vara automatiskt.

## 8.2 Lägg till spelare

Fält:

- förnamn
- efternamn
- nivå 1–3

## 8.3 Ta bort spelare

Använd soft delete: `active = false`.

Historiska matchkopplingar ska behållas.

## 8.4 Ändra nivå

Ändring sker från spelarkortet.

Nivå 1 är högst och nivå 3 är lägst.

Nivån används vid nästa uttryckliga omfördelning och endast för att balansera ordinarie matchtrupper. Den får inte påverka hur många ordinarie matcher eller extra inhopp en spelare får.

Ingen nivåhistorik behövs i MVP.

## 8.5 Lägg till match

Datum, tid, motståndare, valfri plats och önskad storlek på grundplanen. Standard är tio (ADR-019). Nya grundplaner och matchveckor har högst tio platser totalt inklusive extra.

## 8.6 Generera grundplan – fas 1

Skapa en deterministisk plan för hela säsongen: jämn fördelning av erbjudna ordinarie plus framtida planerade platser, exakt önskat antal i varje grundplan, proportionell nivåbalans, väntetid och fast säsongsrotation. Nivå påverkar inte totalantalet. Äldre ej inställda matchers erbjudanden måste först kompletteras och bekräftas manuellt. Befintliga uttagningar är endast förslag till denna historik.

## 8.7 Starta och hantera matchveckan – fas 2

Före matchveckan kan tränaren justera ordinarie grundplan med kopplade byten som bevaras vid omfördelning. `Starta matchveckan` fryser planen och undantar matchen från generering. Kallelser skickas samma vecka i ett annat verktyg. Sanna registrerar status per spelare: ej kallad, inväntar svar, tackat ja, tackat nej eller indragen. Flera ändringar sparas atomiskt.

En ordinarie plats räknas som erbjuden först när kallelsen markeras som skickad. Nej och indragning raderar inte erbjudandet; återaktivering dubbelräknas inte. Återbud kräver ingen omedelbar ersättare. Ja och väntande svar reserverar tillsammans högst tio platser inklusive extra. Matchveckan visar ja, väntande och lediga platser.

## 8.8 Kalla extra spelare

Spelare utanför den frysta grundplanen är extra. Rekommendationen prioriterar genomförda extra, erbjudna ordinarie, tid sedan senaste extra och fast rotation. Nivå påverkar inte ordningen. Tränaren kan välja en annan aktiv kandidat; nej och indragna kallelser måste återaktiveras uttryckligen. Endast faktiskt spelad extra medverkan ökar extraräknaren.

## 8.9 Lås och rätta deltagande

Truppen kan ändras även efter start fram till låsning. Efter start registreras ett till tio faktiska deltagare atomiskt. Väntande svar måste först hanteras; noll deltagare hanteras som inställd match. Sena aktiva deltagare kan läggas till. Spelad ordinarie respektive extra medverkan hålls åtskild från plan och erbjudanden.

Coach kan rätta låst deltagande med obligatorisk anledning. Före/efter, aktör och tidpunkt bevaras. Ingen framtida plan ändras automatiskt. Äldre genomförda matcher behåller sin historik tills en uttrycklig rättning görs.

## 8.10 Omfördela framtida grundplaner

Fördelningen ändras aldrig automatiskt när trupp, matcher, platser eller nivåer ändras. Tränaren väljer nästa eller en vald framtida grundplan som start. Genomförda, inställda, tidigare planerade och frysta matchveckor samt manuella beslut bevaras.

---

# 9. Uttagningsalgoritm

## Input

- aktiva spelare
- nivå per spelare
- matcher
- target roster size per match
- redan manuellt låsta uttagningar

## Grundprincip

Minimera skillnaden mellan spelarnas erbjudna ordinarie platser plus bevarade framtida grundplaner. Inställda matcher undantas.

Sekundärt mål: matchtruppen ska spegla truppens nivåfördelning så nära som möjligt.

## Deterministisk ordinarie rotation

Algoritmen använder ingen viktad scoring och ingen slump. Den ska:

1. beräkna den jämnaste möjliga ordinarie säsongsfördelningen
2. beräkna proportionella nivåkvoter för varje match
3. rotera spelare inom nivågrupperna
4. prioritera längst väntetid mellan i övrigt likvärdiga spelare
5. använda en fast säsongsrotation som sista utslagsregel

Samma input ska alltid ge samma resultat. Den fasta rotationen får inte baseras på alfabetisk namnordning.

## Separat extrarotation

Extra påverkar inte framtida ordinarie fördelning. Erbjudna ordinarie används som sekundärt utslagsmått efter genomförda extra. Se ADR-023.

## Krav

Efter full fördelning:

- skillnaden mellan max och min antal matcher per spelare bör normalt vara max 1
- varje match ska ha rätt antal spelare
- nivåfördelningen ska vara så nära truppens totala nivåfördelning som möjligt
- manuella beslut ska överleva omfördelning
- extra inhopp ska fördelas separat och rättvist

Om en perfekt fördelning inte är möjlig ska systemet visa ett tydligt fel eller en varning. Grundplanen får inte bli ofullständig tyst eller skriva över manuella beslut. Matchveckan tillåter uttryckligen färre än tio deltagare.

---

# 10. Teknisk arkitektur

## Rekommenderad stack

- Frontend + server: **Next.js**
- Databas + auth: **Supabase**
- Databas: **PostgreSQL**
- Hosting: **Vercel**
- Styling: **Tailwind CSS**

Undvik tung state management i MVP.

---

# 11. Arkitekturöversikt

```text
Browser
   |
   v
Next.js
   |
   +---- Server Actions / API routes
   |
   v
Supabase
   |
   +---- PostgreSQL
   |
   +---- Auth
```

MVP behöver ingen separat backendtjänst.

---

# 12. Datamodell

## teams

```sql
id uuid primary key
name text not null
created_at timestamptz
```

## seasons

```sql
id uuid primary key
team_id uuid references teams(id)
name text not null
start_date date
end_date date
active boolean default true
rotation_seed uuid not null
```

## team_members

```sql
id uuid primary key
team_id uuid references teams(id)
user_id uuid references auth.users(id)
role text check (role in ('coach'))
active boolean default true
created_at timestamptz

unique(team_id, user_id)
```

## players

```sql
id uuid primary key
team_id uuid references teams(id)
first_name text not null
last_name text
level smallint check (level between 1 and 3)
active boolean default true
created_at timestamptz
updated_at timestamptz
```

## matches

```sql
id uuid primary key
season_id uuid references seasons(id)
opponent text not null
match_date timestamptz not null
location text
target_players integer
status text
created_at timestamptz
updated_at timestamptz
```

## match_players

```sql
id uuid primary key
match_id uuid references matches(id)
player_id uuid references players(id)
selection_type text check (selection_type in ('regular', 'extra'))
selection_source text check (selection_source in ('automatic', 'manual'))
selection_status text check (selection_status in ('selected', 'removed'))
played boolean default false
manual_override boolean default false
replaced_player_id uuid references players(id)
created_at timestamptz
updated_at timestamptz

unique(match_id, player_id)
```

---

## Matchveckans tabeller (ADR-023)

- `match_workflows`: match, lag, säsong, fas, revision och historikgranskning.
- `match_calls`: spelare, fryst grundplantillhörighet, erbjuden ordinarie och kallelsesvar.
- `match_participation`: faktisk spelare och ordinarie/extra efter låsning.
- `match_workflow_events`: åtgärd, anledning, före/efter, aktör, tidpunkt, revision och request-id.

Alla relationer verifierar lag och säsong. Coachbegränsad RLS-läsning, server-only atomiska mutationer och skydd av fryst `match_players`-plan. Gemensamma läsmodeller förhindrar dubbelräkning av äldre och nytt deltagande.

# 13. Matchstatus

Använd endast:

- upcoming
- completed
- cancelled

I UI visas dessa som `Planerad`, `Genomförd` och `Inställd`. Separat matchfas är grundplan, matchvecka, låst eller äldre historik. Kallelser har egna svar; faktisk medverkan registreras separat.

---

# 14. Server actions / API

## Players

- getPlayers
- createPlayer
- updatePlayer
- deactivatePlayer

## Matches

- getMatches
- getMatch
- createMatch
- updateMatch
- deleteMatch
- cancelMatch

## Selection

- generateSeasonAllocation
- regenerateFutureAllocation
- swapPlayer
- addExtraPlayer
- resetManualChange
- suggestExtraPlayers
- get_match_workflow (coach)
- save_match_workflow (server-only): start, responses, history, lock, correct, cancel

---

# 15. Viktiga queries

## Spelarlista

Returnera:

- namn
- nivå
- erbjudna ordinarie platser
- spelade ordinarie och spelade extra
- totalt faktiskt spelade
- framtida planerade platser
- flagga för ofullständig erbjudandehistorik

Sök och sortering, mobilkort och jämförbar desktoptabell.

## Spelarkort

Returnera:

- spelarinfo
- tidigare matcher
- kommande matcher
- ordinarie tilldelningar
- genomförda ordinarie matcher
- genomförda extra inhopp

## Match

Returnera:

- matchdata
- uttagna
- står över
- extra inhoppare
- nivåfördelning

## Översikt

Returnera:

- nästa match
- nästa 5 matcher
- distribution av antal matcher per spelare

---

# 16. Auth

MVP har tre tränare med varsitt användarkonto och gemensam åtkomst till samma lag. Inloggade besökare kan läggas till med begränsad läsåtkomst.

Rekommenderat:

- Supabase Auth
- magic link eller email/password

Användarna kopplas till laget genom `team_members` med rollen `coach` eller `viewer`. MVP innehåller ingen sida för att bjuda in eller administrera medlemmar; medlemskapen skapas vid initial uppsättning.

Ingen publik spelarsida, spelarinloggning eller föräldrainloggning införs. `viewer` är en autentiserad lagroll och får endast den begränsade lagyta som definieras i avsnitt 3.

---

# 17. Säkerhet och data

MVP hanterar begränsad persondata.

Minimera lagrad data:

- namn
- spelarnivå
- matchkopplingar

Lagra inte:

- personnummer
- adresser
- telefonnummer
- medicinsk information

Använd Row Level Security i Supabase.

En användare ska endast komma åt lag och funktioner som dess aktiva medlemskap och roll tillåter. `viewer` får inte få spelarnivå eller individuell spelarhistorik i databas-, server- eller nätverkssvar.

Row Level Security ska kontrollera ett aktivt medlemskap i `team_members`. Säkerheten ska testas både positivt och negativt.

---

# 18. Responsivitet

## Mobil

Primär målplattform.

- bottom navigation
- single-column
- stora touch targets
- inga tabeller

## Tablet

- single-column eller 2-column cards

## Desktop

- sidebar
- max-width container
- möjlighet till 2-column layout

---

# 19. Komponenter

Bygg följande återanvändbara komponenter:

```text
AppShell
BottomNav
DesktopNav
PageHeader
MatchCard
MatchListItem
MatchDistribution
PlayerListItem
PlayerCard
LevelBadge
SegmentedControl
StatusBadge
EmptyState
ConfirmDialog
```

Håll komponentbiblioteket litet.

---

# 20. Design states

Alla centrala vyer ska ha:

- loading
- empty
- error
- populated

Exempel tom spelarlista:

`Inga spelare ännu`

CTA:

`Lägg till spelare`

---

# 21. Microcopy

Tonen ska vara kort och praktisk.

Använd:

- Visa laget
- Lägg till spelare
- Ändra nivå
- Justera laget
- Generera fördelning
- Står över
- Kommande matcher
- Tidigare matcher

Undvik tekniska termer i gränssnittet.

---

# 22. MVP-scope

## Ska byggas

- login
- ett lag
- en aktiv säsong
- spelarlista
- lägg till spelare
- ta bort/deaktivera spelare
- nivå 1–3
- matchlista
- skapa match
- automatisk matchfördelning
- manuell justering
- spelarhistorik
- mobil + desktop responsivitet

## Ska inte byggas

- träningsschema
- spelarnärvaro eller träningskallelser
- pushnotiser
- e-post
- SMS
- föräldrakonton
- spelarlogin
- målstatistik
- poängstatistik
- matchresultat
- lagkassa
- chat
- dokument
- kalenderintegration
- avancerad RBAC
- flera föreningar
- rapportgenerator

---

# 23. Implementation order

## Fas 1 – Data och grund

1. skapa Next.js-projekt
2. konfigurera Supabase
3. skapa databasmodellen
4. seed med testdata
5. auth

## Fas 2 – Läsflöden

1. AppShell
2. Översikt
3. Matcher
4. Spelare
5. Spelarkort
6. Matchdetalj

## Fas 3 – CRUD

1. skapa spelare
2. ändra spelare
3. deaktivera spelare
4. skapa match
5. ändra match
6. ta bort match

## Fas 4 – Fördelningsmotor

1. fairness
2. nivåbalans
3. rotation
4. säsongsfördelning
5. manuell swap

## Fas 5 – Polish

1. responsive QA
2. loading states
3. empty states
4. error states
5. accessibility
6. performance

---

# 24. Acceptance criteria

## Översikt

- nästa match syns direkt
- kommande matcher kan öppnas
- matchfördelning visas
- fungerar på mobil utan horisontell scroll

## Matcher

- alla kommande matcher visas
- ny match kan skapas
- match kan öppnas

## Matchdetalj

- uttagna syns
- står över syns
- tränare kan byta spelare manuellt

## Spelare

- spelare kan läggas till
- spelare kan deaktiveras
- nivå kan ändras
- antal matcher visas

## Spelarkort

- kommande matcher visas
- tidigare matcher visas
- nivå kan ändras

## Fördelning

- varje grundplan får target antal spelare; matchveckan tillåter färre
- sex återbud från tio ordinarie och fem extra ger nio deltagare: tio erbjudna ordinarie, fyra spelade ordinarie och fem spelade extra
- nej/indragning bevarar erbjudandet, återaktivering dubbelräknas inte
- högst tio ja/väntande tillsammans; obesvarade måste hanteras före låsning
- låst deltagande kan rättas med anledning och revisionshistorik
- historikspärr och ofullständig statistik visas tydligt
- viewers nekas matchveckans svar och individuell statistik
- skillnaden i antal matcher per spelare är så liten som möjligt
- nivåerna fördelas balanserat
- manuell ändring är möjlig
- ordinarie matcher och extra inhopp redovisas och fördelas separat
- extra inhopp rekommenderas efter lägst antal genomförda inhopp, därefter lägst antal erbjudna ordinarie platser och längst väntetid, utan hänsyn till nivå
- samma input ger samma automatiska fördelning
- manuella ändringar bevaras vid omfördelning

---

# 25. Codex-instruktion

Bygg tjänsten iterativt.

Prioritera:

1. enkelhet
2. mobil UX
3. tydlighet
4. korrekt fördelningslogik
5. stabil datamodell

Undvik att lägga till funktioner som inte finns i denna spec.

När det finns flera möjliga tekniska lösningar: välj den enklaste som håller för MVP.

Skapa inte extra dashboards, adminpaneler eller inställningssidor om de inte behövs för kärnflödet.
