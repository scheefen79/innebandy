# Aktuell milstolpe: Implementation 03 – matchgrund

## Mål

Låt en behörig tränare skapa, lista och öppna matcher i lagets aktiva säsong genom ett säkert mobile-first-flöde.

Detaljerat scope och acceptanskriterier finns i `docs/planning/implementation-03-match-foundation.md`. Arkitekturbeslutet finns i ADR-006.

## Leverabler

- [x] Implementation 03 avgränsad och godkänd.
- [x] Matchgrundens arkitektur dokumenterad i ADR-006.
- [ ] Reproducerbar `matches`-migration med dataintegritet och index.
- [ ] Positiva och negativa pgTAP-test för schema, grants och RLS.
- [ ] Syntetisk matchseed.
- [ ] Servervaliderat formulär för att skapa match.
- [ ] Mobile-first matchlista med `Kommande` och `Alla`.
- [ ] Läsbar matchdetalj med generiskt not-found-beteende.
- [ ] Loading, empty, error och populated states verifierade.
- [ ] Lokal användarresa och 390 px-layout verifierade.
- [ ] Oberoende skrivskyddad agentgranskning genomförd.

## Rekommenderad ordning

1. Implementera och testa migration, index, grants och RLS.
2. Lägg till syntetisk seedmatch och dokumenterad reset.
3. Implementera servernära validering och create-use-case.
4. Implementera matchlista och matchdetalj.
5. Verifiera states, mobil, tangentbord och faktisk användarresa.
6. Kör full kontroll och oberoende granskning.

## Milstolpen är klar när

- en behörig tränare kan skapa och läsa en match end-to-end
- en obehörig användare inte kan läsa eller skapa lagets matcher
- matchdata är tidsmässigt och relationellt entydig
- samtliga relevanta design states är verifierade
- inga oaccepterade granskningsfynd återstår
