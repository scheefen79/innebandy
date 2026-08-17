# ADR-006: Matchgrund, tidsmodell och behörighetsgräns

- Status: Accepterad
- Datum: 2026-08-17

## Kontext

Matchschemat blir nästa datagrund efter spelarna. Det behöver stödja svensk lokal inmatning, entydig lagring, lagisolering och senare uttagningar utan att Implementation 03 samtidigt introducerar hela matchlivscykeln.

## Beslut

- `matches` lagrar både `team_id` och `season_id` och använder en sammansatt foreign key så att matchens säsong alltid tillhör samma lag.
- Matchstart lagras som PostgreSQL `timestamptz`. Formulärvärden tolkas i `Europe/Stockholm` och presentation sker i samma tidszon.
- Obefintliga och tvetydiga lokala tider vid svensk tidsomställning avvisas i stället för att servern tyst väljer en offset.
- Databasstatus begränsas till `upcoming`, `completed` och `cancelled`; UI visar `Planerad`, `Genomförd` och `Inställd`.
- Nya matcher skapas alltid som `upcoming` och med ett positivt `target_players`. Både databasdefault och insert-policyns `WITH CHECK` upprätthåller statusen vid direkta Data API-anrop.
- Varje create-formulär bär ett UUID-baserat `request_id` med `unique (team_id, request_id)`. Det ger lag-scopad idempotens utan att förbjuda två legitima matcher med samma motståndare och starttid.
- Idempotens följer first-write-wins. Identisk normaliserad retry returnerar originalet; ändrad payload med samma lag och request-id ger konflikt och får aldrig uppdatera originalet.
- RLS använder aktivt `team_members`-medlemskap. Insert kräver dessutom att den refererade säsongen är aktiv och tillhör laget.
- Autentiserade klienter får endast `select` och `insert` i Implementation 03. `update` och `delete` öppnas inte innan motsvarande återställningsbara produktflöden och tester finns.
- Matchfrågor begränsas alltid till användarens aktiva lag och aktiva säsong. En obehörig eller okänd detalj returnerar samma not-found-beteende.
- Tidsberoende queries får en explicit `now`-parameter från applikationsgränsen och läser inte systemklockan inne i testbar querylogik.
- Uttagningar får en separat tabell och transaktionell persistens i Implementation 04; de modelleras inte provisoriskt i `matches`.
- `matches` får `unique (id, team_id)` så framtida `match_players` kan referera match och lag i samma foreign key.
- En databas-trigger underhåller `updated_at` från start. Authenticated får fortfarande ingen update-grant förrän ett kontrollerat ändringsflöde implementeras.

## Konsekvenser

- Samma lagrade tidpunkt visas konsekvent även över svensk sommar- och vintertid.
- Den duplicerade `team_id`-kolumnen ger stark dataintegritet och enkla, indexerbara RLS-villkor.
- Samma request-id kan användas i olika lag, medan parallella retries inom ett lag konvergerar till samma oföränderliga första skrivning.
- Matchskapande kan levereras och verifieras utan att öppna destruktiva eller halvfärdiga mutationer.
- Matchlistan visar tillfälligt `0 / target` tills uttagningspersistensen införs.
- Senare implementationer behöver migrationer och nya policies/grants för update, cancel och kontrollerad delete.

## Alternativ

- Lagra separat lokalt datum och tid: avvisas eftersom en match behöver en entydig kronologisk ordning och senare historik.
- Lagra endast `season_id`: avvisas eftersom lagintegritet och RLS då kräver indirekta joins överallt och felaktiga korskopplingar blir svårare att förhindra.
- Ge full CRUD direkt: avvisas eftersom permanent radering och genomförda matcher har andra produktregler och återställningskrav.
- Skapa `match_players` samtidigt: skjuts till Implementation 04 för att hålla matchgrund och atomisk uttagningspersistens separat verifierbara.
