# ADR-023: grundplan, externa kallelser och låst deltagande

- Status: Accepterat och lokalt implementerat/verifierat. Full databas- och kodgrind passerade i CI för `52a28a5` (453 pgTAP-tester och verkliga samtidighetstester).
- Datum: 2026-10-05
- Plan: `docs/planning/implementation-20-two-phase-match-planning.md`.

## Kontext

Kallelser skickas samma vecka i ett annat verktyg. Många återbud och sena ändringar innebär att faktisk trupp ofta är mindre än tio. Dagens kopplade ordinarie byten, krav på full ordinarie trupp och extra utanför målantalet passar inte arbetssättet. Sanna behöver kunna följa kallelser och svar utan separat spreadsheet.

## Beslut

- Generatorn skapar en grundplan för hela säsongen. När matchveckan startas bevaras planen och matchen undantas från omfördelning.
- Plan, kallelser/svar och faktisk medverkan hålls åtskilda. Det nya matchveckoflödet kräver inte kopplade bytespar.
- En ordinarie kallelse räknas som erbjuden först när den markeras som skickad externt. Den räknas en gång även vid nej eller indragen kallelse. Inställda matcher räknas inte. Framtida planerade platser ingår vid säsongsfördelning.
- Nivå används endast för balans. Den ordinarie rotationens slutliga utslagsregler är väntetid och fast säsongsordning.
- Spelare utanför grundplanen kallas som extra. Extra-ranking använder genomförda extra, erbjudna ordinarie, senaste extra och fast rotation. Endast faktisk medverkan ökar extraräknaren.
- Ja och obesvarade kallelser reserverar tillsammans högst tio platser, inklusive extra. Återbud eller indragen kallelse frigör plats utan krav på omedelbar ersättare.
- Matchtruppen kan ändras efter start fram till låsning. Faktiska deltagare registreras atomiskt efter start; ett till tio tillåts. Obesvarade kallelser måste först hanteras.
- Låst deltagande kan rättas av coach med obligatorisk anledning. Föregående och nya värden samt aktör och tidpunkt bevaras. Rättningen ändrar inte framtida plan automatiskt.
- Äldre kallelser kompletteras och bekräftas manuellt. Sparade uttagningar är förslag, inte bevis för skickade kallelser. Den nya generatorn spärras tills äldre ej inställda matcher i aktiv säsong är genomgångna.
- Hantering, svar och individuell statistik är coach-skyddade i både server och databas. Viewer behåller begränsad matchvy utan dessa uppgifter.
- Kallelser skickas fortsatt externt. Ingen integration eller kommunikationsfunktion införs.

## Tekniskt upplägg

Separata tabeller lagrar matchfas/revision, kallelser, låst deltagande och revisionshändelser. Den befintliga `match_players`-tabellen bevarar grundplan och äldre historik. Gemensamma läsmodeller kombinerar äldre data och det nya auktoritativa deltagandet utan dubbelräkning.

Server-only RPC:er sparar en hel åtgärd med coachkontroll, lag/säsongsintegritet, låsning, förväntad revision och request-id. Identiska återförsök returnerar tidigare resultat; ändrad payload med samma request-id nekas. Kapacitet kontrolleras i samma transaktion. Äldre skrivvägar måste neka mutation av frysta planer.

## Ersatta eller kompletterade beslut

- ADR-003/005/007: rättviseunderlaget övergår från faktiskt spelade ordinarie till erbjudna ordinarie; plan, kallelser och deltagande hålls isär.
- ADR-008/022: kopplade bytespar styr inte fas 2. Befintlig historik bevaras.
- ADR-009: extra ryms inom totalgränsen tio; full ordinarie trupp är inte ett krav i nya flödet.
- ADR-010: låsning kräver inte exakt målantal ordinarie och kan rättas kontrollerat.
- ADR-011: spelaröversikten kompletteras med erbjudna platser och total faktisk medverkan.
- ADR-019: tio är totalgräns för reserverade platser och nytt registrerat deltagande, inklusive extra. Äldre historik skrivs inte ned till tio.

Berörda äldre ADR-filer har en explicit ändringsnotering och hänvisning till detta beslut.

## Alternativ och konsekvenser

Att bara tillåta fler manuella byten löser inte obesvarade kallelser, återbud utan ersättare eller skillnaden mellan erbjudande och medverkan. Att importera svar automatiskt utökar scope och skapar ett externt beroende. Vi väljer manuell registrering och separata tillstånd eftersom det fungerar med nuvarande kallelseverktyg och kan verifieras oberoende.

Erbjudanderegeln innebär att en spelare som tackar nej eller får sin kallelse indragen kan ha färre faktiskt spelade matcher trots lika många erbjudanden. Båda måtten visas uttryckligen. Regeln är användarens val och ska inte ändras indirekt genom implementation.

Historikkomplettering är en engångsinsats som kräver mänsklig kontroll. Omfördelning blir skyddad från att skriva över pågående matchveckor. Fler tillstånd och rättningshistorik kräver särskilda negativa behörighets-, samtidighets- och migreringstester.

## Skäl att ompröva

Om kallelseverktyget erbjuder en godkänd integration, laget ändrar spelform eller rättvisan ska baseras på faktiskt deltagande i stället för erbjudanden behövs ett nytt uttryckligt beslut.

## Komplettering 2026-10-05

[ADR-024](ADR-024-cancel-and-preview-redistribution.md) gör inställning tillgänglig i båda faserna och öppnar förhandsgranskning av resterande grundplaner. Ny fördelning sparas uttryckligen; övriga frysta matchveckor och spelad historik bevaras.
