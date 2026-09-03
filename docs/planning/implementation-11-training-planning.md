# Implementation 11: gemensam träningsplanering

- Status: Föreslagen
- Föreslagen: 2026-08-26
- Produktunderlag: `docs/product/Codex-överlämning – Höstens träningsplanering.md`

## Syfte

Ge alla aktiva tränare för FBC Sollentuna P17 en gemensam, mobile-first planering för höstens träningar:

```text
Tränaren öppnar Träningar
  → ser nästa träning och höstens kalender
  → öppnar ett träningstillfälle
  → granskar eller justerar övningar, ordning och vägledande tider
  → sparar planen gemensamt för tränargruppen
  → markerar träningen som planerad eller genomförd
```

Planeringen ska vara ett praktiskt stöd på plats. Angivna minuter är riktmärken och får aldrig hindra tränarna från att anpassa passet.

## Beslutad grund

- Alla aktiva `team_members` med rollen `coach` får läsa och redigera samtliga träningar för sitt lag. ADR-016 tillåter dessutom `viewer` att läsa träningar utan redigeringsmöjlighet.
- Perioden innehåller 27 träningstillfällen från 5 september till 12 december 2026.
- Träning sker måndagar 16:15–17:30 och lördagar 10:00–11:00.
- Ingen träning skapas för 26 eller 31 oktober 2026.
- Fem temablock och deras måndags-/lördagsupplägg hämtas från produktunderlaget.
- Varje träning får en egen kopia av blockets dagsupplägg. En ändring i ett tillfälle ändrar inte andra träningar.
- Källor och originalbilder från Svensk Innebandys Övningsbank ska attribueras och länkas. Bild är valfri när en säker och stabil originalkälla saknas.
- MVP har ingen automatisk synkronisering mot Övningsbanken.

## Vägledande tidsstruktur

### Måndag, 75 minuter

1. Samling och uppvärmning – cirka 15 minuter
2. Teknikstationer – cirka 15 minuter
3. Matchövning 1 – cirka 20 minuter
4. Matchövning 2 – cirka 20 minuter
5. Avslutande samling – cirka 5 minuter

### Lördag, 60 minuter

1. Samling och uppvärmning – cirka 15 minuter
2. Teknikstationer – cirka 15 minuter
3. Matchövning 1 – cirka 12 minuter
4. Matchövning 2 – cirka 13 minuter
5. Avslutande samling – cirka 5 minuter

Tidsvärden lagras som valfria vägledande minuter. Appen visar `cirka` och validerar inte att summan exakt motsvarar träningens längd.

## Användarupplevelse

### Navigation och översikt

- Lägg till `Träningar` i desktop- och mobilnavigationen.
- Överst visas nästa kommande träning med datum, tid, temablock, fokus, status och CTA `Öppna planeringen`.
- Därefter visas alla 27 tillfällen grupperade per temablock och i kronologisk ordning.
- Varje rad visar datum, tid, huvudbudskap och status.
- Empty state för en säsong utan träningar ska förklara att grundplanen ännu inte är inlagd.

### Träningsdetalj

- Visa datum, lokal Stockholmstid, total träningstid, block, fokus och huvudbudskap.
- Visa momenten i beslutad ordning med titel, vägledande tid, syfte, genomförande och coachingpunkter.
- Teknikdelen visar tre tydliga stationer och förklarar rotationen 5 minuter per station som vägledning.
- Övningar med källa visar länk `Öppna originalövningen` och originalbild när den är tillgänglig och tillåten att visa.
- Tränaranteckningar visas separat från den långsiktiga övningsbeskrivningen.
- Visa status samt vem som senast ändrade planen och när.

### Redigering

- Alla aktiva tränare kan redigera fokus, huvudbudskap, moment, ordning, vägledande minuter, syfte, genomförande, coachingpunkter, källänk och gemensamma anteckningar.
- Tränaren kan lägga till en egen övning och ta bort eller flytta ett moment inom det enskilda tillfället.
- Övningar från grundplanen är redigerbara kopior; källhänvisningen bevaras tills tränaren uttryckligen byter källa.
- Sparning sker som hela planens aktuella version i en atomisk operation.
- Vid samtidig ändring får den senare tränaren ett begripligt konfliktmeddelande och måste läsa in den senaste versionen innan nytt försök. Ingen ändring skrivs över tyst.

