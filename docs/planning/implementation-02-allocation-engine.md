# Implementation 02: deterministisk fördelningsmotor

- Status: Genomförd och verifierad
- Godkänd: 2026-08-17
- Verifierad: 2026-08-17

## Syfte

Implementera och verifiera projektets rättviselogik som en ren TypeScript-domänmodul innan den kopplas till databas eller gränssnitt.

Implementationens två separata ansvar är:

```text
generateRegularAllocation(input)
  → ordinarie, nivåbalanserade matchtrupper

recommendExtraPlayers(input)
  → rättvist rangordnade kandidater för extra inhopp
```

Ordinarie matcher och extra inhopp ska förbli två oberoende rättvisesystem.

## Ingår

### Domänkontrakt

Vanliga TypeScript-objekt för:

- aktiva spelare med id, nivå och fast rotationsordning
- suffixet av planerade matcher som faktiskt ska genereras, med id, ordning och target-antal
- rättvise-baseline per spelare som summerar genomförda ordinarie matcher och alla bevarade ordinarie tilldelningar före omfördelningsgränsen
- senaste genomförda eller bevarade planerade ordinarie match före suffixet per spelare
- manuellt tillagda och borttagna ordinarie uttagningar
- genomförda extra inhopp och senaste inhoppsdatum
- ordinarie uttagningar, extrarekommendationer, varningar och fel

Domänkontraktet får inte exponera Supabase-, React- eller Next.js-typer.

### Ordinarie fördelning

- beräkna den jämnaste matematiskt möjliga fördelningen av ordinarie platser
- fylla exakt target-antal unika spelare per match
- balansera nivå 1–3 proportionellt utan att nivå påverkar totalt antal matcher
- prioritera längst väntetid mellan i övrigt likvärdiga spelare
- använda säsongens fasta rotationsordning som sista utslagsregel
- bevara manuella tillägg och borttagningar
- returnera strukturerade varningar när nivåbalans eller rättvisa avviker
- returnera strukturerade fel utan partiellt resultat när säker generering är omöjlig

### Extra inhopp

Returnera en kandidatordning baserad på:

1. färst genomförda extra inhopp
2. längst tid sedan senaste genomförda extra inhopp
3. fast rotationsordning

Applikationslagret skickar en explicit `eligibleCandidates`-lista. Varje kandidat ska vara aktiv, tillgänglig enligt de regler som finns i MVP och varken ordinarie uttagen eller redan registrerad som extra i den aktuella matchen. MVP har ingen separat kalender för annan frånvaro; sådan tillgänglighet ligger utanför systemet tills ett produktbeslut inför den.

Spelarnivå och ordinarie matchhistorik får inte påverka resultatet. Funktionen får inte själv ändra räknare eller historik och får endast rangordna kandidaterna i `eligibleCandidates`.

### Omfördelningsgräns

Domänmotorn får endast det suffix av matcher som ska räknas om. Matcher före vald startmatch skickas inte in och kan därför inte ändras.

Applikationslagret beräknar en `baselineRegularCount` per spelare från:

- genomförda ordinarie matcher
- bevarade planerade ordinarie tilldelningar före startmatchen

Motorn använder denna baseline när rättvisan i suffixet beräknas. Befintliga uttagningar i suffixet används endast när de är manuellt bevarade; automatiska suffixplatser får räknas om.

### Kodstruktur

```text
src/domain/allocation/
├── types.ts
├── regular-allocation.ts
├── regular-allocation.test.ts
├── extra-recommendation.ts
├── extra-recommendation.test.ts
└── test-builders.ts
```

Strukturen får justeras om ansvaren förblir lika tydligt separerade.

## Ingår inte

- nya Supabase-tabeller eller migrationer för matcher och uttagningar
- hämtning eller lagring av fördelning
- databastransaktion för omfördelning
- matchlista, matchdetalj eller knappen `Generera fördelning`
- UI för manuella byten eller extra inhoppare
- markera match som genomförd
- uppdatera spelarhistorik eller inhoppsräknare
- deployment eller produktionsdata

