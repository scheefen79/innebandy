# ADR-020: serieuppdatering av träningsplaner per veckodag och block

- Status: Accepterad
- Datum: 2026-09-19

## Kontext

ADR-013 gjorde varje träning till ett självständigt objekt utan levande mallkoppling, och skrev samtidigt in konsekvensen att "en senare global malländring måste vara en uttrycklig funktion med egen konfliktmodell". Det här är den funktionen.

Ett temablock innehåller tre måndagar (16:15–17:30) och tre lördagar (10:00–11:00). Måndagarna delar upplägg med varandra och lördagarna med varandra, men de två veckodagarna har olika längd och olika övningsuppsättningar i blockmanifestet. En tränare som förbättrade måndagsupplägget fick tidigare skriva in samma ändring en gång per kvarvarande måndag, vilket både tog tid och gjorde att passen gled isär.

## Beslut

- Serien är härledd, inte lagrad: samma `team_id`, `season_id`, `theme_block` och samma veckodag räknat i `Europe/Stockholm`. Ingen `training_blocks`-tabell, ingen veckodagskolumn och ingen mallreferens. ADR-013:s lagringsmodell gäller alltså fortfarande.
- Serien är veckodagsscopad, inte blockscopad. En måndag sprids till blockets måndagar, en lördag till lördagarna. Funktionen är symmetrisk och innehåller inget måndagsspecifikt.
- Kopieras: `focus`, `key_message`, `coach_notes` och samtliga `training_items`. Kopieras inte: `starts_at`, `ends_at`, `status`, `theme_block`. Varje träning behåller sin egen tid, sin egen status och sin egen närvaro.
- Omfattningen är kommande pass: Stockholm-datum större än eller lika med dagens, och status `draft` eller `planned`. Passerade, genomförda och inställda träningar är historik och skrivs aldrig om.
- Allt sker i en transaktion. `save_training_plan_series` sparar det redigerade passet genom det oförändrade enskilda kontraktet `save_training_plan_unchecked` och propagerar därefter. En halvt applicerad serie kan inte uppstå.
- Konfliktmodell för syskonen: ovillkorlig överskrivning plus `revision + 1`. Det redigerade passet behåller sin optimistiska revisionskontroll.
- Idempotens återanvänder `last_save_request_id` och `last_save_payload_hash` per rad, med en hash som namnrymdas med `series` och utelämnar `requested_status`.
- Inget nytt index. `training_sessions_team_season_start_idx` täcker prefixet och en säsong rymmer ett trettiotal rader.

Ovillkorlig överskrivning valdes av fyra skäl: tränaren ser aldrig syskonens revisioner och har alltså inget att jämföra mot; operationens uttalade avsikt är att göra alla kommande pass på veckodagen lika det redigerade; revisionshöjningen bevarar ändå skyddet för en kollega, vars öppna formulär får `STALE_TRAINING_PLAN` vid nästa sparning; och `updated_by` sätts till den som sparade, så historiken förblir sann.

## Konsekvenser

- En tränare kan nu skriva över upp till två andra pass med ett klick. Det motverkas av att knappen anger exakt antal berörda träningar före klicket och att bannern efteråt namnger antalet.
- Ett block kan innehålla en `planned` och en `draft` måndag med identiskt innehåll, eftersom status inte propageras. Det är avsiktligt.
- Duplicerat övningsinnehåll är fortsatt lagringsmodellen, precis som i ADR-013.
- Knappen döljs när serien saknar kommande syskon, vilket också är hur ett passerat pass degraderar.
- Om blocken senare får riktiga veckodagsmallar är det här RPC:et den naturliga platsen att hänga dem på.

## Alternativ

- Levande mallreferenser: avvisas, det återinför precis det ADR-013 valde bort.
- Revisionskontroll per syskon: avvisas eftersom tränaren inte har syskonens revisioner och en enda samtidig redigering skulle avbryta hela operationen.
- Kopiera även status: avvisas eftersom genomförda pass då skulle återupplivas och närvaron bli fel.
- Blockscopad serie över båda veckodagarna: avvisas eftersom måndagar och lördagar har olika längd och olika övningar.
- Två anrop från serverrutten i stället för ett RPC: avvisas eftersom det inte är atomiskt och skulle kräva en egen konfliktmodell mellan anropen.
