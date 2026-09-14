# Implementation 15: tränarnärvaro

- Status: Genomförs
- Beslut: ADR-018

## Mål

Alla aktiva, inloggade lagmedlemmar ska kunna ange om de kommer eller är frånvarande vid en kommande träning. Alla ska kunna se en samlad överblick per träning och träningsdetaljen ska visa antal och namn på dem som kommer.

## Acceptanskriterier

- `training_attendance` har högst ett svar per träning och medlem, samt kanoniska statusvärden för kommer och frånvarande.
- En aktiv coach och en aktiv viewer kan spara endast sitt eget svar. Outsider, anonym användare och direkt klientmutation nekas.
- Närvarovyn visar personens egna svar och en översikt med antalet och namnen på dem som kommer.
- Varje träningsdetalj visar samma antal och namn.
- Genomförda träningar kan inte få nya eller ändrade planerade närvarosvar.
- Mobilvyn fungerar utan horisontell scroll och har loading, error, empty och populated state.

## Avgränsning

Detta är planerad tränarnärvaro, inte spelarnärvaro, kallelser, påminnelser eller registrering av faktisk närvaro efter passet.