## Acceptanskriterier

### Ordinarie fördelning

- Referensfallet med 23 spelare, 9 matcher och 12 platser ger 108 tilldelningar.
- Varje referensmatch innehåller exakt 12 unika spelare.
- Varje referensspelare får 4 eller 5 ordinarie matcher.
- Skillnaden mellan högsta och lägsta antal är 1 när inga manuella beslut hindrar det.
- Nivå påverkar matchernas sammansättning men inte en spelares totala tilldelning.
- Längst väntetid avgör mellan annars likvärdiga spelare.
- Fast rotation avgör när kandidater fortfarande är likvärdiga.
- Exakt samma input ger strukturellt identiskt resultat i upprepade körningar.
- Manuella tillägg och borttagningar bevaras vid omfördelning.
- En otillräcklig nivågrupp ersätts av andra nivåer och ger en strukturerad varning.

### Extra inhopp

- Färst genomförda extra inhopp prioriteras oberoende av nivå.
- Äldsta senaste inhopp prioriteras vid lika antal.
- Fast rotation avgör återstående lika lägen.
- En spelare utan genomfört inhopp behandlas som att den väntat längst.
- Endast kandidater i den redan validerade `eligibleCandidates`-listan kan rekommenderas.
- Extra historik påverkar inte ordinarie resultat och ordinarie historik påverkar inte extrarekommendationen.

### Fel och skyddsregler

- Target mindre än noll eller större än antalet tillgängliga aktiva spelare ger ett strukturerat fel.
- Dubbletter av spelar-, match- eller rotations-id:n avvisas.
- En aktiv spelare utan giltig nivå exkluderas och redovisas tydligt innan fördelning.
- Motstridiga manuella beslut ger ett strukturerat fel.
- Om manuella borttagningar lämnar färre tillgängliga spelare än target stoppas hela den nya genereringen med ett strukturerat fel och utan nya uttagningar.
- Manuella beslut som gör perfekt rättvisa omöjlig bevaras och ger en strukturerad varning.
- Ett felresultat innehåller inga nya partiella uttagningar.

## Testmatris

Samtliga observerbara fall i `docs/quality/allocation-test-cases.md` som hör till ren domänlogik ska automatiseras:

- O1–O5: ordinarie fördelning
- E1–E2 och E5: extrarekommendation och separation
- M1–M3: låsningar och omfördelningsgräns, inklusive att baseline från bevarade matcher påverkar suffixets rättvisa utan att de bevarade matcherna returneras eller ändras
- F1–F4: fel och skyddsregler

E3–E4 samt S1–S2 kräver senare applikationslogik och datalagring. De ska inte simuleras inne i domänmotorn.

Utöver exemplen ska tester täcka:

- tom spelarlista och tom matchlista
- en spelare och en match
- osorterad input
- oberoende av alfabetisk namnordning
- en extrakandidatlista där redan uttagna och inaktiva spelare har filtrerats bort av applikationslagret
- input som inte muteras
- flera upprepade körningar med identiskt resultat

## Verifieringsplan

1. Kör lint och TypeScript-kontroll.
2. Kör hela Vitest-sviten.
3. Kör ett separat referenstest för 23 × 9 × 12.
4. Verifiera att domänmodulen inte importerar ramverk, nätverk eller databasklient.
5. Kör produktionsbygget för att upptäcka integrationsfel.
6. Låt en separat skrivskyddad agent granska hela diffen mot `main`.

UI-, mobil- och webbläsarverifiering är inte relevant eftersom implementationen saknar presentation.

## Definition av klar

Implementation 02 är klar när:

- samtliga relevanta acceptanskriterier är automatiserade och passerar
- samma input bevisligen ger samma output
- ordinarie och extra rättvisa inte delar räknare eller prioriteringsdata
- inga P0- eller P1-fynd och inga oaccepterade P2-fynd återstår
- verifiering och kvarvarande algoritmiska begränsningar har redovisats
