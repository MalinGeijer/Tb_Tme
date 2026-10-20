# Designbeslut för Turbo Encoder-referensmodell

Datum: 2026-10-20

## Mål och arbetssätt

Projektet ska utvecklas iterativt i små, diskuterade och granskningsbara steg.
Vi implementerar inte hela miljön på en gång.

Ingen DUT finns ännu. Första målet är att validera en oberoende,
beteendebaserad VHDL-referensmodell mot oberoende golden-filer.
Senare ska samma modell kunna användas för DUT-verifiering.
Golden-filer får inte användas för att beräkna modellens resultat.

## Överenskommet

- Projektet ska stödja kodraterna 1/2, 1/4 och 1/6. Kodrat 1/3 ska inte
  implementeras och ska avvisas som ej stödd av projektet.
- Generatorpolynom ska framöver skrivas med potenser av `D`, tillsammans
  med standardens beteckningar. Sambandet mellan polynom, anslutningsvektor
  och registerordning ska fastställas före implementation.
- Gemensamma hjälpfunktioner samlas i filen `tb/packages/utils.pkg`.
  Föreslaget VHDL-paketnamn är `utils`. Hjälpfunktionerna omfattar
  filhantering, formatkonvertering, jämförelse och diagnostik efter behov.
- Konfigurationen ligger separat under `tb/config/`.
- Genererade resultat ska hamna i `output/`. Oberoende golden-filer
  ligger kvar i `testvectors/golden/`.
- Ingen DUT-specifik klockning, handskakning eller latensmodell införs nu.

## Föreslagen ansvarsfördelning

| Plats | Ansvar |
| --- | --- |
| `src/reference/` | Turbo-algoritmen, inklusive interleaver, komponentkodning, terminering och serialisering. |
| `tb/config/` | Kodrat, informationsblockets längd, filvägar och uttryckligt valda filformat. |
| `tb/packages/utils.pkg` | Gemensamma hjälpfunktioner, separat från kodningsalgoritmen. |
| `tb/tb_turbo_reference.vhd` | Överordnad testbänk som anropar modell och hjälpfunktioner. |
| `output/` | Genererade referensresultat; eventuella rapportfiler bestäms senare. |

Det föreslagna första verifieringsflödet är:

1. Läs och validera konfiguration och indata.
2. Beräkna kodordet med referensmodellen.
3. Skriv beräknat kodord till `output/`.
4. Läs och validera motsvarande golden-fil.
5. Jämför längd och bitinnehåll och rapportera PASS/FAIL med diagnostik.

Förslaget är att modellen behandlar ett helt informationsblock per anrop
och arbetar med en bitsekvens i sändningsordning. Bytepackning och filformat
hanteras vid filgränsen. Exakta gränssnitt är ännu inte fastställda.

## Standardunderlag och informationsblock

Avsett primärt underlag är `docs/standards/131x0b5-Turbo.pdf`.
Diskussionen har utgått från CCSDS officiella nätversion av
**CCSDS 131.0-B-5, Issue 5, september 2023**, *TM Synchronization and
Channel Coding*, kapitel 6:
<https://ccsds.org/Pubs/131x0b5.pdf>.

Den lokala PDF-kopian har ännu inte kunnat läsas tillförlitligt med
tillgängliga verktyg och dess överensstämmelse med nätversionen är inte
verifierad. Detta ska klarläggas före implementation av kodningslogiken.

Enligt avsnitt 6.3 f, tabellerna 6-1 och 6-2 samt avsnitt 6.3 j gäller
följande längder för de kodrater projektet ska stödja:

| Informationsbitar `k` | Informationsbyte | Kodordsbitar, 1/2 | Kodordsbitar, 1/4 | Kodordsbitar, 1/6 |
| ---: | ---: | ---: | ---: | ---: |
| 1784 | 223 | 3576 | 7152 | 10728 |
| 3568 | 446 | 7144 | 14288 | 21432 |
| 7136 | 892 | 14280 | 28560 | 42840 |
| 8920 | 1115 | 17848 | 35696 | 53544 |

Kodordslängden är `n = (k + 4) / r`, där `r` är nominell kodrat.
De fyra extra stegen avser terminering och är inte extra informationsbitar
som ska läggas i indatafilen. Blockstorleken styr även interleavern enligt
avsnitt 6.3 g.

Rekommendationen är att konfigurationen anger informationsblockets längd
i bitar och att filinläsningen kontrollerar längden mot detta värde.

## Öppna frågor före implementation

- Innehåller `testvectors/input/input892bytes.hex` exakt ett informationsblock
  på 892 byte, alltså 7136 bitar? Filnamnet antyder det, men innehållet har
  inte granskats.
- Ska första iterationen stödja enbart 7136 informationsbitar eller alla
  fyra blockstorlekar? Detta är ännu inte uttryckligen fastställt.
- Vilken bitordning, bytepackning och eventuell utfyllnad använder filerna?
- Innehåller golden-filerna endast Turbo-kodord eller även exempelvis ASM
  eller randomisering? Vektorernas ursprung och transformationer behöver
  dokumenteras.
- Vilket format och vilka namn ska resultatfilerna i `output/` ha?
- Vilken simulator och VHDL-version ska användas?

ASM och randomisering föreslås hållas separata från själva Turbo-kärnan.
Det innebär inte att standardens krav för den fullständiga kedjan utelämnas;
jämförelsegränsen måste fastställas mot standarden och vektorformatet.

## Status

Detta dokument registrerar diskussionen. Det implementerar inga paket,
testbänkar, konfigurationer eller nya kataloger. Ingen VHDL-kod har skrivits
och ingen simulering eller funktionell verifiering har utförts i detta steg.
