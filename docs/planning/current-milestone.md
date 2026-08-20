# Aktuell milstolpe: Implementation 04 – ordinarie laguttagningar

## Mål

Låt en behörig tränare generera, förhandsgranska, spara och läsa en komplett ordinarie fördelning för den aktiva säsongens framtida matcher.

Detaljerat scope och acceptanskriterier finns i `docs/planning/implementation-04-selection-persistence.md`. Arkitekturbeslutet finns i ADR-007.

## Leverabler

- [x] Implementation 04 avgränsad och godkänd.
- [x] Atomisk persistens dokumenterad i ADR-007.
- [x] Reproducerbar `match_players`-migration med stark lagintegritet.
- [x] RLS, grants och atomisk persistens verifierade negativt.
- [x] Testbar mappning från databasunderlag till fördelningsmotorn.
- [x] Serverberäknad preview med versionsmärkt underlagsfingeravtryck.
- [x] Atomiskt och idempotent save-flöde med stale-preview-skydd.
- [x] Matchlista och matchdetalj visar sparade uttagningar.
- [x] Loading, empty, error, preview och saved states verifierade.
- [x] Lokal användarresa och 390 px-layout verifierade.
- [x] Oberoende skrivskyddad agentgranskning genomförd utan kvarstående fynd.

## Rekommenderad ordning

1. Implementera och testa `match_players`, sammansatta nycklar, grants och RLS.
2. Implementera kanoniskt underlag, fingerprint och mapper till domänmotorn.
3. Implementera preview och svensk fel-/varningspresentation.
4. Implementera atomisk persistens med låsning och stale-preview-skydd.
5. Visa uttagningar i matchlista samt `Lag` och `Står över`.
6. Verifiera hela användarresan och genomför oberoende granskning.

## Milstolpen är klar när

- en behörig tränare kan generera, förhandsgranska, spara och läsa fördelningen
- en obehörig användare inte kan läsa eller mutera uttagningar
- hela resultatet sparas atomiskt och endast mot oförändrat underlag
- varje framtida match har exakt target unika ordinarie spelare
- inga oaccepterade granskningsfynd återstår
