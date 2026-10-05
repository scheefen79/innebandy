# Öppna produkt- och teknikfrågor

Frågorna nedan behöver avgöras före eller under den första milstolpen. De är prioriterade efter hur tidigt de påverkar arkitekturen.

## Måste avgöras före implementation

### 0. Inloggningsmetod

**Beslut:** MVP använder e-post och lösenord med tre manuellt skapade Supabase Auth-konton. Magic link avvaktas för att undvika beroende av produktions-SMTP och e-postcallback i denna fas. Sessionsarkitekturen dokumenteras i ADR-004.

### 1. Tränare och lagbehörighet

**Beslut:** De tre tränarna har varsitt användarkonto och delar åtkomst till samma lag. Användarna kopplas till laget genom `team_members` med rollen `coach`. Rollen `viewer` används för inloggade besökare med begränsad läsåtkomst.

Datamodellen får stödja fler tränare och besökare, men MVP innehåller ingen sida för inbjudningar eller medlemsadministration. Kontona kopplas till laget vid initial uppsättning. Row Level Security ska utgå från medlemskapet och rollen i `team_members`.

`coach` får läsa och administrera all lagdata. `viewer` får läsa översikt, träningar, matcher och spelarnamn i matchuttagningar, men får inte se spelarnivåer, spelarlistan, spelarprofiler eller spelarhistorik. Båda aktiva rollerna får ange och ändra endast sin egen planerade tränarnärvaro samt se närvaroöversikten. Ett spelarnamn får exponeras för `viewer` endast som del av en matchuttagning. ADR-016 och ADR-018 beskriver säkerhetsgränserna.

### 2. Betydelsen av spelarnivå

**Beslut:** Nivå 1 är högst och nivå 3 är lägst.

Nivån används för att skapa balanserade matchtrupper och får inte påverka hur många matcher en spelare tilldelas. UI, seeddata, tester och förklarande text ska använda samma riktning på skalan.

### 3. Kallelser och faktisk medverkan

**Beslut 2026-10-05:** ADR-023 ersätter tidigare beslut om att inte registrera förfrågningar och avböjanden. Generatorn skapar grundplanen; matchveckan fryser planen och registrerar externt skickade kallelser samt svar. En skickad ordinarie kallelse räknas en gång även vid nej/indragning. Inställda matcher undantas. Extra-ranking är genomförda extra, erbjudna ordinarie, senaste extra och fast rotation; nivå används endast för balans.

Ja och väntande svar reserverar högst tio platser inklusive extra. Återbud kräver ingen ersättare. Ett till tio faktiska deltagare låses efter start när väntande svar hanterats; noll innebär inställd match. Coach kan rätta med obligatorisk anledning och revisionshistorik. Äldre erbjudanden kompletteras och bekräftas manuellt innan generering, och ofullständig historik märks i statistik. Ingen extern integration införs.

### 4. Borttagning av match

**Beslut:** En felaktigt skapad framtida match utan uttagning får raderas permanent. En match som har ingått i fördelningen ska normalt markeras som `cancelled`, och en genomförd match får inte raderas direkt.

- En inställd match räknas inte som en ordinarie match för spelarna.
- Inställning av en match utlöser inte automatisk omfördelning.
- Appen visar i stället att fördelningen kan ha blivit ojämn och erbjuder `Omfördela framtida matcher`.
- Manuella låsningar ska bevaras vid omfördelning.

## Måste avgöras före fördelningsmotorn

### 5. Manuella låsningar

**Beslut:** Manuella ändringar bevaras automatiskt vid framtida omfördelning. Låsningen är ett internt systembeteende och ska inte kräva att tränaren förstår eller administrerar tekniska låstyper.

Före matchveckan kan grundplanen justeras med bevarade, kopplade ordinarie byten. Efter `Starta matchveckan` hanteras varje kallelse och svar oberoende och sparas atomiskt. Grundplanen fryses och omfördelas inte. ADR-023 ersätter tidigare fas 2-flöde med extra utanför målantalet.

