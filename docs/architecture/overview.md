# Arkitekturöversikt

## Status

Applikationsstacken är accepterad i ADR-001. Detaljerade beslut för behörighet, uttagningsmodell, autentisering och fördelningsmotor finns i ADR-002, ADR-003, ADR-004 och ADR-005.

## Systemgräns

MVP:n är en responsiv webbapplikation för tränare. Den hanterar lag, säsong, spelare, matcher, uttagningar och spelarhistorik. Publika spelarvyer, kommunikation, betalning och generell föreningsadministration ligger utanför systemgränsen.

## Föreslagen struktur

```text
Webbläsare
    |
    v
Next.js-applikation
    |-- serverrenderade läsvyer
    |-- server actions eller API-routes för mutationer
    |-- ren domänmodul för fördelningslogik
    |
    v
Supabase
    |-- PostgreSQL
    |-- Auth
    `-- Row Level Security
```

## Ansvarsområden

### Presentation

Next.js-komponenter visar vyer och formulär. De ska inte innehålla själva fördelningsalgoritmen.

### Applikationslogik

Use cases hanterar exempelvis skapande av spelare, matcher, omfördelning och manuella byten. De ansvarar för validering och transaktionsgränser.

### Domänlogik

Fördelningsmotorn tar ett explicit inputobjekt och returnerar ett deterministiskt resultat. Den ska kunna testas utan databas, nätverk eller UI.

### Data och behörighet

PostgreSQL lagrar projektets tillstånd. Supabase Auth identifierar tränaren och Row Level Security begränsar åtkomst till lag som användaren tillhör.

## Arkitekturprinciper

- Håll MVP:n i en deploybar applikation.
- Separera domänlogik från ramverk och databas.
- Gör behörighet explicit i datamodellen.
- Använd databastransaktioner när en omfördelning ändrar flera uttagningar.
- Optimera för begriplighet och testbarhet före generell flexibilitet.

## Arkitekturbeslut

- ADR-001: applikationsstack och hosting
- ADR-002: lagmedlemskap och Row Level Security
- ADR-003: representation av manuella uttagningslåsningar
- ADR-004: inloggning och sessionshantering
- ADR-005: ren och deterministisk fördelningsmotor
