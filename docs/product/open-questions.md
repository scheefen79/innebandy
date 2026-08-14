# Öppna produkt- och teknikfrågor

Frågorna nedan behöver avgöras före eller under den första milstolpen. De är prioriterade efter hur tidigt de påverkar arkitekturen.

## Måste avgöras före implementation

### 0. Inloggningsmetod

**Beslut:** MVP använder e-post och lösenord med tre manuellt skapade Supabase Auth-konton. Magic link avvaktas för att undvika beroende av produktions-SMTP och e-postcallback i denna fas. Sessionsarkitekturen dokumenteras i ADR-004.

### 1. Tränare och lagbehörighet

**Beslut:** De tre tränarna har varsitt användarkonto och delar åtkomst till samma lag. Användarna kopplas till laget genom `team_members` med rollen `coach`.

Datamodellen får stödja fler tränare, men MVP innehåller ingen sida för inbjudningar eller medlemsadministration. De första tre kontona kopplas till laget vid initial uppsättning. Row Level Security ska utgå från medlemskapet i `team_members`.

### 2. Betydelsen av spelarnivå

**Beslut:** Nivå 1 är högst och nivå 3 är lägst.

Nivån används för att skapa balanserade matchtrupper och får inte påverka hur många matcher en spelare tilldelas. UI, seeddata, tester och förklarande text ska använda samma riktning på skalan.

### 3. Genomförd match

**Beslut:** Ordinarie matcher och extra inhopp följer två separata rättvisestrukturer.

- Ordinarie uttagningar fördelas enligt säsongens vanliga rotations- och nivåbalansregler.
- Extra inhopp fördelas i en separat rotation så att samma spelare inte återkommande får extramatcherna.
- Ett extra inhopp påverkar inte spelarens framtida ordinarie matchfördelning.
- En ordinarie uttagning påverkar inte spelarens prioritet i rotationen för extra inhopp.
- När en match markeras som genomförd registreras ordinarie uttagna och extra inkallade som spelade som standard. Tränaren kan markera återbud eller frånvaro individuellt.
- Endast ett faktiskt genomfört extra inhopp ökar spelarens inhoppsräknare.
- Förfrågningar och avböjanden registreras inte i MVP.
- Spelarnivå påverkar inte rekommendationen av extra inhoppare. Nivå används endast för den ordinarie lagbalansen.

Prioriteringsordning för extra inhopp:

1. Färst genomförda extra inhopp.
2. Längst tid sedan senaste genomförda extra inhopp.
3. Säsongens fasta, reproducerbara rotationsordning som sista utslagsregel.

Tränaren kan alltid välja en annan tillgänglig spelare än den som appen rekommenderar.

Spelarkort och matchhistorik ska därför skilja mellan ordinarie tilldelningar, extra inhopp och faktiskt spelade matcher.

### 4. Borttagning av match

**Beslut:** En felaktigt skapad framtida match utan uttagning får raderas permanent. En match som har ingått i fördelningen ska normalt markeras som `cancelled`, och en genomförd match får inte raderas direkt.

- En inställd match räknas inte som en ordinarie match för spelarna.
- Inställning av en match utlöser inte automatisk omfördelning.
- Appen visar i stället att fördelningen kan ha blivit ojämn och erbjuder `Omfördela framtida matcher`.
- Manuella låsningar ska bevaras vid omfördelning.

## Måste avgöras före fördelningsmotorn

### 5. Manuella låsningar

**Beslut:** Manuella ändringar bevaras automatiskt vid framtida omfördelning. Låsningen är ett internt systembeteende och ska inte kräva att tränaren förstår eller administrerar tekniska låstyper.

UI:t har två separata flöden:

1. `Justera ordinarie lag` flyttar en ordinarie matchplats mellan spelare. Den tillagda spelaren räknas som ordinarie och den borttagna spelaren får inte den ordinarie matchen.
2. `Lägg till extra inhoppare` registrerar en extra match utanför den ordinarie fördelningen och påverkar endast den separata extrarotationen efter genomförd match.

Appen visar ändrade spelare som `Manuellt tillagd`, `Manuellt borttagen` eller `Extra inhoppare`. Tränaren kan välja `Återställ manuellt byte`, varefter systemet åter får bestämma uttagningen automatiskt.

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
- genomförda ordinarie matcher används när rättvisan för återstående matcher beräknas
- extra inhopp hålls separat från den ordinarie fördelningen

### Match- och deltagandestatus

Kommande uttagningar är `Planerad` fram till att matchen har spelats. Det finns ingen status `Bekräftad` före matchen.

Matchstatus:

- `Planerad` – matchen är kommande och uttagningen kan ändras.
- `Genomförd` – matchen har spelats och deltagandet har sparats.
- `Inställd` – matchen blev inte spelad.

När en match markeras som genomförd föreslår appen att alla ordinarie uttagna och registrerade extra inhoppare deltog. Tränaren korrigerar eventuella återbud och sparar sedan deltagandet.

Deltagandestatus per spelare:

- `Spelade`
- `Deltog inte`
- `Extra inhoppare`

Först när deltagandet sparas uppdateras historiken och räknaren för genomförda extra inhopp.

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
