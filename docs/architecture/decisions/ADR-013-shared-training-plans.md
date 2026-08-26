# ADR-013: delade träningsplaner som självständiga tillfällen

- Status: Föreslagen
- Datum: 2026-08-26

## Kontext

Tre tränare behöver gemensamt planera 27 träningar under hösten 2026. Grundinnehållet återanvänds per veckodag och temablock, men tränarna behöver kunna anpassa ett enskilt pass utan att oväntat ändra andra pass. Flera tränare kan öppna och redigera samma plan samtidigt.

## Beslut

- Varje träning lagras som ett självständigt `training_sessions`-objekt med egna `training_items`.
- Fem block och tio dagsmallar används endast vid idempotent initialisering. Träningarna behåller ingen levande mallkoppling efter skapandet.
- Alla aktiva tränare i laget har samma läs- och redigeringsbehörighet genom befintligt `team_members`-medlemskap.
- Hela träningens plan sparas atomiskt genom en server-only funktion med monoton `revision` och jämförelse mot klientens förväntade revision.
- Tidsangivelser för momenten är frivilliga riktmärken. Start- och sluttid för själva träningen är däremot kanoniska `timestamptz` skapade från `Europe/Stockholm`.
- Status följer `draft → planned → completed`. Genomförda träningar är skrivskyddade i MVP.
- Övningar kan bära original-URL och valfri verifierad originalbild. Textinnehållet ska fungera även utan extern bild.

## Konsekvenser

- Tränarna kan anpassa en specifik träning utan sidoeffekter på resten av blocket.
- Duplicerat övningsinnehåll accepteras för att göra beteendet enkelt och förutsägbart.
- En senare global malländring måste vara en uttrycklig funktion med egen konfliktmodell.
- Revisionskontroll förhindrar tyst last-write-wins när två tränare arbetar samtidigt.
- Datamodellen kan senare återanvändas för andra säsonger, men första bootstrapen är avgränsad till Hösten 2026.

## Alternativ

- Levande mallreferenser: avvisas eftersom en malländring skulle kunna förändra redan granskade träningspass.
- Endast ett stort textfält per träning: avvisas eftersom ordning, tider, källor och mobil presentation blir svåra att validera och återanvända.
- Automatisk synk mot Övningsbanken: avvisas i MVP eftersom extern struktur, tillgänglighet och bildrättigheter inte ska bli en driftskritisk del av appen.
- Last-write-wins: avvisas eftersom tre tränare kan skriva över varandras arbete utan att märka det.
- Separata redigeringsroller: avvisas tills ett konkret behov finns; befintlig `coach`-roll är tillräcklig.
