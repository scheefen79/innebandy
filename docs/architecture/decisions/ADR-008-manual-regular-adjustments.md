# ADR-008: Manuella ordinarie byten som kopplade beslut

- Status: Accepterad
- Datum: 2026-08-20

## Kontext

En tränare behöver kunna flytta en ordinarie matchplats utan att bytet skrivs över vid nästa generering. Datamodellen måste samtidigt skilja manuella ordinarie beslut från extra inhopp, bevara exakt target och undvika halva byten vid samtidiga tränare eller nätverksfel.

## Beslut

- Ett manuellt ordinarie byte lagras som två ömsesidigt kopplade `match_players`-rader: en `manual/removed` för spelaren som går ut och en `manual/selected` för spelaren som går in.
- `replaced_player_id` pekar i båda riktningarna och används för att identifiera det exakta paret vid presentation och återställning.
- Databasen validerar med en `DEFERRABLE INITIALLY DEFERRED` constraint-trigger att varje `regular/manual`-rad vid transaktionens slut har exakt en ömsesidig motpart i samma match, lag och säsong, med en annan spelare och motsatt selection-status. Ensamma och korskopplade mutationer kan därmed inte committas.
- Skapa och återställ är separata atomiska server-only-funktioner. Vanliga `authenticated`-klienter saknar mutationsgrant och `EXECUTE`.
- Samma sessions-, medlemskaps- och service-role-gräns som ADR-007 återanvänds.
- Ett matchspecifikt fingeravtryck och radlås skyddar mot att två tränare ändrar samma gamla uttagningsläge.
- Skapande ersätter endast en utgående `regular/automatic/selected`-rad med det manuella paret utan att ändra matchens ordinarie target. En manuellt tillagd spelare måste återställas innan ett nytt byte som berör den kan skapas.
- Återställning tar bort paret och återskapar den utgående platsen som automatisk. Andra matcher räknas inte om implicit.
- Senare uttrycklig omfördelning behandlar `manual/selected` som include och `manual/removed` som exclude enligt ADR-005 och ADR-007.

## Konsekvenser

- Ett byte är observerbart, återställningsbart och kan aldrig sparas till hälften.
- UI kan visa begripliga etiketter utan att exponera tekniska lås.
- Den manuellt tillagda spelaren påverkar ordinarie rättvisa som en ordinarie plats men påverkar aldrig extrarotationen.
- Återställning återgår till den tidigare automatiska platsen; en full rättviseoptimering sker först när tränaren uttryckligen väljer omfördelning.
- Ömsesidiga par kräver uppskjuten databasvalidering och negativa tester för ensam insert/delete/update, korskoppling och flera rader som pekar på samma motpart.

## Alternativ

- Uppdatera endast `player_id` på den automatiska raden: avvisas eftersom orsaken, den borttagna spelaren och återställningsvägen då försvinner.
- Lagra endast den tillagda spelaren: avvisas eftersom motorn då inte kan bevara vem som uttryckligen ska stå över.
- Köra full omfördelning automatiskt efter varje byte: avvisas eftersom produkten kräver att redan genererade matcher inte ändras utan ett uttryckligt beslut.
- Blanda bytet med extra inhopp: avvisas eftersom ordinarie och extra är separata rättvisesystem.
