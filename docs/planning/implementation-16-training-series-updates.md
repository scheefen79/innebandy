# Implementation 16: serieuppdatering av träningsplaner

- Status: Genomförs
- Beslut: ADR-020

## Mål

En tränare ska kunna hålla ett blocks veckodagsserie innehållsmässigt synkad med en enda sparning, utan att någon träning utanför serien påverkas. Redigeras en måndag i block 3 ska ändringen kunna gälla blockets övriga kommande måndagar; redigeras en lördag gäller den lördagarna.

## Acceptanskriterier

- Redigeringsvyn har två knappar: `Spara denna träning` och `Spara för alla <veckodagar> i block N (X st)`. Den enskilda ligger först, så att Enter i ett textfält aldrig sparar hela serien.
- Serieknappen visas bara när serien har minst ett kommande syskon, och antalet i etiketten stämmer med det servern faktiskt skriver.
- Serien omfattar samma lag, säsong, `theme_block` och samma veckodag räknat i `Europe/Stockholm`, med status `draft` eller `planned` och datum tidigast idag.
- `focus`, `key_message`, `coach_notes` och alla moment kopieras. `starts_at`, `ends_at`, `status` och `theme_block` lämnas orörda.
- Måndagar och lördagar är skilda serier och påverkar aldrig varandra.
- Passerade, genomförda och inställda träningar skrivs aldrig om.
- Hela operationen är en transaktion. Avvisas sparningen skrivs ingenting, varken till det redigerade passet eller till syskonen.
- Det redigerade passet behåller sin revisionskontroll. Syskonen skrivs över ovillkorligt men får `revision + 1`, så en kollega med ett öppet syskonformulär får `STALE_TRAINING_PLAN` vid sin nästa sparning.
- Klienten kan inte anropa `save_training_plan_series` direkt, och en aktiv viewer nekas.
- Mobilvyn fungerar utan horisontell scroll och båda knapparna har minst 44 px träffyta.

## Mått

| # | Mått | Målvärde |
|---|---|---|
| M1 | Sparningar för att uppdatera en veckodagsserie | 1 |
| M2 | Unika `focus`, `key_message` och momentlistor inom (block, veckodag) efter en serieparning | 1 / 1 / 1 |
| M3 | Rader utanför målmängden vars `revision` ändrats | 0 |
| M4 | Passerade, genomförda och inställda pass vars innehåll ändrats | 0 |
| M5 | Ändrade rader när sparningen avvisas | 0 |
| M6 | Regression på enskild sparning | 0 |
| M7 | Symmetri måndag och lördag | båda riktningarna gröna |

Mätfrågan för M2 och M3 finns i `docs/architecture/decisions/ADR-020-training-series-updates.md` samt i `supabase/tests/database/14_training_series_save.test.sql`, som täcker samma villkor som automatiska tester.

## Avgränsning

Detta ändrar hur en plan sprids, inte vad den innehåller. Ingår inte: att skapa eller radera träningstillfällen, att ändra tider eller veckodag, att propagera status eller närvaro, en blockscopad serie över båda veckodagarna, eller en levande mallkoppling mellan träningarna.
