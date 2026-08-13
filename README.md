# Innebandy

Ett mobile-first planeringsverktyg för tränare i FBC Sollentuna P17. Tjänsten ska ersätta ett spreadsheet för matchfördelning och göra uttagningarna rättvisa, balanserade och lätta att överblicka.

## Status

Projektet befinner sig i planerings- och beslutsfas. Ingen applikation är ännu skapad.

## Dokumentation

- [Designspecifikation och teknisk arkitektur](docs/product/FBC_P17_DESIGN_TECH_SPEC.md)
- [Öppna frågor](docs/product/open-questions.md)
- [Arkitekturöversikt](docs/architecture/overview.md)
- [Aktuell milstolpe](docs/planning/current-milestone.md)
- [Implementation 01: säker grund och spelarlista](docs/planning/implementation-01-foundation.md)
- [Definition of Done](docs/quality/definition-of-done.md)
- [Testfall för matchfördelning](docs/quality/allocation-test-cases.md)
- [Arkitekturbeslut](docs/architecture/decisions/)
- [Agentinstruktioner](AGENTS.md)

## Teknik

Projektet använder Next.js, TypeScript, Tailwind CSS, Supabase/PostgreSQL och Vercel. Beslutet och dess konsekvenser finns i `docs/architecture/decisions/ADR-001-application-stack.md`.

## Arbetsflöde

Större funktioner går från krav och acceptanskriterier till design, implementation, automatiska tester och manuell verifiering. Viktiga beslut dokumenteras så att både människor och agenter kan förstå varför lösningen ser ut som den gör.
