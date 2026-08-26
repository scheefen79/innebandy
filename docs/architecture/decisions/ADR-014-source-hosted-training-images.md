# ADR-014: källhostade bilder för träningsövningar

- Status: Accepterad
- Datum: 2026-08-26

## Kontext

Tränarna behöver övningsbilder i planeringen. Bilderna kommer från Svensk Innebandys Övningsbank. Att kopiera filerna till vårt repo skulle skapa dubbla original och större ansvar för rättigheter och aktualitet.

## Beslut

Appen lagrar originalsidans officiella titel, URL och en HTTPS-adress till den statiska bilden på `innebandy.se`. Bilden visas med attribution och en tydlig länk till originalövningen. Den officiella titeln gör skillnaden mellan vår planerade variant och källövningen synlig. Endast värddomänen `innebandy.se/media/**` tillåts av bildkomponenten och berikningsfunktionen.

Om en övning saknar statisk originalbild visas text och källänk utan tom bildyta. Nyskrivna instruktioner lagras lokalt; källans längre beskrivning kopieras inte.

## Konsekvenser

- Originalbilden behöver inte lagras eller versionshanteras av laget.
- En ändrad eller borttagen bild hos källan kan sluta visas, medan resten av träningsplanen fortsätter fungera.
- Bildvisningen kan stängas av centralt om källans tekniska eller rättsliga villkor ändras.
