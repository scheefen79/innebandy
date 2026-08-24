# Aktuell milstolpe: Implementation 07 – genomför match

## Mål

Låt en behörig tränare registrera faktiskt deltagande och atomiskt flytta en spelad match från `Planerad` till `Genomförd`, så att ordinarie historik och extrarotation uppdateras korrekt.

Detaljerat föreslaget scope och acceptanskriterier finns i `docs/planning/implementation-07-match-completion.md`. Föreslaget arkitekturbeslut finns i ADR-010.

## Leverabler

- [x] Implementation 07 granskad och godkänd.
- [x] Completion- och deltagandekontrakt accepterat i ADR-010.
- [ ] Kanoniskt deltagandeunderlag och fingeravtryck implementerat.
- [ ] Atomisk matchcompletion med stale- och first-write-wins-skydd implementerad.
- [ ] Manuella ordinarie par stödjer genomfört deltagande säkert.
- [ ] Direkta klientmutationer och RPC-anrop negativt verifierade.
- [ ] Ordinarie och extra historik verifierad separat.
- [ ] Matchdetalj och completion-vy visar deltagande begripligt.
- [ ] Lokal completion-resa och 390 px-layout verifierade.
- [ ] Oberoende skrivskyddad agentgranskning genomförd.

## Rekommenderad ordning

1. Granska och godkänn Implementation 07 och ADR-010.
2. Anpassa parintegriteten och implementera kanoniskt completion-underlag.
3. Implementera server-only completion och negativa databas-/samtidighetstester.
4. Implementera deltagarformulär, sammanfattning och svensk felpresentation.
5. Visa sparat deltagande och verifiera historikregressioner.
6. Verifiera hela användarresan och genomför oberoende granskning.

## Milstolpen är klar när

- en behörig tränare kan korrigera föreslaget deltagande och genomföra matchen
- matchstatus och alla `played`-värden sparas atomiskt
- frånvaro inte räknas som genomförd ordinarie match eller extra inhopp
- identiska retries konvergerar och olika samtidiga beslut inte skriver över varandra
- genomförd match inte längre kan ändras av planeringsflödena
- inga oaccepterade granskningsfynd återstår
