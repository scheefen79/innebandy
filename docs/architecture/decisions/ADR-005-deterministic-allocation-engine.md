# ADR-005: Ren och deterministisk fördelningsmotor

- Status: Accepterad
- Datum: 2026-08-17

## Kontext

Rättvis matchfördelning är produktens viktigaste affärsregel. Om logiken byggs direkt i UI, databasfrågor eller mutationer blir den svårare att förstå, verifiera och ändra. Ordinarie matcher och extra inhopp har dessutom olika rättviseregler och får inte påverka varandra.

## Beslut

- Fördelningslogiken implementeras som rena TypeScript-funktioner under `src/domain/allocation/`.
- Funktionerna tar fullständig, explicit input och returnerar nya outputobjekt utan att mutera input eller extern state.
- Domänmodulen får inte läsa aktuell tid, använda slump, anropa nätverk eller importera Next.js, React eller Supabase.
- Match- och spelar-id:n samt `rotationOrder` används för stabil identitet och deterministisk utslagsordning. Spelarnamn används aldrig som tie-breaker.
- Ordinarie fördelning och extra rekommendation implementeras som separata funktioner med separata historikfält.
- Omfördelning uttrycks som ett suffix av matcher plus en rättvise-baseline som inkluderar både antal och senaste genomförda eller bevarade ordinarie tilldelning före suffixet. Domänmotorn kan därmed inte ändra frysta matcher.
- Ordinarie nivå används endast för matchernas sammansättning, aldrig för att ge fler ordinarie matcher totalt.
- Manuella ordinarie tillägg och borttagningar är explicita inputbegränsningar som måste bevaras.
- Applikationslagret ansvarar för att extrafunktionen endast får aktiva och valbara kandidater som inte redan är uttagna i den aktuella matchen.
- Förväntade avvikelser returneras som stabila, strukturerade varningskoder. Ogiltig eller omöjlig input returneras som stabila felkoder utan partiellt nytt resultat.
- Persistens, transaktioner och behörighetskontroll tillhör senare applikations- och datalager.

## Konsekvenser

- Domänmotorn kan verifieras med snabba, deterministiska tester utan lokal Supabase.
- Samma motor kan senare användas av serverlogik, förhandsgranskning och omfördelning utan duplicerade regler.
- Alla uppgifter som påverkar resultatet måste uttryckas i input; dolda databas- eller tidsberoenden tillåts inte.
- Applikationslagret ansvarar senare för att läsa historik, skapa input, spara hela resultatet atomiskt och översätta koder till svensk UI-text.
- Ett strukturerat fel innebär att applikationslagret behåller samtliga befintliga uttagningar; ett partiellt domänresultat får aldrig sparas.
- Kontraktet behöver versionsmedveten migrering om framtida produktregler ändrar betydelsen av historik eller manuella beslut.

## Alternativ

- Algoritm i React-komponenter: avvisas eftersom presentation och rättviselogik då inte kan testas eller ändras oberoende.
- PostgreSQL-funktion: avvaktas eftersom det binder iteration och tester till databasen innan kontraktet är stabilt.
- Slumpmässig lottning: avvisas eftersom samma input måste ge samma resultat och tränaren ska kunna förstå rotationen.
- En gemensam poängmodell för ordinarie och extra matcher: avvisas eftersom produkten kräver två oberoende rättvisesystem utan viktad scoring.
