# ADR-009: Planerade extra inhopp som separat uttagning

- Status: Accepterad
- Datum: 2026-08-21

## Kontext

Tränarna behöver fylla tillfälliga luckor utan att ge samma spelare alla extramatcher och utan att störa den ordinarie rättvisan. En rekommendation är inte ett deltagandebevis: först när matchen senare markeras som genomförd ska ett extra inhopp påverka spelarens historik.

## Beslut

- En planerad extra inhoppare lagras som en egen `match_players`-rad med `extra/manual/selected`, `played=false` och utan `replaced_player_id`.
- Extra raden ligger utanför matchens ordinarie `target_players` och förändrar eller ersätter aldrig en ordinarie plats.
- Kandidatordningen byggs server-side från endast genomförda extra inhopp och använder ADR-005:s deterministiska extrafunktion. Den senaste genomförda extratidpunkten är den räknade matchens `starts_at`; uttagningsradens revisionsfält eller tiden då deltagandet sparades används inte. Nivå och ordinarie historik ingår inte.
- Kandidaten måste vara aktiv i samma lag och aktiva säsong och får inte ha någon uttagningsrad i matchen. Den regeln är starkare än enbart ”inte uttagen” eftersom datamodellen har `unique(match_id, player_id)` och ett manuellt borttaget ordinarie beslut ska förbli entydigt.
- Tränaren får välja en annan valbar kandidat än den högst rankade. Valet lagras först vid bekräftelse; förfrågningar och avböjanden lagras inte.
- Lägg till och ta bort är separata atomiska server-only-funktioner med samma sessions-, medlemskaps-, stale- och låsmönster som ADR-007 och ADR-008. Match- och spelar-id identifierar operationens mål entydigt. Kontrollordningen är lås, behörighet/målidentitet, actionspecifika domänvillkor, exakt sluttillstånd, stale-fingeravtryck och sist mutation. Identiska giltiga retries konvergerar därmed utan dubblett eller falskt stale-fel, men en genomförd, inställd eller passerad match kan aldrig godkännas som idempotent. Add kräver aktiv spelare även vid retry; remove får ta bort en befintlig planerad extra rad för en spelare som hunnit bli inaktiv.
- Direkt mutation och direkt RPC från webbläsarrollen förblir nekad. Endast de skyddade Next.js-routes som verifierar session får använda service-role-funktionerna.
- Ordinarie generering, omfördelning och manuella ordinarie byten måste uttryckligen bevara extra rader.
- `played` förblir `false` under hela Implementation 06. Genomförd match och faktisk deltagarregistrering införs i en senare implementation.

## Konsekvenser

- Extra rättvisa kan förklaras och testas oberoende av ordinarie rättvisa.
- En planerad extra spelare påverkar inte historiken förrän deltagandet faktiskt sparas.
- Flera extra inhoppare kan registreras till samma match utan att matchens ordinarie target förändras.
- En manuellt borttagen ordinarie spelare visas inte som extrakandidat i samma match. Om produkten senare ska stödja det krävs en förändrad unikhets- och beslutmodell.
- Servern behöver en kanonisk historikkälla för att undvika klientstyrd rankning och ett matchspecifikt fingeravtryck för att skydda kandidatens valbarhet och matchens skrivläge. Ändrad historik kan ändra den rådgivande rekommendationen men gör inte ett fortfarande valbart manuellt val stale.

## Alternativ

- Räkna planerade extra uttagningar direkt: avvisas eftersom produktbeslutet säger att endast faktiskt genomförda inhopp påverkar rättvisan.
- Låta nivå balansera extra kandidater: avvisas eftersom extrarotationen uttryckligen är nivåoberoende.
- Lagra förfrågningar och avböjanden: avvisas som onödig person- och processdata i MVP.
- Uppdatera ordinarie target när en extra läggs till: avvisas eftersom extra inhopp är ett separat system och inte en ordinarie plats.
- Tillåta direkt klientinsert med RLS: avvisas eftersom stale-kontroll, medlemskapsverifiering och samtidighet ska hållas i en atomisk servergräns.
