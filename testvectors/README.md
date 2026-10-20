# Testvektorer

## Filformat för separata `.hex`-filer

- ASCII-text med versala hexsiffror och exakt två hexsiffror per byte.
- Byte separeras med ett mellanslag; varje rad innehåller 16 byte utom
  sista raden, som kan vara kortare.
- LF-radslut och avslutande radslut. Inga rubriker, adresser eller kommentarer.
- Byteordningen är filordningen. Radbrytningar är enbart formatering och
  markerar inte blockgränser. Läsaren måste acceptera en kort sista rad.
- Bitordningen inom byte måste fastställas separat före kodning/jämförelse.

## Kontrollerade längder

Nuvarande vektorer avser ett informationsblock på 892 byte (7136 bitar).

| Fil | Databyte | Databitar |
| --- | ---: | ---: |
| `input/input892bytes.hex` | 892 | 7136 |
| `golden/outRate2.hex` | 1785 | 14280 |
| `golden/outRate4.hex` | 3570 | 28560 |
| `golden/outRate6.hex` | 5355 | 42840 |

Golden-längderna motsvarar `n = (k + 4) / r` för `k = 7136` enligt
CCSDS 131.0-B-5, Issue 5, september 2023, avsnitt 6.3 f och j samt
tabell 6-2. Längdkontrollen bevisar inte att kodningen är korrekt.

På sikt ska vektorer för standardens övriga informationsblockstorlekar
1784, 3568 och 8920 bitar tillkomma. De finns inte i denna uppsättning.
Projektet implementerar inte kodrat 1/3.

## Källunderlag och utförda kontroller

`turboGoldenIdleAllRates.txt` bevaras oförändrad som befintligt källunderlag.
Dess ursprung och oberoende behöver fortfarande dokumenteras.

Indata överensstämmer exakt med samlingsfilens andra rad. De separata
golden-filerna överensstämmer byte för byte med slutet av motsvarande
kodratsavsnitt. Följande prefix finns före dessa data i samlingsfilen:

| Kodrat | Prefix (hex) |
| --- | --- |
| 1/2 | `034776C7272895B0` |
| 1/4 | `034776C7272895B0FCB88938D8D76A4F` |
| 1/6 | `25D5C0CE8990F6C9461BF79CDA2A3F31766F0936B9E40863` |

Prefixens funktion är inte verifierad i denna kontroll. De har inte lagts
till i de separata golden-filerna. Samlingsfilen innehåller även ett avsnitt
för kodrat 1/3, vilket lämnas orört.

Formateringen ändrar endast blanktecken i de fyra separata `.hex`-filerna.
Avkodade byte jämfördes före och efter ändringen och är identiska.
Ingen simulering eller funktionell verifiering av Turbo-algoritmen har körts.
