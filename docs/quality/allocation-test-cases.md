# Exempelbaserade testfall för matchfördelning

Dokumentet beskriver observerbart beteende. Testerna ska implementeras mot en ren, deterministisk domänmodul.

## Ordinarie fördelning

### O1: Jämn fördelning från referensarket

Givet 23 aktiva spelare, nio matcher och tolv platser per match finns 108 ordinarie matchplatser.

Förväntat:

- varje match får exakt 12 spelare
- varje spelare får 4 eller 5 ordinarie matcher
- skillnaden mellan högsta och lägsta antal är 1
- totalt antal tilldelningar är 108

### O2: Nivå påverkar inte total rättvisa

Givet spelare på nivå 1–3 och ett matematiskt jämnt antal platser.

Förväntat:

- nivå används för matchernas sammansättning
- ingen spelare får fler ordinarie matcher enbart på grund av sin nivå

### O3: Längst väntetid avgör lika läge

Givet två likvärdiga spelare på samma nivå och med lika många ordinarie matcher, där spelare A väntat längre sedan senaste ordinarie match.

Förväntat: spelare A prioriteras.

### O4: Deterministiskt resultat

Givet exakt samma spelare, matcher, rotation och manuella beslut i två körningar.

Förväntat: båda körningarna ger identiska uttagningar.

### O5: Nivågrupp kan inte fylla sin kvot

Givet att en nivågrupp har färre tillgängliga spelare än sin beräknade kvot.

Förväntat:

- matchen fylls från övriga nivågrupper
- exakt target-antal väljs
- resultatet innehåller en varning om avvikande nivåbalans

## Extra inhopp

### E1: Lägst antal inhopp prioriteras

Givet spelare A med 0, B med 1 och C med 2 genomförda extra inhopp.

Förväntat: A rekommenderas först oberoende av spelarnivå.

### E1b: Ordinarie antal bryter lika extrahistorik

Givet två spelare med lika många genomförda extra inhopp men 4 respektive 5 ordinarie matcher.

Förväntat: spelaren med 4 ordinarie matcher rekommenderas först.

### E2: Längst väntetid avgör lika antal

Givet A och B med ett genomfört extra inhopp var, där A:s inhopp skedde tidigare.

Förväntat: A rekommenderas före B.

### E3: Förfrågan eller nej räknas inte

Givet att A tillfrågas men tackar nej.

Förväntat: A:s inhoppsräknare och senaste inhoppsdatum ändras inte.

### E4: Endast faktiskt deltagande räknas

Givet att A registreras som extra inhoppare men markeras `Deltog inte` när matchen genomförs.

Förväntat: A får inget genomfört extra inhopp.

### E5: Extra inhopp påverkar inte ordinarie rättvisa

Givet att A genomför ett extra inhopp.

Förväntat: A:s prioritet och antal i den ordinarie fördelningen ändras inte.

## Manuella ändringar och omfördelning

### M1: Ordinarie manuellt byte bevaras

Givet att A manuellt tas bort och B manuellt läggs till i en planerad match.

När framtida matcher omfördelas från en tidpunkt före matchen.

Förväntat: A förblir borttagen och B förblir ordinarie uttagen i matchen.

### M2: Extra inhoppare bevaras separat

Givet att C läggs till som extra inhoppare.

När ordinarie framtida matcher omfördelas.

Förväntat: C ligger kvar som extra och räknas inte som ordinarie uttagen.

### M3: Omfördelning från vald match

Givet fem planerade matcher och att tränaren väljer omfördelning från match 3.

Förväntat:

- match 1 och 2 ändras inte
- ordinarie tilldelningar i match 1 och 2 ingår i rättvise-baseline för match 3–5
- automatiska platser i match 3–5 får räknas om
- manuella ändringar i match 3–5 bevaras

## Status och historik

### S1: Genomför match

Givet ordinarie uttagna och extra inhoppare i en planerad match.

När matchen markeras som genomförd.

Förväntat: alla föreslås som spelade tills tränaren korrigerar och sparar deltagandet.

### S2: Inställd match räknas inte

Givet en planerad och fördelad match som markeras inställd.

Förväntat:

- matchens ordinarie tilldelningar räknas inte i spelarstatistiken
- inga extra inhopp räknas
- övriga matcher omfördelas inte automatiskt

## Fel och skyddsregler

### F1: Fler platser än aktiva spelare

Givet 10 aktiva spelare och target 12.

Förväntat:

- ny generering för matchen stoppas med ett tydligt fel
- befintlig uttagning lämnas oförändrad
- andra matcher lämnas oförändrade

### F2: Spelare saknar nivå

Givet en aktiv spelare utan nivå.

Förväntat: spelaren exkluderas från automatisk ordinarie fördelning och appen visar att nivå måste anges.

### F3: Manuella beslut gör perfekt rättvisa omöjlig

Förväntat: besluten bevaras och resultatet redovisar den minsta uppnådda skillnaden samt en varning.

### F4: Manuella borttagningar lämnar för få kandidater

Givet en match där manuella borttagningar gör att antalet tillgängliga spelare understiger matchens target.

Förväntat:

- den nya genereringen stoppas med ett strukturerat fel
- inga nya partiella uttagningar returneras
- befintliga uttagningar ska därför kunna lämnas oförändrade av applikationslagret
