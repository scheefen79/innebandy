# ADR-011: atomisk spelarhantering och separat historik

- Status: Accepterad
- Datum: 2026-08-24

## Kontext

Tre tränare delar samma lag och kan skapa eller ändra spelare samtidigt. `rotation_order` är den sista deterministiska utslagsregeln i ordinarie och extra rotation och får därför varken kollidera eller återanvändas godtyckligt. Spelarändringar får samtidigt inte tyst skriva om sparade uttagningar. Spelarvyn behöver redovisa ordinarie matcher och extra inhopp som två oberoende rättvisesystem.

## Beslut

- Browsern får läsa lagets spelare via RLS men spelarens mutationer går genom server-only databasfunktioner.
- Skapande låser den aktiva säsongen och tilldelar `max(rotation_order)+1`. En deaktiverad spelares ordning återanvänds inte.
- Varje create-formulär har ett stabilt UUID `request_id` som lagras på spelaren och är unikt. Identisk normaliserad input med samma id konvergerar till befintlig spelare; annan input med samma id nekas.
- Ändring och deaktivering låser spelaren och använder ett versionsmärkt fingeravtryck för first-write-wins.
- `players` får ett automatiskt `updated_at` som ingår i fingeravtrycket.
- Namn, nivå och `is_active` är de enda föränderliga spelaruppgifterna i MVP. Lag, säsong och rotationsordning kan inte ändras genom UI.
- Deaktivering är soft delete och ändrar aldrig `match_players`.
- Deaktivering blockeras om spelaren finns på någon sida i ett framtida manuellt ordinarie par eller som framtida extra inhoppare. Tränaren måste först återställa hela paret respektive ta bort extra-raden. Därmed kan två inaktiva spelare aldrig lämnas i ett manuellt par som inte kan återställas.
- Framtida automatiska ordinarie rader får bevaras vid själva deaktiveringen och hanteras därefter genom uttrycklig omfördelning.
- En identisk deactivate-retry kontrolleras efter lås och målidentitet men före stale och returnerar det redan uppnådda sluttillståndet. Edit av en inaktiv spelare nekas.
- Spelarens historikkälla härleds från `matches` och `match_players`; aggregerade räknare lagras inte på `players`.
- Ordinarie och extra redovisas separat. Endast `selected` ingår; `played` avgör genomförd respektive frånvarande på en completed match.
- Skapande, nivåändring och deaktivering utlöser ingen automatisk omfördelning. Tränaren får en tydlig signal och väljer omfördelning uttryckligen.

## Konsekvenser

- Rotation förblir deterministisk även när två tränare skapar spelare samtidigt.
- Ett tappat create-svar kan skickas igen utan att skapa en andra spelare.
- Historik och uttagningar bevaras vid deaktivering.
- Ett namnbyte visas även i historiska matcher eftersom MVP lagrar spelaridentitet, inte ett namn-snapshot.
- Det kan tillfälligt finnas framtida uttagningar för en deaktiverad spelare tills tränaren omfördelar. UI måste förklara detta och får inte kalla fördelningen uppdaterad.
- Historikfrågan behöver testas mot status, selection type/status och `played` för att undvika sammanblandning av rättvisesystemen.

## Avvisade alternativ

- Direkt INSERT/UPDATE från browsern: avvisas eftersom atomisk rotation, medlemskontroll, stale-skydd och stabil felmappning annars sprids över klienter.
- Enbart säsongslås vid skapande: avvisas eftersom det hindrar rotationskollision men inte dubbelregistrering efter ett tappat svar.
- Återanvänd lägsta lediga rotationsnummer: avvisas eftersom deaktivering då kan ändra den fasta säsongsordningens betydelse.
- Lagra räknare på spelaren: avvisas eftersom de kan avvika från den kanoniska matchhistoriken.
- Radera spelaren permanent: avvisas eftersom historiska matchkopplingar ska bevaras.
- Omfördela automatiskt vid ändring: avvisas eftersom produkten kräver ett uttryckligt tränarbeslut och bevarande av manuella val.
