# Aktuell milstolpe: beslutsgrund och projektskelett

## Mål

Skapa en verifierad grund för implementation utan att börja bygga funktioner på oklara antaganden.

## Leverabler

- [x] Git-repo initierat och kopplat till GitHub.
- [x] Produktspecifikationen placerad under `docs/product/`.
- [x] Grundläggande agentinstruktioner skapade.
- [x] Öppna frågor identifierade.
- [x] Föreslagen arkitektur beskriven.
- [x] Öppna blockerande frågor beslutade.
- [x] Teknikstack bekräftad i ADR-001.
- [x] Behörighetsmodell dokumenterad i ADR-002.
- [x] Uttagnings- och deltagandemodell dokumenterad i ADR-003.
- [x] Fördelningsmotorns regler uttryckta som testfall.
- [x] Första implementationens scope och verifieringsplan definierade.
- [x] Första implementationens scope och verifieringsplan godkända.

## Rekommenderad ordning

1. Skapa applikationsskelettet.
2. Implementera en tunn vertikal funktion: login till läsbar spelarlista med RLS.
3. Implementera algoritmtesterna före eller tillsammans med fördelningsmotorn.

## Milstolpen är klar när

- inga kända blockerande produktbeslut återstår för första implementationen
- arkitekturvalen är dokumenterade med konsekvenser
- det finns testbara acceptanskriterier för den första vertikala funktionen
- användaren har granskat och förstått strukturen
