# Aktuell milstolpe: Implementation 05 – manuella ordinarie byten

## Mål

Låt en behörig tränare flytta en ordinarie matchplats mellan två spelare, bevara beslutet vid framtida generering och återställa bytet säkert.

Detaljerat föreslaget scope och acceptanskriterier finns i `docs/planning/implementation-05-manual-regular-adjustments.md`. Föreslaget arkitekturbeslut finns i ADR-008.

## Leverabler

- [x] Implementation 05 granskad och godkänd.
- [x] Manuellt byteskontrakt accepterat i ADR-008.
- [ ] Atomiskt create/restore med stale-skydd implementerat.
- [ ] Direkta klientmutationer och RPC-anrop negativt verifierade.
- [ ] Manuella include/exclude-beslut bevaras vid generering.
- [ ] Matchdetalj visar manuellt tillagd och borttagen spelare.
- [ ] Lokal create/restore-resa och 390 px-layout verifierade.
- [ ] Oberoende skrivskyddad agentgranskning genomförd.

## Rekommenderad ordning

1. Godkänn Implementation 05 och ADR-008.
2. Implementera constraints, server-only create/restore och negativa databastester.
3. Implementera kandidatlista, formulär och svensk felpresentation.
4. Visa manuella etiketter och återställning på matchdetaljen.
5. Verifiera bevarande vid generering och faktisk samtidighet.
6. Verifiera hela användarresan och genomför oberoende granskning.

## Milstolpen är klar när

- en behörig tränare kan skapa och återställa ett ordinarie byte
- matchens target bevaras och bytet överlever framtida generering
- en obehörig eller stale operation inte kan mutera uttagningen
- create och restore är atomiska även vid samtidiga tränare
- inga oaccepterade granskningsfynd återstår
