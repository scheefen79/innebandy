# ADR-018: planerad tränarnärvaro per inloggad lagmedlem

- Status: Accepterad
- Datum: 2026-09-14

## Kontext

Tränargruppen behöver se hur många och vilka tränare som planerar att vara på plats vid varje träning. Tidigare hölls sådan information utanför tjänsten. Laget har både rollen `coach` och rollen `viewer`, men produktbeslutet är att varje aktiv, inloggad lagmedlem ska kunna ange sin egen närvaro och se översikten.

## Beslut

- En planerad närvaropost hör till exakt en träning och en inloggad lagmedlem, med status `coming` eller `absent`. Avsaknad av post betyder att medlemmen inte har svarat.
- Alla aktiva lagmedlemmar kan läsa översikten, se namnen på dem som uppgett att de kommer och spara endast sin egen post.
- Ett frivilligt visningsnamn lagras på lagmedlemskapet. Det används i närvaroöversikten och faller tillbaka till e-postprefix för äldre medlemskap utan visningsnamn.
- Närvaron lagras separat från träningsplanen. Den ändrar inte planens revision, status eller övningsinnehåll.
- En genomförd träning är skrivskyddad för nya närvarosvar. Svar sparas via en server-only funktion som verifierar medlemskap och alltid härleder användaren från den verifierade sessionen.

## Konsekvenser

- Besökare får ett begränsat skrivflöde för sin egen planerade närvaro, men får ingen annan administrativ träningsbehörighet.
- Träningsdetaljen och den nya närvarovyn visar samma aktuella antal och namn från en gemensam läsmodell.
- Namn kan hållas team-specifika utan att personuppgifter behöver läggas i migreringar eller källkod.
- Senare behov av anmärkningar, kallelser eller faktisk närvaro efter passet kräver ett separat produktbeslut.
