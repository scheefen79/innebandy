# Aktuell milstolpe: Implementation 06 – extra inhoppare

## Mål

Låt en behörig tränare få en rättvis, nivåoberoende rekommendation och lägga till eller ta bort planerade extra inhoppare utan att påverka ordinarie uttagning.

Detaljerat föreslaget scope och acceptanskriterier finns i `docs/planning/implementation-06-extra-substitutes.md`. Föreslaget arkitekturbeslut finns i ADR-009.

## Leverabler

- [x] Implementation 06 granskad och godkänd.
- [x] Separat extrauttagningskontrakt accepterat i ADR-009.
- [ ] Kanonisk extra historik och kandidatrankning implementerad.
- [ ] Atomiskt tillägg/borttagning med stale-skydd implementerat.
- [ ] Direkta klientmutationer och RPC-anrop negativt verifierade.
- [ ] Ordinarie target, generering och manuella byten bevarar extra rader.
- [ ] Matchdetalj visar och hanterar extra inhoppare separat.
- [ ] Lokal add/remove-resa och 390 px-layout verifierade.
- [ ] Oberoende skrivskyddad agentgranskning genomförd.

## Rekommenderad ordning

1. Granska och godkänn Implementation 06 och ADR-009.
2. Implementera kanonisk historikkälla, server-only add/remove och negativa databastester.
3. Koppla Implementation 02:s extrarankning till applikationslagret.
4. Implementera kandidatlista, bekräftelse, svensk felpresentation och borttagning.
5. Verifiera bevarande vid ordinarie generering och faktiska samtidighetsfall.
6. Verifiera hela användarresan och genomför oberoende granskning.

## Milstolpen är klar när

- en behörig tränare kan se en rättvis rekommendation och välja valfri valbar kandidat
- planerade extra inhoppare kan läggas till och tas bort atomiskt
- endast genomförda extra inhopp används som historik
- ordinarie uttagning, target och rättvisa förblir oförändrade
- obehöriga, stale och samtidiga operationer inte kan skapa ett ogiltigt läge
- inga oaccepterade granskningsfynd återstår
