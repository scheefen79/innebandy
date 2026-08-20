# Arbetsinstruktioner för Innebandy

## Projektets mål

Bygg ett enkelt, mobile-first planeringsverktyg för FBC Sollentuna P17. Verktyget ska hjälpa tränare att fördela matchplatser rättvist och balansera matchtrupper efter spelarnivå.

Produktens källa är `docs/product/FBC_P17_DESIGN_TECH_SPEC.md`. Lägg inte till funktioner utanför specifikationen utan ett uttryckligt beslut.

## Prioriteringsordning

1. Korrekt och rättvis matchfördelning.
2. Enkel och tydlig mobilupplevelse.
3. Säker datamodell och behörighetskontroll.
4. Liten, begriplig lösning som är lätt att ändra.
5. Responsivitet, tillgänglighet och stabilitet.

## Arbetssätt

- Läs relevant dokumentation innan du föreslår eller ändrar kod.
- Klargör mål, acceptanskriterier och verifiering för varje större uppgift.
- Gör små, fokuserade ändringar. Blanda inte orelaterade förändringar.
- Dokumentera viktiga teknikbeslut i `docs/architecture/decisions/`.
- Uppdatera berörda dokument när ett beslut ändrar produkt, arkitektur eller arbetsflöde.
- Implementera inte öppna produktbeslut som antaganden. Dokumentera frågan och be om beslut när svaret påverkar beteende eller datamodell.
- Använd specialistagenter endast för tydligt avgränsade, självständiga arbetsströmmar. Huvudagenten ansvarar för helhet och slutlig verifiering.

## Autonomi och godkännanden

- Vid analys, planering, diagnos eller granskning: inspektera och rapportera, men ändra inte implementationen om det inte efterfrågas.
- Vid uttrycklig begäran att bygga, ändra eller rätta: gör relevanta lokala ändringar och kör icke-destruktiv verifiering.
- När användaren har godkänt en implementationsplan gäller godkännandet som stående mandat att slutföra hela det dokumenterade scopet lokalt. Agenten får då skapa arbetsgren, ändra kod, migrationer, tester och dokumentation, köra icke-destruktiva kontroller, använda en skrivskyddad granskningsagent och rätta verifierade P0–P2-fynd utan nya delgodkännanden.
- Agenten får själv fatta små, reversibla teknik- och UI-beslut inom godkänd plan när de följer befintlig specifikation, ADR:er och etablerade mönster. Besluten ska dokumenteras när de påverkar arkitektur eller framtida arbete.
- Be endast om ett nytt produktbeslut när rimliga alternativ ger materiellt olika användarbeteende, rättviselogik, datamodell eller säkerhetsnivå och svaret inte redan finns dokumenterat.
- Be om godkännande före commit, push, pull request, deployment, externa skrivningar, destruktiva åtgärder eller väsentligt utökat scope.
- Bevara användarens befintliga ändringar och avbryt om de inte säkert kan separeras från uppgiften.

Det fullständiga mandatet och stoppunkterna finns i `docs/workflow/autonomy-contract.md`.

## Kvalitetskrav

- Följ `docs/quality/definition-of-done.md`.
- Affärslogik för fördelning ska vara separerad från UI och testas deterministiskt.
- Alla centrala vyer ska hantera loading, empty, error och populated states.
- Mobil är primär målplattform och får inte ha horisontell scroll.
- Persondata ska minimeras. Behörighet och Row Level Security ska verifieras, inte bara konfigureras.
- En agent får inte kalla arbete färdigt utan att redovisa utförd verifiering och kvarvarande osäkerheter.

## Oberoende kodgranskning

När en separat agent får rollen som granskare ska den vara skrivskyddad och oberoende av implementationen:

- Läs först `AGENTS.md`, relevant planering, `docs/quality/definition-of-done.md` och berörda arkitekturbeslut.
- Granska hela ändringen mot avsedd bas, inklusive nya filer som ännu inte är spårade av Git.
- Kör gärna relevanta icke-destruktiva kontroller, men ändra inte filer och installera inte beroenden.
- Skapa inte commit, push, pull request, GitHub-kommentar eller merge.
- Rapportera endast konkreta fynd som kan beläggas. Ange prioritet, fil och rad, konsekvens, evidens och rekommenderad rättning.
- Använd prioriteterna P0 (blockerande), P1 (allvarlig), P2 (bör rättas) och P3 (förbättring).
- Skriv uttryckligen när inga fynd finns och redovisa då även vad som kontrollerades och kvarvarande osäkerheter.

Huvudagenten ska själv bedöma granskarens fynd, göra eventuella rättningar och köra slutlig verifiering. En ändring är inte redo att integreras med öppna P0- eller P1-fynd. P2-fynd ska rättas eller uttryckligen accepteras med motivering.

## Lärande och kommunikation

Användaren vill förstå arbetssättet. Vid viktiga beslut ska agenten kort förklara:

- vad som beslutades
- vilka rimliga alternativ som fanns
- varför valet passar projektets nuvarande fas
- vad som skulle kunna få beslutet att ändras senare

Undvik onödig teori när ett konkret exempel i projektet förklarar bättre.
