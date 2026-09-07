# ADR-014: källhostade bilder för träningsövningar

- Status: Accepterad
- Datum: 2026-08-26

## Kontext

Tränarna behöver övningsbilder i planeringen. Bilderna kommer från Svensk Innebandys Övningsbank. Att kopiera filerna till vårt repo skulle skapa dubbla original och större ansvar för rättigheter och aktualitet.

## Beslut

Appen lagrar originalsidans officiella titel, URL och en HTTPS-adress till den statiska bilden på `innebandy.se`. När en övning har en Övningsbanken-källa är den officiella titeln också den synliga övningsrubriken. I träningsvyn prioriteras verifierad originalvideo, därefter originalbild; om båda saknas visas ingen medieyta. Bild och film visas med attribution och en tydlig länk till originalövningen. Endast värddomänen `innebandy.se/media/**` tillåts för bilder och verifierade Vimeo-URL:er tillåts för video.

Om en övning saknar statisk originalbild visas text och källänk utan tom bildyta. Nyskrivna instruktioner lagras lokalt; källans längre beskrivning kopieras inte.

## Konsekvenser

- Originalbilden behöver inte lagras eller versionshanteras av laget.
- En ändrad eller borttagen bild hos källan kan sluta visas, medan resten av träningsplanen fortsätter fungera.
- Bildvisningen kan stängas av centralt om källans tekniska eller rättsliga villkor ändras.
- Lokala träningsfokus hör hemma på pass- eller blocknivå, inte som en alternativ rubrik för en källövning.
