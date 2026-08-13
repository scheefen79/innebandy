# Definition of Done

En uppgift är klar först när samtliga relevanta punkter nedan är uppfyllda.

## Produkt

- Beteendet motsvarar specifikationen och uppgiftens acceptanskriterier.
- Ingen oönskad funktion eller väsentlig scope-utökning har lagts till.
- Loading, empty, error och populated states är hanterade där de är relevanta.

## Kod

- Lösningen följer dokumenterad arkitektur och projektets etablerade mönster.
- Affärslogik är separerad från presentation och externa integrationer.
- Fel och gränsfall hanteras uttryckligt.
- Ändringen innehåller inga hemligheter, persondata eller oavsiktliga debug-utskrifter.

## Testning

- Relevanta automatiska tester finns och passerar.
- Fördelningslogik har deterministiska tester för normalfall, tie-breakers och omöjliga input.
- Ändringen har verifierats i den faktiska användarresan när UI berörs.
- Mobil layout, tangentbordsanvändning och grundläggande tillgänglighet har kontrollerats när UI berörs.

## Data och säkerhet

- Databasändringar är reproducerbara genom migrationer.
- Row Level Security och behörighetsregler har negativa tester: en obehörig användare ska nekas.
- Destruktiva eller irreversibla förändringar har en uttrycklig plan för återställning eller migrering.

## Dokumentation och överlämning

- Berörda produkt-, arkitektur- och planeringsdokument är uppdaterade.
- Genomförd verifiering och eventuella kvarvarande risker redovisas.
- Commit och push görs först efter användarens godkännande.

