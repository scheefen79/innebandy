# ADR-017: kuraterad katalog för att byta träningsövning

- Status: Accepterad
- Datum: 2026-09-05

## Kontext

En tränare behöver kunna ersätta en övning i ett enskilt träningspass utan att lämna det aktuella temablocket eller av misstag förändra andra pass. Övningsbanken har publika övningar med varierande täckning av bild, video och kort beskrivning.

## Beslut

- En versionshanterad katalog i `content/ovningsbanken-exercise-catalog.json` är den enda datakällan för ersättningsförslag.
- Katalogen samlas in med ett manuellt startat, lågintensivt script. Det finns ingen produktionstrafik eller automatisk synk mot Övningsbanken.
- Katalogen lagrar endast metadata, media-URL:er och original-URL. Fullständig extern instruktionstext kopieras inte; tränaren måste öppna och uttryckligen bekräfta att originalövningen har granskats före byte.
- Förslag begränsas till Blå 9–12 år och den aktuella momenttypen. Övningar som har ett överlappande träningsområde med aktuellt temablock märks som rekommenderade, men blocket spärrar inte andra verifierade val.
- Själva bytet uppdaterar bara den lokala kopian av momentet och sparas genom den befintliga atomiska plan-sparningen med revisionskontroll.
- En befintlig, fri manuell ändring av källänk är ett separat redigeringsflöde. Servern kräver en uttrycklig manuell markering när en befintlig övnings källa ändras utan ett katalogbyte.
- Bild laddas bara från `innebandy.se` eller `www.innebandy.se`; video kommer enbart från katalogens verifierade Vimeo-URL:er. Vid mediabrist eller laddningsfel finns en tydlig fallback till originalövningen.

## Konsekvenser

- Förslagen är förutsägbara, granskningsbara och fungerar utan att produktionen hämtar externa katalogdata.
- Katalogen kan bli inaktuell och uppdateras då uttryckligen genom scriptet, följt av katalogtesterna och vanlig kodgranskning.
- Övningar utan verifierad video eller sammanfattning är fortfarande användbara genom original-länken, men systemet gör aldrig anspråk på att media finns.

## Alternativ

- Live-sökning i Övningsbanken: avvisas. Den skulle bryta MVP-avgränsningen, göra ersättningsflödet beroende av extern tillgänglighet och ge otestbara resultat.
- Fria externa URL:er från klienten: avvisas för katalogförslag. De kan inte garanteras matcha rätt område eller kontrolleras som media.
- Kopiera hela originalbeskrivningar och media till repot: avvisas. Originalet behåller sin källa och upphovsrättsliga kontext.
