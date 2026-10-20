# Turbo Encoder VHDL-verifiering

Projektet ska innehålla en fristående, beteendebaserad VHDL-referensmodell
för en Turbo Encoder och en självkontrollerande verifieringsmiljö.

Ingen DUT finns ännu. Första målet är att validera referensmodellens
beräknade utdata bit för bit mot oberoende golden-filer. Senare ska samma
referensmodell kunna användas för DUT-verifiering. Golden-filerna är en
jämförelsekälla och ingår inte i kodningsalgoritmen.

## Katalogstruktur

| Sökväg | Syfte |
| --- | --- |
| `src/reference/` | Beteendebaserad VHDL-referensmodell. |
| `tb/` | Självkontrollerande VHDL-testbänk. |
| `tb/config/` | Testbänkskonfiguration. |
| `tb/packages/` | Gemensamma testbänksverktyg och filhantering. |
| `testvectors/input/` | Indatatestvektorer. |
| `testvectors/golden/` | Oberoende golden-utdata. |
| `docs/standards/` | Tillämpliga standarddokument. |
| `scripts/` | Simulerings- och verifieringsskript. |

Primärt standardunderlag: `docs/standards/131x0b5-Turbo.pdf`.
Dokumentnummer, revision och relevanta avsnitt ska verifieras innan
kodningsalgoritmen implementeras. Arbetsregler finns i `AGENTS.md`.

## Kör GOLDEN-verifiering

Testbänken använder VHDL-2008 och har körts med GHDL 1.0.0 (mcode).
Kör från projektroten:

```bash
bash scripts/run_golden.sh
```

Det analyserar paketen (`ghdl -a`), elaborerar testbänken (`ghdl -e`) och
kör simuleringen (`ghdl -r --assert-level=error`). Skriptet avbryter vid fel.
Genererade biblioteksfiler läggs under `build/ghdl/`.

Konfigurationen finns i `tb/config/tb_config_pkg.vhd`. Initialt väljs 892
informationsbyte, kodrat 1/2 och motsvarande befintliga testvektorer.
Du kan i stället ange bytelängd, kodratens nämnare och filvägar explicit:

```bash
bash scripts/run_golden.sh 892 4 testvectors/input/input892bytes.hex testvectors/golden/outRate4.hex
bash scripts/run_golden.sh 892 6 testvectors/input/input892bytes.hex testvectors/golden/outRate6.hex
```

Giltiga informationslängder är 223, 446, 892 och 1115 byte. Kodratens
nämnare ska vara 2, 4 eller 6. Välj själv indata och en oberoende golden-fil
som motsvarar både längden och kodraten. Befintliga golden-filer täcker
enbart 892 informationsbyte. Relativa filvägar räknas från projektroten.

Varje körning behandlar ett block och skriver över:

- `output/reference_output.hex`: beräknat kodord, 16 byte per rad, MSB först.
- `output/verification.log`: konfiguration, längder, PASS/FAIL och vid
  mismatch första avvikande block, byte och bit samt antal avvikande byte.

Byt `CFG_OUTPUT_PATH` och `CFG_LOG_PATH` i config för andra resultatnamn.
Resultatfilerna måste vara skilda från indata och golden. Använd inte
alternativa sökvägar eller symboliska länkar till samma fil för dessa roller.
Utmatningskatalogen måste finnas; skriptet skapar `output/`.

Modellen adderar inte ASM eller randomisering. Golden-jämförelsen gäller
själva Turbo-kodordet inklusive fyra termineringssteg. Filformatet beskrivs
i `testvectors/README.md`. Felaktiga filer eller jämförelsefel ger felstatus.

De tre befintliga 892-byte-vektorerna har passerat bitexakt jämförelse.
Övriga blockstorlekar stöds av algoritmen men saknar ännu golden-verifiering.
Ingen DUT eller kontinuerlig strömverifiering är implementerad.
