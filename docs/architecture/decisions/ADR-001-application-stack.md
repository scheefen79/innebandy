# ADR-001: Applikationsstack och hosting

- Status: Accepterad
- Datum: 2026-08-13

## Kontext

MVP:n är en liten, mobile-first webbapplikation för tre tränare. Den behöver autentisering, relationsdata, Row Level Security, serverlogik och enkel hosting. Projektet ska vara begripligt och kunna utvecklas iterativt utan en separat backendtjänst.

## Beslut

Använd:

- Next.js för webbgränssnitt och serverlogik
- TypeScript
- Tailwind CSS för styling
- Supabase Auth och PostgreSQL
- Supabase Row Level Security
- Vercel för hosting av webbapplikationen

Fördelningslogiken implementeras som en ren TypeScript-modul utan beroende till Next.js eller Supabase.

## Konsekvenser

- En kodbas räcker för frontend och serverfunktioner.
- Fördelningsmotorn kan testas utan nätverk eller databas.
- Behörighet måste implementeras både i applikationslogik och RLS.
- Projektet blir beroende av Supabase och Vercel, men beroendet bedöms rimligt för MVP.

## Alternativ

- Separat frontend och backend: avvisas eftersom det ökar drift och komplexitet utan tydligt MVP-värde.
- Tung klientbaserad state management: avvisas tills ett konkret behov finns.

