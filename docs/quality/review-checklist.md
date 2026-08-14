# Checklista för oberoende agentgranskning

Checklistan används av en separat agent efter implementation men före integration. Granskaren är skrivskyddad: den får undersöka filer och köra icke-destruktiva kontroller, men aldrig ändra projektet eller GitHub.

## Underlag

1. Läs `AGENTS.md` och `docs/quality/definition-of-done.md`.
2. Läs uppgiftens plan, acceptanskriterier och berörda arkitekturbeslut.
3. Fastställ bas och granska både Git-diff och ospårade filer.
4. Kontrollera att ändringen håller sig inom beslutat scope.

## Granskningsområden

### Produkt och domän

- Stämmer beteendet med specifikation och acceptanskriterier?
- Är rättvis fördelning, ordinarie matcher och extra inhopp korrekt separerade där de berörs?
- Är nivåskalan entydig: 1 är högst och 3 är lägst?
- Har öppna produktbeslut felaktigt implementerats som antaganden?

### Kod och arkitektur

- Är domänlogik separerad från UI och externa integrationer?
- Är lösningen liten, begriplig och förenlig med dokumenterade beslut?
- Hanteras fel, tomdata och gränsfall uttryckligt?
- Finns oavsiktlig komplexitet, död kod, debug-utskrifter eller duplicerad logik?

### Test och användarupplevelse

- Täcker testerna ändringens risker och passerar relevanta kommandon?
- Är affärslogik deterministiskt testad, inklusive tie-breakers och omöjliga input när relevant?
- Hanterar centrala vyer loading, empty, error och populated states när relevant?
- Fungerar berörd UI på mobil utan horisontell scroll, med tangentbord och grundläggande tillgänglighet?

### Data, säkerhet och integritet

- Innehåller ändringen hemligheter, riktiga personuppgifter eller känsliga loggar?
- Är autentisering och behörighetskontroll placerad på rätt sida av tillitsgränsen?
- Finns positiva och negativa tester för Row Level Security när dataåtkomst berörs?
- Är migrationer reproducerbara och service role-nyckeln frånvarande i webbläsarkod?

### Dokumentation och drift

- Är relevanta produkt-, arkitektur- och planeringsdokument uppdaterade?
- Kan en annan agent reproducera installation, test och build?
- Redovisas verifiering och kvarvarande risker utan att arbetet översäljs som färdigt?

## Rapportformat

Rapportera fynd först, sorterade efter prioritet:

```text
[P1] Kort rubrik — sökväg:rad
Konsekvens: Vad kan gå fel och för vem.
Evidens: Vad i ändringen som visar problemet.
Rekommendation: Minsta rimliga rättning.
```

Prioriteter:

- **P0:** blockerande; exempelvis dataläckage, dataförlust eller helt obrukbar kärnfunktion.
- **P1:** allvarligt korrekthets-, säkerhets- eller regressionsfel som måste rättas före integration.
- **P2:** verkligt problem som bör rättas eller uttryckligen accepteras med motivering.
- **P3:** avgränsad förbättring som inte blockerar integration.

Avsluta med:

- kontroller som kördes och deras resultat
- kvarvarande osäkerheter eller ej verifierade områden
- uttrycklig slutsats: `redo`, `redo efter rättningar` eller `inte redo`

Om inga konkreta fynd finns, skriv `Inga fynd` i stället för att konstruera förbättringsförslag.
