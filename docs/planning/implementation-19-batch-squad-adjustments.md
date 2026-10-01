# Implementation 19: flera byten och flera extra inhoppare i ett steg

- Status: Godkänd 2026-10-01; lokalt implementerad, mobil användarresa och oberoende granskning återstår
- Föreslagen: 2026-10-01

## Syfte

Låt tränaren justera matchtruppen snabbare: flera ordinarie spelare kan bytas ut och flera extra inhoppare läggas till i ett enda sparande, utan att något kan sparas till hälften.

## Beslutad omfattning

- `Justera ordinarie lag`: tränaren markerar flera spelare som ska stå över och lika många ersättare, och parar ihop dem. Varje par sparas som ett manuellt byte enligt ADR-008. Alla par sparas atomiskt eller inget.
- Antalet som står över är alltid lika med antalet som läggs till. Matchens ordinarie `target_players` ändras inte. Att lämna en plats tom ingår inte.
- `Lägg till extra inhoppare`: tränaren markerar en eller flera kandidater med kryssrutor. Alla sparas atomiskt som `extra/manual/selected`, `played=false`.
- Kandidatregeln är oförändrad: aktiv spelare i samma lag och säsong utan någon rad i matchen. Ordinarie uttagna och manuellt borttagna spelare kan inte läggas till som extra. Tränaren kan välja vilken kandidat som helst, inte bara den rekommenderade.
- Det finns inga nya produktfunktioner utöver detta. Befintliga enkla flöden fungerar som en batch om ett.

## Utanför scope

- Mindre trupp (byte utan ersättare).
- Extra inhopp för manuellt borttagna spelare.
- Ändring av rankning, nivåbalans eller återställningsflöde per par.

## Acceptanskriterier

- 1–N byten och 1–N extra spelare kan sparas i ett anrop; ett ogiltigt element avvisar hela batchen och lämnar matchen oförändrad.
- Dubbletter, överlappande ut/in-id:n, olika antal ut och in, och spelare som inte uppfyller ADR-008/009-villkoren nekas.
- Stale fingeravtryck nekas utan att något skrivs. Identisk retry konvergerar utan dubbletter.
- Varje bytespar är fortfarande ömsesidigt kopplat och kan återställas enskilt; databasens deferred-trigger godkänner endast kompletta par.
- Extra rader ligger utanför target och påverkar inte ordinarie rättvisa; `played` förblir `false`.
- Endast coach får skriva; viewer och anonym nekas i serverlager och databas.
- Flödena fungerar med tangentbord och på 390 px utan horisontell scroll, med tydlig sammanfattning (`aria-live`) av valda par och extra, samt loading-, empty-, error- och stale-lägen.

## Teknisk plan

1. Ny migration: `create_manual_regular_adjustments(pairs jsonb)` och `add_extra_substitutes(player_ids uuid[])`, server-only (ingen grant till `authenticated`), samma kontrollordning som ADR-007–009. De befintliga enkla funktionerna lämnas orörda.
2. Domän/feature-lager: parsning och validering av batch-input, separerat från UI.
3. Routes: `adjust/save` och `extras/add` accepterar flera värden; befintliga routetester utökas.
4. UI: `adjustment-form.tsx` (par ut/in) och `extra-form.tsx` (kryssrutor).
5. Dokumentation: ADR-022, uppdatering av spec 8.7/8.8, `open-questions.md` beslut 5 och `current-milestone.md`.

## Verifiering

1. Enhetstester av batchparsning och validering.
2. Routetester för flera id:n, överlapp och felaktigt antal.
3. pgTAP: atomicitet, negativa fall (ensam rad, korskoppling, samma motpart två gånger, dubbletter, stale, viewer/anonym), retry, extra utanför target.
4. `git diff --check`, lint, typkontroll, Vitest, bygge, databastester och db lint.
5. Lokal mobil användarresa för båda flödena.
6. Oberoende skrivskyddad granskning av hela diffen mot `main`.

## Öppen punkt att bekräfta

- Parning i UI: tränaren väljer ersättare per spelare som står över. Alternativet (välj fritt och låt systemet para i listordning) avvisas eftersom återställning per par då blir oförutsägbar.
