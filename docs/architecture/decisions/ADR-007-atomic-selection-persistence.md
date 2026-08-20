# ADR-007: Atomisk persistens av ordinarie uttagningar

- Status: Accepterad
- Datum: 2026-08-20

## Kontext

Fördelningsmotorn producerar ett resultat för flera matcher samtidigt. Om webbläsaren skriver rader en och en kan nätverksfel, samtidiga tränare eller ändrat underlag skapa halvskrivna eller inaktuella lag. Databasen behöver samtidigt bevara lag- och säsongsintegritet inför senare manuella val och extra inhopp.

## Beslut

- Den rena TypeScript-motorn fortsätter ansvara för rättvisa och nivåbalans.
- `match_players` lagrar uttagningstyp, källa, status och framtida deltagande separat enligt ADR-003.
- Tabellen duplicerar `team_id` och `season_id` och använder sammansatta foreign keys till både match och spelare för stark lagintegritet.
- Webbläsare och vanliga authenticated-klienter får endast läsa behöriga uttagningar, inte mutera tabellen direkt.
- En snäv PostgreSQL-funktion sparar en komplett automatisk ordinarie fördelning i en enda transaktion efter kontroll av `auth.uid()`, medlemskap och hela payloaden.
- Berörda matcher låses vid persistens så att samtidiga sparförsök serialiseras.
- Ett deterministiskt fingeravtryck av det serverlästa underlaget binder preview till save. Databasfunktionen låser källraderna och återskapar det versionsmärkta kanoniska underlaget innan jämförelsen. Ändrat underlag ger ett stabilt stale-preview-fel innan några rader ersätts.
- Fingeravtrycket är endast samtidighetsskydd. Funktionen validerar själv att resultatet innehåller exakt target unika, aktiva spelare från rätt lag och säsong för varje match.
- Funktionen ersätter endast automatiska ordinarie rader inom det godkända framtida scopet. Manuella och extra rader reserveras och får aldrig raderas av detta flöde.
- Samma aktuella resultat kan sparas flera gånger och konvergerar till samma persistenta tillstånd.

## Konsekvenser

- Ett fördelningsfel eller databasfel kan inte lämna vissa matcher uppdaterade och andra gamla.
- Två tränare kan inte oavsiktligt blanda två fördelningsresultat.
- RLS skyddar läsning medan mutationens mer komplexa invariants samlas i en testbar transaktionsgräns.
- Underlagsfingeravtrycket kräver en kanonisk och versionsmärkt serialisering. En framtida ändring av inputkontraktet måste versionshanteras.
- Omfördelning och manuella lås kan senare använda samma transaktionsgräns utan att flytta domänalgoritmen till databasen.

## Alternativ

- Flera klientstyrda inserts: avvisas eftersom de inte ger en säker atomisk helhetsoperation.
- Köra hela algoritmen i PostgreSQL: avvisas eftersom den verifierade TypeScript-domänen då dupliceras och blir svårare att testa.
- Spara direkt utan preview: avvisas i denna fas eftersom tränaren behöver se lag och varningar innan en hel säsongsfördelning skrivs.
- Acceptera save trots ändrat underlag: avvisas eftersom resultatet då kan baseras på gamla spelare, nivåer, matcher eller targets.
