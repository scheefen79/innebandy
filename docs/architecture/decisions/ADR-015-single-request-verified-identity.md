# ADR-015: Engångsverifierad identitet per request

- Status: Accepterad
- Datum: 2026-08-26

## Kontext

Prestandaarbetet i `codex/overview-next-training-performance` visade att varje skyddad sida och route verifierade JWT:n med `supabase.auth.getClaims()` en gång till, trots att Next.js Proxy redan gör exakt samma verifiering för varje request (ADR-004). Det är dubbelarbete på alla ~25 skyddade vyer och API-routes.

Under verifieringen av ändringen upptäcktes att `proxy.ts` låg i repo-roten, medan appen ligger under `src/app/`. Next.js kräver att `proxy.ts` ligger på samma nivå som `app`-katalogen (dvs. `src/proxy.ts`) för att filen ska registreras. Filen kördes därför aldrig i produktion eller lokal drift — byggutdata saknade helt raden `ƒ Proxy (Middleware)`. Appen fungerade ändå eftersom varje sida gjorde sin egen, kompletta `getClaims()`-kontroll oberoende av proxyn. Detta är alltså en existerande felkonfiguration som fanns innan detta arbete, men som först blev synlig och allvarlig när sidkontrollerna gjordes beroende av proxyns resultat.

## Beslut

- `proxy.ts` flyttas till `src/proxy.ts` så att Next.js faktiskt registrerar och kör den.
- Proxyn verifierar JWT:n en gång per request och skriver `sub` till en request-header (`x-innebandy-verified-user-id`, definierad i `src/lib/auth/verified-user-header.ts`) via `NextResponse.next({request})`. Mekanismen skriver om headern på det inkommande request-objektet och kan därför inte förfalskas av klienten.
- Skyddade sidor och route-handlers läser identiteten med `getVerifiedUserId()` (`src/lib/auth/verified-user.ts`) istället för att anropa `getClaims()` igen.
- RLS och `loadTeamContext`/domänfrågorna förblir oförändrade och är fortsatt den auktoritativa behörighetskontrollen; header-läsningen ersätter bara den redundanta JWT-verifieringen, inte databasens rättighetskontroll.

## Konsekvenser

- En JWT-verifiering per request istället för två, på samtliga skyddade sidor och routes.
- Proxyn är nu ett verkligt, nödvändigt beroende för autentisering (tidigare var den dead code). Om `proxy.ts` av misstag flyttas eller matcher-konfigurationen ändras så att en route inte längre täcks, kan sidan tappa sin auktoriseringskontroll helt eftersom den inte längre gör en egen fallback-verifiering. Detta vägs upp av att Next.js body i byggutdata visar `ƒ Proxy (Middleware)` när den är korrekt registrerad, vilket bör kontrolleras vid framtida ändringar av filstrukturen.
- Verifierat lokalt: obehörig request får ett äkta 307-svar till `/login` direkt (inte längre en streamad Suspense-shell), och en inloggad testcoach fick verklig säsongsdata via headern, i både `next dev` och en produktionsbyggd server.

## Alternativ

- Låta varje sida fortsätta verifiera JWT:n själv (nuvarande läge innan detta beslut): enklare men dubbelarbete på varje request, och det underliggande proxy-placeringsfelet hade förblivit dolt.
- React `cache()` för att memoisera `getClaims()` per request: löser inte grundproblemet eftersom Proxyn ändå gör en egen, separat verifiering före sidan renderas.
