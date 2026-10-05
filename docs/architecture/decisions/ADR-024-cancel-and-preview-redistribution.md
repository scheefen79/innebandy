# ADR-024: ställ in match och förhandsgranska resterande grundplaner

- Status: Accepterat, valt av användaren 2026-10-05.
- Plan: [Implementation 21](../../planning/implementation-21-cancel-and-redistribute.md).

## Kontext och beslut

Inställningskontrollen i matchveckan var otillgänglig före fas 2, och en inställd match gav ingen sammanhängande väg till omfördelning. Coach ska kunna ställa in från matchdetalj, grundplan eller matchvecka och därefter granska en ny fördelning för återstående framtida grundplaner.

Användaren valde förhandsgranskning och uttrycklig sparning framför automatisk sparning. Inställningen sparas först genom befintlig revisionskontrollerad, idempotent `save_match_workflow`. Därefter öppnas befintlig fördelningsmotor med nytt underlag. En tydlig status bekräftar vilken match som verkligen är inställd och att nya planer inte är sparade ännu.

Inställning och omfördelning är två separata transaktioner. Historikspärr, fel eller avbruten förhandsgranskning återställer inte inställningen och ändrar inte övriga planer. Fördelningen sparas senare atomiskt med befintlig fingerprint-kontroll; ett gammalt underlag nekas.

Inställda matchers erbjudanden räknas bort. Andra påbörjade matchveckor och spelade matcher bevaras, liksom manuella val. Full omfördelning av frysta matchveckor ingår inte. Viewer har inga mutationskontroller eller mutationsrättigheter.

## Konsekvenser och alternativ

Befintliga datakontrakt återanvänds; ingen migration eller ny rättviseregel behövs. Automatisk gemensam inställning och omfördelning hade krävt ett annat produktbeslut och en gemensam transaktion. Den lösningen kan omprövas senare om laget vill slopa granskning av nya trupper.
