# ADR-019: standardtrupp om tio kallade spelare per match

- Status: Accepterad
- Datum: 2026-09-17

## Kontext

Referensarket och den ursprungliga planeringen utgick från tolv ordinarie matchplatser per match. Appen har aldrig haft tolv hårdkodat: varje match bär sitt eget `matches.target_players`, och formuläret för ny match föreslog i stället hälften av de aktiva spelarna avrundat uppåt. Förslaget följde alltså truppens storlek och inte lagets faktiska matchupplägg, vilket gav olika antal platser beroende på hur många spelare som råkade vara aktiva.

Laget har beslutat att tio spelare ska kallas per match i stället för tolv.

## Beslut

- Standardtruppen är tio ordinarie spelare per match. Värdet finns på ett ställe, `src/features/matches/match-defaults.ts`, och används både av formuläret och av serverrutten som skapar matchen.
- Tio är ett förval, inte en spärr. Fältet `Antal matchplatser` finns kvar och en coach kan ange ett annat antal för en enskild match. Databasens enda regel är fortsatt `target_players > 0`.
- Kolumnen `matches.target_players` får `default 10`, så en match som skapas utan explicit antal hamnar rätt även utanför formuläret.
- Samtliga befintliga matcher skrivs om till tio platser, inklusive genomförda. Inga sparade uttagningar ändras eller tas bort.
- Förslagsregeln `ceil(aktiva spelare / 2)` tas bort. I stället varnar formuläret när laget har färre aktiva spelare än standardtruppen, eftersom fördelningen då inte går att generera (F1 i `docs/quality/allocation-test-cases.md`).

## Konsekvenser

- Fördelningsmotorn behövde ingen ändring. Den läser alltid `targetSize` per match, så rättvisan räknas om utifrån tio platser av sig själv.
- Referensfallet i `docs/quality/allocation-test-cases.md` och motsvarande domäntest går från 23 × 9 × 12 = 108 tilldelningar till 23 × 9 × 10 = 90. Varje spelare får då 3 eller 4 ordinarie matcher i stället för 4 eller 5.
- Genomförda matcher som redan hade tolv sparade ordinarie spelare har nu ett target på tio. Historiken i `match_players` är intakt och spelarstatistiken påverkas inte, men matchvyn kan visa fler uttagna än antalet platser för dessa matcher. Det är ett medvetet val för att hålla ett enda gällande truppvärde i hela appen.
- Beslutet ändras rimligen om laget byter serie eller spelform, eller om truppstorleken behöver skilja sig mellan seriematch och cup. Då bör antalet flyttas till säsongen i stället för till en konstant.
