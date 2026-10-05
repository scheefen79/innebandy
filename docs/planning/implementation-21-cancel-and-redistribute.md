# Implementation 21 – ställ in och omfördela resterande matcher

- Status: Implementerad och granskad lokalt 2026-10-05. Ny riktig Supabase-verifiering i CI återstår före integration.
- Arbetsgren: `codex/two-phase-match-planning`; fortsätter efter `52a28a5`.
- Beslut: ADR-024. Ingen ny datamodell eller migration behövs.

## Mål och acceptans

Coach kan ställa in en ännu ej genomförd match från matchdetaljen, grundplanen eller matchveckan. Bekräftelse markerar matchen inställd, räknar bort dess platser/erbjudanden och öppnar en ny förhandsgranskning av återstående framtida grundplaner. Fördelningen sparas först genom ett uttryckligt val i förhandsgranskningen.

- Påbörjade andra matchveckor och spelade matcher ändras inte.
- Manuella beslut i återstående grundplaner bevaras.
- Inställd match och dess historik bevaras; den räknas inte i rättviseunderlaget.
- Inställning fungerar även innan matchveckan startas och före komplettering av äldre historik för ej genomförda matcher.
- Misslyckad/stale inställning öppnar inte en framgångsvy.
- Om historikspärr, otillräcklig trupp eller annan validering stoppar omfördelning är matchen fortfarande inställd och övriga planer oförändrade.
- Finns inga omfördelningsbara matcher visas tomläge utan sparknapp.
- Viewer nekas mutation och ser inga inställningskontroller.

## Utvecklingssteg

- [x] Produktbeslut: förhandsgranska och spara; ingen automatisk sparning.
- [x] Gemensam inställningskontroll på matchdetalj och i båda faserna.
- [x] Lyckad inställning leder till aktuell förhandsgranskning och tydlig sparstatus.
- [x] Länk från redan inställd match för att återuppta omfördelning.
- [x] SQL-regressioner: inställning i båda faserna, erbjudanden räknas bort, idempotent retry, stale förhandsgranskning, nya framtida val, skydd av fryst/spelad historik/manuella par och viewer.
- [x] Route- och renderingstester för navigation, fel och kontroller.
- [x] Lokal mobilresa med syntetiska data, inklusive bekräftelse och sparad omfördelning.
- [x] Slutligt bygge, lint, typkontroll, domäntester och diffkontroll.
- [x] Oberoende skrivskyddad granskning och eventuella rättningar: inga P0–P2-fynd.
- [ ] Riktig Supabase/pgTAP-verifiering för de nya SQL-regressionerna i CI.

## Verifiering hittills

199 applikationstester passerar. Hela migrationskedjan och 467 SQL-assertions passerar på isolerad PostgreSQL med lokal adapter utan extra service-role-grants. Riktig Supabase-körning av de 14 nya assertionerna återstår. Föregående commit `52a28a5` har grön riktig CI inklusive 453 pgTAP-tester, databaslint och samtliga samtidighetstester.

Mobilflödet verifierades i 390 × 844 med en isolerad lokal databas och enbart syntetiska spelare: inställning från matchdetaljen före start av matchveckan, bekräftelse i förhandsgranskningen, endast återstående match i förslaget, uttrycklig sparning och sparad status i matchöversikten. Den inställda matchen behåller sin historik och länk för att återuppta omfördelning. Ingen horisontell scroll i bekräftelse eller förhandsgranskning. Produktionsbygge, lint, typkontroll och diffkontroll passerar.

Commit/push/merge/produktion för detta tillägg är separata publiceringssteg. Inga verkliga matcher har ställts in.
