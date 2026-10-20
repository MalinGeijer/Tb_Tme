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

Detta steg etablerar endast projektstrukturen. Ingen VHDL-kod eller
simuleringskonfiguration har implementerats; simulator och VHDL-version
är ännu inte valda. Befintliga filer behålls på sina ursprungliga platser.
