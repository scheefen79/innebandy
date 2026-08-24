# Aktuell milstolpe: Implementation 08 – spelarhantering och historik

## Mål

Låt de tre tränarna underhålla den aktiva spelartruppen och förstå varje spelares ordinarie och extra matchhistorik utan att spelarändringar tyst skriver om uttagningar.

Detaljerat föreslaget scope och acceptanskriterier finns i `docs/planning/implementation-08-player-management-and-history.md`. Föreslaget arkitekturbeslut finns i ADR-011.

## Leverabler

- [x] Implementation 08 granskad och godkänd.
- [x] Spelar- och historikkontrakt accepterat i ADR-011.
- [ ] Atomiskt skapande med permanent rotationsordning implementerat.
- [ ] Ändring och soft delete med stale-skydd implementerat.
- [ ] Direkta klientmutationer och RPC-anrop negativt verifierade.
- [ ] Ordinarie och extra spelarhistorik implementerad och separat verifierad.
- [ ] Spelarlista, sökning, spelarkort och formulär implementerade.
- [ ] Omfördelningssignal efter spelarändring verifierad.
- [ ] Lokal spelarresa och 390 px-layout verifierade.
- [ ] Oberoende skrivskyddad agentgranskning genomförd.

## Rekommenderad ordning

1. Granska och godkänn Implementation 08 och ADR-011.
2. Implementera kanonisk historikkälla och server-only spelarmutationer.
3. Verifiera rotation, grants, stale-skydd och samtidighet i databasen.
4. Implementera lista, sökning, spelarkort och skapa-/ändraflöden.
5. Implementera deaktivering och tydlig omfördelningssignal.
6. Verifiera hela användarresan och genomför oberoende granskning.

## Milstolpen är klar när

- en behörig tränare kan skapa, öppna, ändra och deaktivera en spelare
- spelarens ordinarie och extra matcher redovisas separat och korrekt
- samtidiga tränare inte kan skapa rotationskollisioner eller skriva över varandras ändringar
- soft delete bevarar historik och inga uttagningar ändras automatiskt
- spelarändringar ger en begriplig väg till uttrycklig omfördelning
- inga oaccepterade granskningsfynd återstår
