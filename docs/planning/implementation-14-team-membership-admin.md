# Implementation 14: lagmedlemsadministration

- Status: Integrationsklar lokalt. Oberoende skrivskyddad granskning genomförd; två P1-fynd (deadlock i minst-en-aktiv-coach-invarianten under samtidighet, samt avsaknad av det efterfrågade concurrency-testet) rättade och verifierade med ett nytt concurrency-test. P2-dokumentationsfynd rättade. P3 UI-fynd rättat. Kvar: verklig produktionsverifiering (redan konfigurerad SMTP och redirect-URL; en riktig inbjudan i produktion är otestad).
- Föreslagen: 2026-09-03
- Arkitekturbeslut: `docs/architecture/decisions/ADR-017-team-membership-administration.md`

## Syfte

Låta en coach lägga till, ändra roll för och inaktivera/återaktivera lagmedlemmar direkt i appen, utan att gå via Supabase SQL Editor, samtidigt som databasen förblir den auktoritativa behörighetsgränsen:

```text
Coach öppnar "Medlemmar"
  → ser aktiva och inaktiverade medlemmar med roll
  → bjuder in en ny medlem med e-post och roll
    → Supabase Auth skickar en inbjudningslänk
    → mottagaren sätter sitt eget lösenord och loggas in
  → kan ändra roll för en befintlig medlem
  → kan inaktivera en medlem (kräver minst en kvarvarande aktiv coach)
  → kan återaktivera en tidigare inaktiverad medlem
```

## Scope

- Ny sida i appen (coach-only) för att lista, bjuda in, ändra roll för och inaktivera/återaktivera lagmedlemmar.
- Serverfunktioner för att bjuda in, lista, ändra roll, inaktivera och återaktivera — alla coach- och service-role-skyddade.
- Nytt autentiseringsflöde: hantera Supabase-inbjudningslänken (kodutbyte mot session) och en sida där mottagaren sätter sitt första lösenord.
- En ny databasinvariant: laget kan aldrig bli utan aktiv coach.
- Kontraktstester och pgTAP-matris för alla nya funktioner, inklusive negativa fall.

## Ingår inte

- En separat adminroll ovanför coach (se ADR-017, alternativ).
- Självregistrering eller en öppen inbjudningslänk utan namngiven e-postmottagare.
- Byte av e-postadress för en befintlig medlem.
- Radering av medlemskap.
- Hantering av flera lag per coach eller per konto.

## Leveransordning

### 0. Förutsättning: e-postleverantör

Supabases inbyggda e-postutskick är begränsat till 2 e-postmeddelanden per timme, totalt för hela projektet, delat mellan inbjudningar, lösenordsåterställningar och allt annat Auth skickar. Det räcker inte ens för de tre ursprungliga tränarna i följd och gör funktionen opålitlig från första användningen.

Laget har varken en egen domän eller avsikt att skaffa en. Renodlade e-postleverantörer (Resend, Brevo, MailerSend m.fl.) kräver domänverifiering (DNS-poster) för att skicka till andra mottagare än det egna kontot, vilket gör dem opraktiska här. Vald lösning är istället att konfigurera custom SMTP i Supabase mot **Googles egen SMTP-server** (`smtp.gmail.com`) med ett dedikerat Gmail-konto (t.ex. `fbcsollentunap17@gmail.com`) och ett genererat App Password. Ingen domän krävs, kontot är gratis, och gränsen på 500 mottagare/dygn ligger långt över lagets faktiska behov. Custom SMTP ingår i nuvarande Supabase Free-plan utan kostnad.

Detta verifieras genom att skicka en riktig testinbjudan från det dedikerade Gmail-kontot och bekräfta att den kommer fram inom rimlig tid, inte bara att Supabase-anropet lyckas.

### 1. Databas: minst-en-aktiv-coach-invarianten

- Lägg till en delad kontroll (t.ex. `private.team_would_lack_active_coach(target_team_id, excluded_user_id)`) som avgör om en given ändring skulle lämna laget utan aktiv coach.
- pgTAP-test som visar att lagets sista aktiva coach inte kan inaktiveras eller nedgraderas till `viewer`, varken direkt eller via två samtidiga transaktioner.

