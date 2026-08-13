# ADR-003: Uttagning, extra inhopp och deltagande

- Status: Accepterad
- Datum: 2026-08-13

## Kontext

Appen måste skilja mellan ordinarie fördelning, manuella justeringar, extra inhopp och faktisk närvaro. Ordinarie matcher och extra inhopp ska vara två separata rättvisesystem.

## Beslut

En matchkoppling lagrar minst:

- uttagningstyp: `regular` eller `extra`
- källa: `automatic` eller `manual`
- uttagningsstatus: `selected` eller `removed`
- faktisk medverkan: `played`
- valfri koppling till ersatt spelare

Manuella ändringar bevaras vid omfördelning men presenteras för tränaren som `Manuellt tillagd`, `Manuellt borttagen` eller `Extra inhoppare`, inte som tekniska lås.

Endast genomförda extra inhopp räknas i extrarotationen. Förfrågningar och avböjanden lagras inte. Spelarnivå påverkar inte extrarotationen.

## Konsekvenser

- Ordinarie rättvisa kan beräknas utan att extra inhopp påverkar den.
- Historiken kan skilja tilldelning från faktisk medverkan.
- Omfördelning måste respektera manuella rader och endast ersätta automatiska framtida uttagningar.
- Att markera en match som genomförd blir en explicit operation där deltagandet granskas och sparas.

## Alternativ

- Ett enda fält `selected`: avvisas eftersom det inte kan beskriva rättvisa, källa och faktisk medverkan separat.
- Räkna extra inhopp som ordinarie matcher: avvisas eftersom användarna vill ha två oberoende fördelningar.