### 6. Omfördelning efter förändringar

**Beslut:** Appen ändrar aldrig en redan genererad fördelning automatiskt när spelartruppen, matchschemat, antalet platser eller en spelares nivå ändras. Den visar att fördelningen behöver uppdateras och erbjuder en uttrycklig omfördelning.

Tränaren väljer från vilken planerad match omfördelningen ska börja:

- nästa planerade match
- en vald framtida match

Vid omfördelning:

- genomförda och inställda matcher ändras aldrig
- matcher före den valda startmatchen ändras inte
- manuella ändringar bevaras
- endast automatiskt tilldelade platser får räknas om
- erbjudna ordinarie och bevarad framtida grundplan används när rättvisan för återstående matcher beräknas
- påbörjade matchveckor undantas från generering
- extra inhopp hålls separat från den ordinarie fördelningen

### Match- och deltagandestatus

Matchstatus är fortsatt `upcoming`, `completed` eller `cancelled`. Separat matchfas är grundplan, matchvecka, låst eller äldre historik. Kallelsestatus är ej kallad, inväntar svar, tackat ja, tackat nej eller indragen. Ja är ett svar på kallelsen; faktisk medverkan registreras separat. Endast faktiskt deltagande ökar genomförda matcher och extra.

### 7. Oavgjorda kandidater

**Beslut:** Den ordinarie fördelningen använder en deterministisk prioriteringsordning som vidareutvecklar spreadsheetets rotation inom nivågrupperna:

1. Fördela det totala antalet ordinarie matcher så jämnt som matematiken tillåter.
2. Fyll exakt önskat antal platser i varje match.
3. Fördela nivå 1–3 proportionellt och så balanserat som möjligt i varje match.
4. Mellan likvärdiga spelare prioriteras den som väntat längst sedan sin senaste ordinarie match.
5. Om kandidater fortfarande är likvärdiga används säsongens fasta, reproducerbara rotationsordning.

Nivå 1 är högst och nivå 3 lägst, men nivån får aldrig ge en spelare fler ordinarie matcher totalt. Den används endast för att balansera matchtrupperna.

Den sista utslagsregeln får inte bygga på alfabetisk ordning eftersom samma spelare då systematiskt kan gynnas. Samma input ska alltid ge samma resultat.

### 8. Omöjliga fördelningar

**Beslut:** Appen får aldrig tyst skapa ett ofullständigt lag eller ignorera tränarens manuella beslut.

- Om en matchs antal platser överstiger antalet aktiva spelare stoppas den nya genereringen för matchen med ett tydligt fel. Befintliga uttagningar och andra matcher ändras inte.
- Om en nivågrupp är för liten för önskad nivåbalans fylls platserna från övriga nivåer. Matchen skapas med en varning om avvikande nivåbalans.
- Om en helt jämn matchfördelning är matematiskt omöjlig tillåts den minsta möjliga skillnaden, normalt högst en ordinarie match.
- Om manuella ändringar gör en jämn fördelning omöjlig bevaras tränarens val och appen visar hur rättvisan påverkas.
- En spelare som saknar nivå ingår inte i automatisk fördelning. Appen visar att nivå måste anges.
- Om manuella borttagningar lämnar för få tillgängliga spelare stoppas omfördelningen för den berörda matchen utan att skriva över dess befintliga uttagning.

## Designunderlag som saknas

### 9. Godkänd mobilskiss

Specifikationen hänvisar till en mobilskiss och en CopaBet-referens. Lägg originalbilder eller länkar i repot innan detaljerad UI-implementation börjar.

## Beslutslogg

När en fråga avgörs:

1. skriv beslutet här
2. skapa ett ADR i `docs/architecture/decisions/` om beslutet påverkar arkitekturen
3. uppdatera specifikationen endast om produktkravet faktiskt ändras
