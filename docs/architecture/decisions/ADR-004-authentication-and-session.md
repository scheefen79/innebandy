# ADR-004: Inloggning och sessionshantering

- Status: Accepterad
- Datum: 2026-08-14

## Kontext

MVP:n används av tre tränare med separata Supabase Auth-konton. Produktspecifikationen tillåter magic link eller e-post och lösenord. Next.js behöver kunna verifiera användarens identitet på servern innan lagdata renderas.

## Beslut

- MVP använder e-post och lösenord. Kontona skapas manuellt; appen har ingen publik registrering.
- `@supabase/ssr` lagrar och uppdaterar sessionen i cookies för både server och webbläsare.
- Next.js Proxy uppdaterar sessionen och skickar oinloggade användare till `/login`.
- Skyddade servervyer verifierar identiteten med `getClaims()` och kontrollerar aktivt `team_members`-medlemskap innan lagytan visas.
- Inloggningsfel är generiska och avslöjar inte om ett konto existerar.
- Endast Supabases publika publishable key används i webbapplikationen. Service role-nyckeln får inte finnas i webbläsarkod.

## Konsekvenser

- Tränarna behöver hantera lösenord, men appen är inte beroende av e-postleverans vid varje inloggning.
- Lösenordsåterställning och produktions-SMTP behöver konfigureras innan skarp drift, men ingår inte i denna implementation.
- Autentisering i proxy ersätter inte RLS; båda lagren måste fortsätta verifieras.
- Auth-sidor och skyddade routes får inte serveras från en delad cache.

## Alternativ

- Magic link: avvaktas eftersom det kräver e-postcallback, mallar och tillförlitlig SMTP för skarp drift.
- Delat tränarkonto: avvisat i ADR-002 eftersom separata konton krävs för säkerhet och spårbarhet.

## Uppdatering

ADR-015 ändrar hur skyddade sidor tar del av proxyns verifiering (en delad request-header istället för att varje sida anropar `getClaims()` igen) och rättar samtidigt att `proxy.ts` låg fel i filträdet och aldrig kördes. Proxyns roll och RLS som auktoritativ kontroll är oförändrade.
