# Implementation 01: säker grund och spelarlista

- Status: Genomförd och verifierad
- Godkänd: 2026-08-13
- Verifierad: 2026-08-14

## Syfte

Verifiera hela den tekniska kedjan med minsta meningsfulla produktflöde:

```text
Tränare loggar in
  → behörighet kontrolleras mot lagmedlemskap
  → tränaren ser lagets aktiva spelare
  → en annan användare kan inte läsa laget
```

När denna implementation är klar vet vi att projektstruktur, deploymentbar applikation, databas, autentisering och Row Level Security fungerar tillsammans innan CRUD och fördelningsmotor byggs.

## Ingår

### Applikationsgrund

- Next.js med TypeScript
- Tailwind CSS
- etablerad katalogstruktur för UI, serverlogik och domänlogik
- miljövariabelmall utan hemligheter
- lint, typecheck och testkommandon
- grundläggande mobil AppShell

### Databas

Reproducerbara Supabase-migrationer för:

- `teams`
- `team_members`
- `seasons`
- `players`

Modellen ska stödja tre separata tränarkonton kopplade till samma lag.

### Behörighet

- Supabase Auth
- inloggningsvy
- utloggning
- skyddad applikationsyta
- Row Level Security baserad på aktivt medlemskap i `team_members`
- positivt test: medlem kan läsa lagets spelare
- negativt test: icke-medlem kan inte läsa lagets spelare

### Spelarlista

- mobil vy för aktiva spelare
- namn och nivå visas
- nivå 1 visas som högst och nivå 3 som lägst
- loading, empty, error och populated states
- desktop får en enkel responsiv variant, inte en separat dashboard

### Testdata

- ett lag
- en aktiv säsong
- minst tre exempelspelare, en på varje nivå
- dokumenterad lokal metod för att koppla de tre tränarkontona till laget utan en medlemsadministrationssida

## Ingår inte

- skapa, ändra eller deaktivera spelare i UI
- matchlista eller matchhantering
- ordinarie matchfördelning
- extra inhopp
- manuell uttagningsjustering
- spelarhistorik
- full designpolish
- deployment till Vercel
- produktionsdata eller riktiga spelarnamn

## Föreslagen kodstruktur

Den exakta strukturen får anpassas till vald stabil Next.js-version, men ansvaren ska hållas separerade:

```text
src/
├── app/                 routes, layouts och servernära UI
├── components/          återanvändbara presentationskomponenter
├── features/players/    spelarlistans use case, query och UI
├── lib/supabase/        Supabase-klienter och sessionshantering
└── domain/allocation/   reserverad plats för ren fördelningslogik

supabase/
├── migrations/
└── seed.sql
```

## Acceptanskriterier

### Projektgrund

- applikationen startar lokalt med dokumenterat kommando
- lint och typecheck passerar
- `.env.example` innehåller endast variabelnamn och säkra exempel
- inga hemligheter finns i Git-status eller källkod

### Autentisering

- oinloggad användare skickas till inloggningsvyn
- giltig tränare kan logga in och ut
- en autentiserad användare utan lagmedlemskap ser inte lagets data

### Spelarlista

- tränaren ser endast aktiva spelare för sitt lag
- namn och nivå visas korrekt
- nivåskalan är entydig: 1 högst, 3 lägst
- listan fungerar på mobil utan horisontell scroll
- loading, empty, error och populated states kan verifieras

### Säkerhet

- direkt databasanrop som lagmedlem ger tillåtna rader
- motsvarande anrop som icke-medlem ger inga rader eller nekas enligt policyn
- användare från ett annat lag kan inte läsa eller ändra lagets spelare
- service role-nyckeln används aldrig i webbläsaren

## Verifieringsplan

### Automatiskt

1. Installera beroenden med låst versionsfil.
2. Kör lint.
3. Kör TypeScript-kontroll.
4. Kör enhetstester för validering och presentation av nivå.
5. Kör databastester för positiva och negativa RLS-fall.
6. Bygg produktionsversionen lokalt.

### Manuell användarresa

1. Öppna appen som oinloggad och verifiera omdirigering.
2. Logga in som en av tränarna.
3. Öppna spelarlistan och verifiera namn samt nivåer.
4. Kontrollera mobile-first layout vid smal viewport.
5. Logga ut och verifiera att skyddad data inte längre visas.
6. Logga in som användare utan medlemskap och verifiera att lagdata inte exponeras.

### Evidens vid överlämning

Agenten ska redovisa:

- vilka kommandon som kördes och om de passerade
- resultat av positiva och negativa RLS-tester
- vilka användarresor som verifierades
- eventuella kvarvarande risker eller steg som kräver användarens Supabase-konfiguration

## Stoppunkter som kräver användaren

- skapande eller val av Supabase-projekt
- tillgång till publika Supabase-miljövariabler
- beslut om exakt inloggningsmetod om Supabase-konfigurationen kräver val
- externa ändringar, commit, push och deployment

Lokalt scaffolding, migrationer, tester och implementation inom ovanstående scope kräver inget separat godkännande efter att implementationen uttryckligen startats.

## Definition av klar

Implementation 01 är klar när samtliga relevanta acceptanskriterier ovan och projektets `docs/quality/definition-of-done.md` är uppfyllda och verifieringsevidensen har redovisats.