### Status

- `Ej planerad`: grundplanen finns men har inte granskats av tränarna.
- `Planerad`: en tränare har granskat och godkänt upplägget för tillfället.
- `Genomförd`: träningen har ägt rum.
- Status ändras uttryckligen av en tränare och aldrig automatiskt av klockan.
- En genomförd träning är skrivskyddad i normalflödet. Att återöppna den ligger utanför första versionen.

## Datamodell

### `training_sessions`

- `id uuid primary key`
- `team_id uuid not null`
- `season_id uuid not null`
- `starts_at timestamptz not null`
- `ends_at timestamptz not null`
- `theme_block smallint not null`
- `focus text not null`
- `key_message text not null`
- `coach_notes text null`
- `status training_session_status not null default 'draft'`
- `revision integer not null default 1`
- `updated_by uuid not null`
- `created_at`, `updated_at`

Unikhet: `(team_id, starts_at)`. Sluttiden måste vara efter starttiden. Tider skapas från `Europe/Stockholm` så att övergången mellan sommar- och vintertid blir korrekt.

### `training_items`

- `id uuid primary key`
- `training_session_id uuid not null`
- `team_id uuid not null`
- `season_id uuid not null`
- `section training_item_section not null`
- `position integer not null`
- `title text not null`
- `guide_minutes integer null`
- `purpose text null`
- `instructions text null`
- `coaching_points jsonb not null default '[]'`
- `source_url text null`
- `source_image_url text null`
- `created_at`, `updated_at`

Sektioner: `gathering`, `warmup`, `technique`, `match_exercise`, `closing`. Position ska vara unik inom en träning. Coachingpunkter valideras som en begränsad lista med korta texter.

## Grunddata

- Skapa ett versionshanterat, granskningsbart innehållsmanifest för fem block och tio dagsmallar: måndag/lördag per block.
- Expandera mallarna till 27 självständiga träningar genom ett idempotent bootstrap-kommando efter att lag och säsong finns.
- Bootstrap identifierar laget genom beslutad slug och säsongen genom namn, avbryter vid konflikt och skriver aldrig över en redan ändrad träning.
- Produktunderlagets generiska övningar måste kopplas till en exakt blå övning i Övningsbanken eller märkas tydligt som `Egen övning` innan innehållet betraktas som komplett.
- Riktiga tränaranteckningar eller andra personuppgifter får inte finnas i repots manifest eller testdata.

## Behörighet och säkerhet

- RLS följer samma aktiva lagmedlemskap som matcher och spelare.
- Aktiv `coach` får läsa och ändra träningar och moment för sitt eget lag och den aktiva säsongen. Aktiv `viewer` får endast läsa dem.
- Annat lag, outsider, inaktiv medlem och anonym användare nekas.
- Direkt klientmutation nekas. En server-only databasfunktion sparar hela planen atomiskt, verifierar tränarens aktiva medlemskap och jämför förväntad `revision`.
- `updated_by` sätts från den verifierade användaren på servern och accepteras inte från formuläret.
- Läsmodellen exponerar endast tränarens visningsnamn eller e-post när det uttryckligen bedöms lämpligt; internt användar-id visas aldrig i UI.

## Samtidighet och integritet

- Sparfunktionen låser `training_sessions`-raden före revisionskontroll.
- Fel revision ger `STALE_TRAINING_PLAN` utan partiella ändringar.
- Session och samtliga moment sparas i en transaktion.
- Exakt upprepad sparning med samma avsedda sluttillstånd ska vara ofarlig.
- Statusövergångar valideras i databasen: `draft → planned → completed`; bakåtövergång och redigering av `completed` ingår inte i MVP.
- Borttagning av en hel träning ingår inte.

## Källhantering

