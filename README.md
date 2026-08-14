# Innebandy

Ett mobile-first planeringsverktyg för tränare i FBC Sollentuna P17. Tjänsten ska ersätta ett spreadsheet för matchfördelning och göra uttagningarna rättvisa, balanserade och lätta att överblicka.

## Status

Projektets Next.js- och Supabase-grund är skapad och verifierad. Autentisering, lagbehörighet och skyddad applikationsyta är implementerade. Nästa steg i Implementation 01 är den läsbara spelarlistan.

## Dokumentation

- [Designspecifikation och teknisk arkitektur](docs/product/FBC_P17_DESIGN_TECH_SPEC.md)
- [Öppna frågor](docs/product/open-questions.md)
- [Arkitekturöversikt](docs/architecture/overview.md)
- [Aktuell milstolpe](docs/planning/current-milestone.md)
- [Implementation 01: säker grund och spelarlista](docs/planning/implementation-01-foundation.md)
- [Definition of Done](docs/quality/definition-of-done.md)
- [Checklista för oberoende granskning](docs/quality/review-checklist.md)
- [Lokal Supabase-utveckling](docs/development/supabase-local.md)
- [Testfall för matchfördelning](docs/quality/allocation-test-cases.md)
- [Arkitekturbeslut](docs/architecture/decisions/)
- [Agentinstruktioner](AGENTS.md)

## Teknik

Projektet använder Next.js, TypeScript, Tailwind CSS, Supabase/PostgreSQL och Vercel. Beslutet och dess konsekvenser finns i `docs/architecture/decisions/ADR-001-application-stack.md`.

## Arbetsflöde

Större funktioner går från krav och acceptanskriterier till design, implementation, automatiska tester och manuell verifiering. Viktiga beslut dokumenteras så att både människor och agenter kan förstå varför lösningen ser ut som den gör.

Innan integration granskas ändringen av en separat skrivskyddad agent enligt [granskningschecklistan](docs/quality/review-checklist.md). Implementerande agent bedömer fynden och ansvarar för rättningar och slutlig verifiering. Commit, push och pull request kräver fortfarande uttryckligt godkännande.

## Lokal utveckling

Krav: Node.js 20.9 eller senare och pnpm.

```bash
pnpm install
pnpm dev
```

Verifiering:

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

Databasmigrationer och RLS-tester körs enligt [guiden för lokal Supabase-utveckling](docs/development/supabase-local.md).

Kopiera `.env.example` till `.env.local` och fyll i Supabase URL samt publishable key. Lägg aldrig riktiga hemligheter i Git.
