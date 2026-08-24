# Aktuell milstolpe: Implementation 09 – översikt

## Mål

Ge de tre tränarna en snabb och tillförlitlig startsida som svarar på vad som händer härnäst och om den ordinarie matchfördelningen behöver uppmärksamhet.

Detaljerat föreslaget scope och acceptanskriterier finns i `docs/planning/implementation-09-overview.md`.

## Leverabler

- [x] Implementation 09 granskad och godkänd.
- [ ] Kanoniskt, behörighetskontrollerat översiktsunderlag implementerat.
- [ ] Nästa match och kommande matcher implementerade.
- [ ] Ordinarie rättvisefördelning implementerad utan att extra inhopp blandas in.
- [ ] `/` används för Översikt och spelarlistan har en stabil `/players`-route.
- [ ] Loading, empty, error och populated states verifierade.
- [ ] Lokal användarresa och 390 px-layout verifierade.
- [ ] Oberoende skrivskyddad agentgranskning genomförd.

## Rekommenderad ordning

1. Granska och godkänn Implementation 09.
2. Implementera och testa det atomiska översiktsunderlaget.
3. Flytta spelarlistan till `/players` och aktivera navigationen.
4. Implementera nästa match, kommande matcher och rättvisefördelning.
5. Verifiera användarresan och genomför oberoende granskning.

## Milstolpen är klar när

- startsidan visar rätt nästa match och upp till fem kommande matcher
- tränaren kan öppna nästa match direkt
- ordinarie rättvisa visas begripligt och extra inhopp inte påverkar indikatorn
- tomma och felaktiga underlag ger en tydlig svensk åtgärdsväg
- navigationen fungerar konsekvent på mobil och desktop
- inga oaccepterade granskningsfynd återstår
