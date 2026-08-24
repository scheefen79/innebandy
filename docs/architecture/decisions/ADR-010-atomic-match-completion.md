# ADR-010: Atomisk matchcompletion och deltagande

- Status: Accepterad
- Datum: 2026-08-24

## Kontext

Matchstatusen `completed` är samtidigt gränsen där planerade uttagningar blir faktisk historik. Om status och deltagande skrivs separat kan ordinarie rättvisa och extrarotation räkna ett halvfärdigt eller felaktigt resultat. Flera tränare kan dessutom försöka avsluta samma match samtidigt.

## Beslut

- Matchcompletion är en enda atomisk server-only databasoperation som uppdaterar `played` för varje aktuell selected-rad och därefter sätter matchstatus till `completed`.
- Input måste innehålla exakt ett booleskt beslut för varje `regular/selected` och `extra/selected` i matchen. Removed-rader ingår aldrig och behåller `played=false`.
- Matchen måste vara `upcoming`, ha passerad `starts_at` och ha exakt `target_players` ordinarie selected-rader.
- Match, uttagningsrader och manuella par låses i stabil ordning. Ett versionsmärkt fingeravtryck skyddar hela uttagningsunderlaget.
- Kontrollordningen är lås, behörighet/målidentitet, strukturell inputvalidering, en särskild completed-gren, domänvillkor för ny completion, stale, exakt setvalidering och mutation. Completed-grenen jämför fullständigt inskickat deltagande med det sparade före fingeravtrycket.
- Identisk retry konvergerar trots att completion har ändrat fingeravtrycket. Vid ett annat beslut efter att matchen genomförts gäller first-write-wins och `MATCH_ALREADY_COMPLETED`; Implementation 07 tillåter ingen efterhandsredigering.
- Den uppskjutna integritetsregeln för manuella ordinarie par tillåter `played=true` på selected-sidan endast när den kopplade matchens slutläge i samma transaktion är `completed`, och förbjuder det alltid på removed-sidan. `upcoming` och `cancelled` får aldrig ha ett manuellt par med spelad selected-rad. Paret och dess kopplingar bevaras för historik.
- Endast `status='completed'` tillsammans med rätt selection type och `played=true` får påverka respektive historik. Completion startar ingen omfördelning.
- Vanliga klientroller saknar UPDATE och EXECUTE. Den skyddade serverrouten verifierar session och databasen verifierar vidarebefordrat aktivt lagmedlemskap.

## Konsekvenser

- Matchstatus och rättvisehistorik kan aldrig hamna i olika transaktionstillstånd.
- Frånvaro kan redovisas utan att den planerade uttagningen eller manuella beslutet försvinner.
- Genomförda extra inhopp börjar påverka rekommendationen först vid completion.
- Samtidiga tränare kan inte skriva över varandras olika deltagandebeslut.
- Felregistrering efter save kan inte rättas i denna implementation; ett framtida korrigeringsflöde behöver revisionsspår och ett separat produktbeslut.

## Alternativ

- Sätta matchstatus först och deltagande senare: avvisas eftersom historikfrågorna då kan läsa ett halvfärdigt resultat.
- Skicka endast frånvaroavvikelser: avvisas eftersom exakt full input är enklare att validera och säkrare vid samtidighet.
- Radera frånvarande uttagningsrader: avvisas eftersom historiken måste skilja uttagen från deltog.
- Tillåta fri redigering av completed match: avvisas i denna fas eftersom revision, konfliktsemantik och rättviseomräkning kräver ett eget beslut.
