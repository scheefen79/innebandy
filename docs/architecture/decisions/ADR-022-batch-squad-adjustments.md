# ADR-022: Atomiska batcher för manuella byten och extra inhoppare

- Status: Accepterad
- Datum: 2026-10-01

## Kontext

Tränare vill byta flera ordinarie spelare och lägga till flera extra inhoppare i samma match. De befintliga funktionerna (ADR-008, ADR-009) hanterar en spelare eller ett par åt gången och skyddas av ett matchspecifikt fingeravtryck som ändras efter varje skrivning. Anrop i följd ger därför `stale` från andra anropet, och att hämta nytt fingeravtryck mellan anropen ger halvsparade ändringar.

## Beslut

- Två nya server-only-funktioner sparar en hel batch i en transaktion med ett fingeravtryck: `create_manual_regular_adjustments` (lista av ut/in-par) och `add_extra_substitutes` (lista av spelar-id).
- Antalet som står över är alltid lika med antalet som läggs till. Matchens `target_players` ändras inte. Mindre trupp kräver ett separat produktbeslut.
- Varje par lagras som två ömsesidigt kopplade rader enligt ADR-008 och kan återställas enskilt. Den uppskjutna constraint-triggern är oförändrad och avgör vad som kan committas.
- Villkoren per element är oförändrade från ADR-008/009. Ut-spelare är `regular/automatic/selected`; in-spelare och extra-spelare är aktiva, i samma lag och säsong, utan rad i matchen. Manuellt borttagna spelare kan alltså inte bli extra.
- Dubbletter, överlappande id:n och olika antal ut och in avvisar hela batchen. Samma lås-, behörighets-, stale- och idempotensordning som ADR-009 gäller. Direkt RPC från webbläsarrollen förblir nekad.
- De enkla funktionerna behålls; UI kan anropa batchen även för ett element.

## Alternativ

- Loopa över de enkla funktionerna: avvisas eftersom det ger stale-fel eller halvsparade batcher.
- Tillåta byte utan ersättare: avvisas nu eftersom det ändrar target och rättvisemodellen.
- Låta systemet para ut och in automatiskt: avvisas eftersom återställning per par då blir oförutsägbar.
- Tillåta extra för manuellt borttagna spelare: avvisas eftersom det motsäger tränarens beslut i samma match och kräver ny unikhetsmodell.

## Konsekvenser

- Fler och större atomiska funktioner kräver fler negativa databastester.
- Spec 8.7 och 8.8 samt `open-questions.md` beslut 5 behöver uppdateras när planen godkänns.

## Skäl att ompröva

- Tränare behöver spela med färre spelare.
- Tränare behöver extra för spelare som tagits bort manuellt.
