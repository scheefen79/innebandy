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
- Be om godkännande före commit, push, pull request, deployment, externa skrivningar, destruktiva åtgärder eller väsentligt utökat scope.
- Bevara användarens befintliga ändringar och avbryt om de inte säkert kan separeras från uppgiften.

## Kvalitetskrav

- Följ `docs/quality/definition-of-done.md`.
- Affärslogik för fördelning ska vara separerad från UI och testas deterministiskt.
- Alla centrala vyer ska hantera loading, empty, error och populated states.
- Mobil är primär målplattform och får inte ha horisontell scroll.
- Persondata ska minimeras. Behörighet och Row Level Security ska verifieras, inte bara konfigureras.
- En agent får inte kalla arbete färdigt utan att redovisa utförd verifiering och kvarvarande osäkerheter.

## Lärande och kommunikation

Användaren vill förstå arbetssättet. Vid viktiga beslut ska agenten kort förklara:

- vad som beslutades
- vilka rimliga alternativ som fanns
- varför valet passar projektets nuvarande fas
- vad som skulle kunna få beslutet att ändras senare

Undvik onödig teori när ett konkret exempel i projektet förklarar bättre.