### 2. Databas: läsning och skrivning av medlemslistan

- `get_team_member_list(target_team_id)`: coach-only, `SECURITY DEFINER`, joinar `team_members` mot `auth.users` för e-post och skickar aldrig ut mer än e-post, roll, status och tidsstämplar.
- `upsert_team_member`, `update_team_member_role`, `deactivate_team_member`, `reactivate_team_member`: service-role- och coach-verifierade, med `request_id` respektive `expected_fingerprint` för idempotens och samtidighetsskydd — samma mönster som `create_player`/`update_player`/`deactivate_player`.
- Samtliga skrivfunktioner anropar minst-en-aktiv-coach-kontrollen innan de tillåter en nedgradering eller inaktivering.

### 3. Serverroute för inbjudan

- En route som verifierar aktiv coach, anropar Supabase Admin Auth (`auth.admin.inviteUserByEmail`) med en `redirectTo`-länk till appens sätt-lösenord-sida, och därefter skriver medlemskapet via steg 2:s funktioner.
- Hantera edge-fall uttryckligen: e-post tillhör redan en aktiv medlem, e-post tillhör ett inaktiverat konto (erbjud återaktivering istället för ny inbjudan), ogiltig eller okänd roll.

### 4. Sätt-lösenord-flöde

- En route som tar emot Supabase-inbjudningslänkens kod och byter den mot en session.
- En sida där personen sätter sitt lösenord innan de kan använda resten av appen.
- Ett begripligt felmeddelande för en utgången eller redan använd länk, utan att exponera vems e-post eller roll som var kopplad till den.

### 5. UI

- Ny navigationspunkt (coach-only) i `AppShell`, på samma sätt som `Spelare` idag är dold för `viewer`.
- Lista aktiva medlemmar med roll-väljare och en "Inaktivera"-knapp; lista inaktiverade medlemmar med en "Återaktivera"-knapp; formulär för att bjuda in en ny medlem med e-post och roll.
- Tydligt fel i UI:t när en åtgärd skulle lämna laget utan aktiv coach, innan förfrågan ens skickas där det går, och som ett begripligt felmeddelande om databasen ändå nekar den.

### 6. Slutlig verifiering

- Lint, typkontroll, hela Vitest-sviten, hela pgTAP-sviten, produktionsbygge.
- Manuell verifiering: bjud in en riktig testadress, sätt lösenord via länken, logga in och verifiera tilldelad roll; försök inaktivera lagets sista coach och bekräfta att det nekas; testa en utgången/förbrukad länk.
- Oberoende skrivskyddad granskning av hela diffen, med särskilt fokus på inbjudningsflödet och minst-en-aktiv-coach-invarianten.

## Acceptanskriterier

### Coach

- Ser en lista över aktiva och inaktiverade medlemmar med roll.
- Kan bjuda in en ny medlem med vald roll via e-post.
- Kan ändra roll för en befintlig aktiv medlem.
- Kan inaktivera en aktiv medlem, utom när det är lagets sista aktiva coach.
- Kan återaktivera en tidigare inaktiverad medlem.

### Inbjuden person

- Får ett e-postmeddelande med en inbjudningslänk.
- Kan sätta sitt eget lösenord via länken och loggas därefter in med sin tilldelade roll.
- En redan använd eller utgången länk ger ett begripligt felmeddelande, inte en krasch eller en oautentiserad session.

### Viewer

- Har fortsatt inte åtkomst till adminvyn eller någon av dess serverfunktioner.

## Negativa säkerhetsfall

- En `viewer`, outsider, inaktiv medlem eller anonym användare nekas alla adminfunktioner (lista, bjuda in, ändra roll, inaktivera, återaktivera).
- Ett annat lags coach kan inte hantera detta lags medlemmar.
- Ingen kan inaktivera eller nedgradera lagets sista aktiva coach, inte ens sig själv.
- En vidarebefordrad identitet i en servermutation verifieras på nytt i databasen, precis som för befintliga mutationer.
- En uttjänt eller redan förbrukad inbjudningslänk ger inte åtkomst till kontot eller till appen.

## Verifiering

