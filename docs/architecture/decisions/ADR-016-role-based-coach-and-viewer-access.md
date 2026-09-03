# ADR-016: Rollbaserad tränar- och besökaråtkomst

- Status: Accepterad
- Datum: 2026-09-03

## Kontext

Appen har hittills endast rollen `coach`. Alla aktiva lagmedlemmar kan läsa lagets tabeller och flera skrivande serverfunktioner verifierar aktivt medlemskap utan att kräva en viss produktroll. Produkten behöver nu en inloggad besökarroll som kan läsa planering men inte administrera laget.

Besökaren ska kunna läsa översikt, träningar, matcher och spelarnamn i matchuttagningar. Besökaren får inte se spelarnivåer, spelarlistan, spelarprofiler eller spelarhistorik och får inte ändra data. Eftersom spelarens namn är tillåtet i en uttagning men spelarresursen i övrigt är förbjuden räcker det inte att dölja sidor och fält i UI:t.

## Beslut

- `team_members.role` stöder `coach` och `viewer`.
- Båda rollerna kräver ett eget autentiserat konto och ett aktivt medlemskap i laget. Ingen anonym eller publik lagyta införs.
- `coach` behåller full läs- och skrivrätt inom sitt lag.
- `viewer` får använda särskilda läsmodeller för översikt, träningar, matcher och matchuttagningar.
- En matchuttagning får returnera spelarens id och namn till `viewer`, men inte nivå, generell matchstatistik eller historik.
- `viewer` får inte generell `select`-åtkomst till `players` eller `match_players`. Tillåten matchinformation exponeras genom rollmedvetna databasfunktioner med minimala returvärden.
- Spelarlista, spelarprofil och spelarhistorik kräver uttryckligen rollen `coach` i den auktoritativa server- eller databasgränsen.
- Varje skrivande databasfunktion och servermutation kräver uttryckligen ett aktivt medlemskap med rollen `coach`.
- Lagkontexten returnerar den verifierade medlemmens roll så att serverrendering och navigation kan anpassas. UI-begränsningen är ett användbarhetslager och ersätter inte databasens kontroll.

## Konsekvenser

- En besökare kan följa lagets planering utan att kunna ändra den.
- Spelarnivåer och individuell historik lämnar inte serverns tillåtna datagräns för `viewer` och kan därför inte återfinnas genom nätverksinspektion eller direkta klientanrop.
- Befintliga RLS-policyer, grants, läsfunktioner och samtliga skrivfunktioner måste inventeras. Ett generellt medlemskapstest är inte längre tillräckligt för skrivning eller spelarläsning.
- UI:t behöver rollanpassad navigation och skrivskyddade varianter av gemensamma vyer.
- Rollen är medvetet liten och statisk. Ingen generell RBAC-motor eller medlemsadministration införs.

## Alternativ

- Dölja navigation och redigeringsknappar enbart i UI:t: avvisas eftersom direkta API-anrop då kan exponera nivåer eller tillåta skrivning.
- Ge `viewer` generell läsrätt till spelartabellen och filtrera fält i komponenterna: avvisas eftersom nivå och historik fortfarande kan hämtas direkt.
- Publik anonym läsyta: avvisas eftersom appen innehåller uppgifter om barn och laguttagningar.
- Generell behörighetsmotor med konfigurerbara rättigheter: avvisas som onödigt komplex för två fasta roller.
