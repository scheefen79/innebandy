# Implementation 12: övningsinnehåll och originalbilder

- Status: Implementerad lokalt
- Datum: 2026-08-26
- Källa: Svensk Innebandys offentliga Övningsbank

## Mål

Ersätt träningsplanens generiska platshållartext med korta, praktiska instruktioner och visa en relevant originalbild när Övningsbanken tillhandahåller en statisk bild.

## Beslutad lösning

- Alla 45 planerade övningsnamn mappas i `content/training-exercise-content.json` till en granskad originalövning.
- Syfte, genomförande och coachingpunkter är nyskrivna sammanfattningar, inte kopior av källtexten.
- Original-URL och eventuell bild-URL sparas per träningsmoment.
- Bilden laddas från `innebandy.se`, visas med attribution och länkas till originalövningen.
- Varje kort visar källövningens officiella titel så att egna varianter inte presenteras som exakta kopior.
- Teknikövningar markeras i blått och matchövningar i grönt med både bakgrund, ram och textetikett.
- Originalbilder kopieras inte till repot. Övningar utan statisk originalbild fungerar fullständigt med text och källänk.
- Berikningen får endast uppdatera orörda grundplaner med status `draft`, revision `1` och den tidigare platshållartexten. Tränarnas ändringar bevaras.

## Acceptanskriterier

- Samtliga 45 namn har källa, syfte, tydligt genomförande och tre coachingpunkter.
- Tillgängliga bilder visas utan horisontell scroll på mobil.
- Bilden har beskrivande alternativtext och synlig attribution.
- Källänken öppnar rätt originalövning.
- Alla använda originalsidor och bildfiler ska jämföras automatiskt; ett stickprov ska även kontrolleras visuellt i webbläsare.
- Berikningen är idempotent och kan inte skriva över en redigerad plan.
- Automatiska kod-, databas- och produktionsbyggtester passerar.

## Kvarvarande kontroll

Gör ett smoke test på riktig mobil efter Vercel-deployment. Om Innebandy.se ändrar bildadresser eller användningsvillkor ska bilder kunna döljas utan att textinnehållet påverkas.