- Spara original-URL per övning, inte kopierad webbsidetext som extern sanning.
- Visa tydlig attribution till Svensk Innebandys Övningsbank.
- Originalbild används endast via en verifierad stabil källa och med källa synlig i samma vy.
- Om extern bild inte kan laddas ska text, instruktioner och källänk fortfarande fungera utan layoutfel.
- AI-genererade bilder får inte ersätta befintliga originalbilder.

## Ingår inte

- spelarnärvaro eller kallelser till träning
- individuella spelargrupper eller stationsindelning
- automatiska notifieringar
- automatisk import eller synk från Övningsbanken
- generell sökfunktion i hela Övningsbanken
- mallredigering som förändrar flera framtida träningar samtidigt
- versionshistorik med återställning
- skapa eller radera extra träningstillfällen
- återöppna en genomförd träning
- ytterligare roller utöver `coach` och den senare beslutade läsrollen `viewer`

## Acceptanskriterier

### Produkt

- Alla 27 beslutade tillfällen visas på rätt datum och lokal tid; 26 och 31 oktober saknas.
- Måndag visar 16:15–17:30 och lördag 10:00–11:00 även över övergången till vintertid.
- Varje träning startar med rätt block-, dags- och övningsinnehåll från manifestet.
- Vägledande minuter visas som ungefärliga och blockerar inte avvikande summor.
- En ändring i ett tillfälle påverkar inte någon annan träning.
- Alla aktiva tränare ser samma sparade plan och kan redigera den.
- Status och senaste ändring visas begripligt.

### Data och säkerhet

- Migrationerna skapar tabeller, typer, index, constraints, grants och RLS reproducerbart.
- Aktiv `coach` får läsa och spara eget lags plan. Aktiv `viewer` får läsa men nekas sparning; samtliga övriga negativa behörighetsfall nekas.
- Samtidiga sparningar kan inte tyst skriva över varandra.
- En misslyckad sparning lämnar session och moment oförändrade.
- Genomförd träning kan inte ändras genom ordinarie skrivflöde.
- Bootstrap kan köras flera gånger utan dubbletter eller överskrivning av användarändringar.

### UI och tillgänglighet

- Översikt, detalj och redigering fungerar vid 390 px utan horisontell scroll.
- Alla kontroller kan användas med tangentbord och har tydliga etiketter, fokuslägen och felmeddelanden.
- Loading, empty, error, populated, stale och success hanteras.
- Extern bilds failure state lämnar läsbart innehåll och fungerande källänk.

## Verifiering

1. Deterministiska tester för generering av de 27 datumen, undantagen och lokal tid/DST.
2. Domän- och valideringstester för moment, ordning, vägledande minuter och statusövergångar.
3. pgTAP för schema, constraints, RLS, grants, revision, atomisk sparning och genomförd-låsning.
4. Databasnära samtidighetstest där två tränare sparar samma revision och exakt en vinner.
5. Bootstrap-test för första körning, identisk retry och konflikt med ändrad befintlig träning.
6. Vitest för list-, detalj- och formuläradapter samt användarsäkra fel.
7. Lint, typkontroll, hela Vitest-sviten, hela pgTAP-sviten och produktionsbygge.
8. Lokal användarresa med två tränarsessioner: öppna samma träning, spara konflikt, ladda om, planera och genomför.
9. Mobil verifiering vid 390 px, tangentbord, konsol och nätverksfel för externa bilder.
10. Oberoende skrivskyddad agentgranskning av hela diffen mot avsedd bas.

## Föreslagen leveransordning

1. Schema, RLS, atomisk läs-/sparmodell och bootstrap-manifest.
2. Träningslista och nästa träning.
3. Träningsdetalj med källor och bilder.
4. Redigering, revisionskonflikt och statusflöde.
5. Full innehållskoppling till exakta blå övningar.
6. Mobil användarresa, säkerhetsverifiering och oberoende granskning.

## Definition av klar

Implementation 11 är integrationsklar när alla aktiva tränare kan se de 27 träningarna, gemensamt granska och ändra ett enskilt upplägg utan tyst överskrivning, markera status, använda planen på mobil och följa varje extern övning till verifierad originalkälla.
