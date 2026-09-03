# ADR-017: Lagmedlemsadministration i appen

- Status: Föreslagen
- Datum: 2026-09-03

## Kontext

Idag måste projektägaren lägga till, ändra roll för eller inaktivera en lagmedlem manuellt i Supabase SQL Editor eller Table Editor (se `docs/development/supabase-local.md` och produktionsrunbooken). Det fungerar för de ursprungliga tre tränarna men skalar inte när fler tränare eller besökare (`viewer`, se ADR-016) ska läggas till löpande, och kräver att varje ändring görs av någon med direkt åtkomst till Supabase-projektet.

ADR-002 uteslöt uttryckligen medlemsadministration i MVP:t. ADR-016 införde rollen `viewer` men ändrade inte hur medlemskap skapas eller ändras.

## Beslut

- En ny, coach-skyddad adminvy byggs i appen för att lista, bjuda in, ändra roll för och inaktivera/återaktivera lagmedlemmar.
- Alla aktiva coacher får åtkomst till adminvyn. Ingen ny roll utöver `coach`/`viewer` införs.
- Ett nytt medlemskap skapas genom en e-postinbjudan: adminen anger e-post och roll, Supabase Auth skickar en inbjudningslänk, mottagaren sätter sitt eget lösenord vid första inloggning. Appen hanterar aldrig lösenord åt någon annan än den inloggade själv.
- Borttagning av åtkomst är alltid en inaktivering (`is_active=false`), aldrig en radering av medlemskapsraden, i linje med den återställningsprincip som redan gäller enligt ADR-016.
- Varje lag måste ha minst en aktiv coach. Databasen vägrar en rolländring eller inaktivering som skulle lämna laget utan aktiv coach, oavsett vem som initierar den och oavsett hur många samtidiga förfrågningar som görs.
- Alla skrivande operationer (bjuda in, ändra roll, inaktivera, återaktivera) går genom service-role-skyddade, coach-verifierade databasfunktioner enligt samma mönster som redan används för spelar- och matchmutationer (privat "unchecked"-implementation bakom en tunn kontrollerad wrapper). Ingen direkt skrivrätt till `team_members` eller `auth.users` ges till `authenticated`.
- Läsning av medlemslistan (inklusive e-postadress, som ligger i `auth.users`) sker via en `SECURITY DEFINER`-funktion som kräver aktiv coach, på samma sätt som `get_player_list`.
- SQL Editor-processen i produktionsrunbooken och den lokala utvecklingsguiden behålls som en oberoende reservväg, men blir inte det primära arbetssättet.

## Konsekvenser

- Tränarna kan själva hantera vilka som har åtkomst utan att någon behöver gå in i Supabase-projektet för vardagliga ändringar.
- Appen får för första gången ett flöde för att skapa nya autentiserade konton och en sida där en inbjuden person sätter sitt första lösenord. Det är ny attackyta som måste testas noga.
- Supabases inbyggda e-postutskick är begränsat till 2 e-postmeddelanden per timme för hela projektet, delat mellan inbjudningar, lösenordsåterställningar och allt annat Auth skickar — otillräckligt för normal användning. Custom SMTP måste konfigureras innan funktionen tas i drift. Custom SMTP ingår i nuvarande Supabase Free-plan utan kostnad; ingen uppgradering av prisplanen krävs.
- Laget har ingen egen domän och avser inte skaffa någon. Renodlade e-postleverantörer (Resend, Brevo, MailerSend m.fl.) kräver domänverifiering för att skicka till andra mottagare än det egna kontot och är därför inte praktiskt användbara utan en domän. Valet föll istället på Googles egen SMTP-server (`smtp.gmail.com`) via ett dedikerat Gmail-konto och ett App Password — gratis, kräver ingen domän, och gränsen på 500 mottagare/dygn ligger långt över lagets faktiska behov. Ett vanligt Gmail-konto som relä är dock inte avsett för produktionsvolymer och kan tillfälligt låsas av Googles missbruksdetektering vid ovanliga utskicksmönster.
- "Minst en aktiv coach"-regeln är en ny invariant i datamodellen som måste testas explicit, inklusive vid samtidiga förfrågningar.
- ADR-002:s ursprungliga ställningstagande att ingen medlemsadministration byggs ersätts härmed för produktionsbruk; SQL-vägen kvarstår som reservväg.

## Alternativ

- Fortsätta hantera allt via SQL Editor: avvisas eftersom det inte skalar till fler tränare/besökare och kräver Supabase-åtkomst för varje ändring.
- En separat adminroll ovanför coach: avvisas nu för att hålla rollmodellen liten; kan omprövas om lagets storlek eller antal coacher växer betydligt.
- Adminen sätter lösenord direkt i formuläret istället för e-postinbjudan: avvisas eftersom appen då skulle hantera och tillfälligt känna till någon annans lösenord, vilket ökar risken och bryter mot principen att aldrig hantera andras autentiseringsuppgifter i klartext genom applikationskoden.
- Hård radering av medlemskap: avvisas av samma skäl som i ADR-016 — historik ska kunna återskapas och ett misstag ska kunna ångras.
