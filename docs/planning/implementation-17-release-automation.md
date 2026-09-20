# Implementation 17: automatiserad verifiering och databasrelease

- Status: Genomförs
- Beslut: ADR-021

## Mål

Ingen ändring ska kunna nå `main` utan att testerna bevisligen körts, och ingen migration ska
kunna glömmas bort. Flödet ska kräva så få manuella steg som möjligt utan att bli oöverblickbart.

## Acceptanskriterier

- Varje pull request kör repots guards, `lint`, `typecheck`, `test`, `build` och hela
  databassviten inklusive pgTAP, de sex samtidighetsskripten och production-bootstrap.
- `main` är skyddad: pull request krävs och båda jobben måste vara gröna före merge.
  Skyddet sätts i GitHubs inställningar. Tills det är påslaget är M2 och M3 inte uppfyllda.
- Arbetsflödet har inga hemligheter och kan inte nå ett skarpt Supabase-projekt.
  `SUPABASE_SERVICE_ROLE_KEY` finns inte i CI.
- Migrationer i `supabase/migrations/` körs automatiskt vid merge till `main`.
- `seed.sql` kan inte nå produktion.
- Guarderna mot spårade miljöfiler, hemligheter och personuppgifter har en enda definition som
  både den lokala preflighten och CI använder.
- Ordningsregeln för additiva och destruktiva migrationer är dokumenterad i runbooken.
- Previewmiljön pekar på en egen databas och kan inte skriva i lagets riktiga data.
- Previews fungerar. Före ändringen saknade Preview Supabase-variabler helt och kraschade på
  varje request, vilket inte märktes eftersom previews ligger bakom Vercels inloggning.

## Mått

| # | Mått | Utgångsläge | Målvärde |
|---|---|---|---|
| M1 | Migrationer som kan ligga omigrerade utan att någon märker det | obegränsat | 0 |
| M2 | Andel pull requests där testerna bevisligen körts | 0 % | 100 % |
| M3 | Merge möjlig med röda tester | ja | nej |
| M4 | Previews som kan skriva i lagets riktiga data | 0 (visade sig redan uppfyllt) | 0 |
| M5 | `pnpm release:preflight` grön | nej | ja |

## Avgränsning

Ingår inte: godkännandesteg före produktionsmigrering, exakt ordning mellan databas- och
appdeploy, Supabase Branching, eller automatisk driftdetektering mot handapplicerade ändringar.
Motiven finns i ADR-021.

Preview-databasen skapas och kopplas för hand. Free-planen rymmer två projekt, och en databas per
pull request kräver Pro.