1. pgTAP-matris för minst-en-aktiv-coach-invarianten, inklusive samtidiga förfrågningar.
2. pgTAP-matris för alla nya funktioner: coach, viewer, outsider, inaktiv medlem, annat lag, anonym användare.
3. Kontraktstester som visar att medlemslistan aldrig innehåller mer än e-post, roll och status.
4. Route- och komponenttester för den nya navigationspunkten, formulären och felmeddelandena.
5. Manuellt test av hela inbjudningsresan med en riktig e-postadress, inklusive en utgången länk.
6. Regressionstester för befintliga coach- och viewer-resor.

## Risker och återställning

- Största risken är en logikbugg i minst-en-aktiv-coach-kontrollen som antingen låser ute laget permanent eller inte skyddar mot att laget låses ute. Testas explicit med samtidiga förfrågningar, liknande de befintliga concurrency-skripten i `supabase/tests/database`.
- E-postleverans är beroende av Supabase-projektets e-postkonfiguration. Med Supabases inbyggda avsändare (utan custom SMTP) är gränsen 2 e-postmeddelanden per timme för hela projektet, vilket gör funktionen opålitlig redan vid normal användning. Custom SMTP mot Gmails SMTP-server via ett dedikerat Gmail-konto måste vara konfigurerat innan lansering (se steg 0); detta ingår i nuvarande Free-plan utan kostnad och kräver ingen egen domän.
- Ett vanligt Gmail-konto som SMTP-relä är inte avsett för produktionsvolymer. Googles missbruksdetektering kan tillfälligt låsa kontot vid plötsliga skurar av utskick. Vid lagets faktiska volym (enstaka inbjudningar/återställningar) bedöms risken som låg, men den finns och kräver i så fall en manuell inloggning för att låsa upp kontot igen.
- Om adminvyn av någon anledning är otillgänglig kvarstår SQL Editor-processen som redan dokumenterad reservväg.
- Återställning: de nya serverfunktionerna kan stängas av (`revoke execute`) utan att påverka övrig funktionalitet, tills en eventuell brist är rättad och verifierad.

## Definition av klar

Implementation 14 är integrationsklar när en coach kan hantera lagets medlemmar och roller helt inuti appen utan att gå via Supabase, minst-en-aktiv-coach-invarianten är verifierad även under samtidighet, viewer och obehöriga är verifierat utestängda från alla nya funktioner, och en oberoende skrivskyddad granskning inte har några kvarvarande fynd.

## Genomförd verifiering

- ESLint: godkänd.
- TypeScript: godkänd.
- Vitest: 39 testfiler och 135 tester godkända.
- pgTAP: 12 testfiler och 325 tester godkända, inklusive rollmatrisen för medlemsadministration.
- Concurrency: nytt test (`db:test:team-concurrency`) verifierar att två coacher som samtidigt inaktiverar varandra serialiserar utan deadlock och aldrig lämnar laget utan aktiv coach; körd upprepade gånger utan flaky-beteende.
- Next.js produktionsbygge: godkänt, alla nya routes registrerade.
- Manuell verifiering: fullständig inbjudningsresa mot en riktig Mailpit-fångad e-post lokalt (inbjudan → mejl → länk → sätt lösenord → korrekt viewer-session med rätt rollbaserad navigation). En riktig bugg hittades och rättades under detta arbete: sätt-lösenord-sidan litade tidigare på "finns en session" istället för "kom en ny session från länken", vilket kunde byta en redan inloggad persons eget lösenord.
- Oberoende skrivskyddad granskning: två P1-fynd (deadlock i invarianten under samtidighet; saknat concurrency-test) rättade och omverifierade. Ett P2-fynd (dokumentationsdrift i lokal guide och produktionsrunbook) rättat. Ett P3-fynd (UI förhindrade inte klientsidan åtgärder mot lagets sista coach) rättat.

Kvarvarande manuell verifiering före skarp drift: en riktig inbjudan i produktionsmiljön (SMTP och redirect-URL är konfigurerade enligt användaren, men själva flödet är inte testat mot den skarpa Supabase-instansen). Ingen commit, push eller deployment ingår i den lokala implementationen.
