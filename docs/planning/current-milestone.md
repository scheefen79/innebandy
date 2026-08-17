# Aktuell milstolpe: Implementation 02 – fördelningsmotor

## Mål

Implementera och verifiera rättvis ordinarie matchfördelning och separat rekommendation av extra inhoppare som ren, deterministisk domänlogik.

Detaljerat scope och acceptanskriterier finns i `docs/planning/implementation-02-allocation-engine.md`. Arkitekturbeslutet finns i ADR-005.

## Leverabler

- [x] Implementation 02 avgränsad och godkänd.
- [x] Domänmotorns arkitektur dokumenterad i ADR-005.
- [x] TypeScript-kontrakt för input, output, varningar och fel.
- [x] Deterministisk ordinarie fördelningsmotor.
- [x] Separat rangordning för extra inhoppare.
- [x] Automatiserade normalfall, tie-breakers och skyddsregler.
- [x] Referensfallet 23 spelare × 9 matcher × 12 platser verifierat.
- [x] Oberoende skrivskyddad agentgranskning genomförd.

## Rekommenderad ordning

1. Definiera typer och valideringsresultat.
2. Implementera tester för normalfall och referensfall.
3. Implementera ordinarie motorn tills testerna passerar.
4. Implementera och testa den separata extrarekommendationen.
5. Lägg till manuella begränsningar, fel och varningar.
6. Kör full verifiering och oberoende granskning.

## Milstolpen är klar när

- alla relevanta fall i testmatrisen passerar
- samma input ger identisk output
- ordinarie och extra rättvisa är bevisligen separerade
- domänmodulen saknar beroenden till UI, databas, nätverk och aktuell tid
- inga oaccepterade granskningsfynd återstår
