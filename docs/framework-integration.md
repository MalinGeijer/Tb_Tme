# Använd algoritmen i ett annat VHDL-framework

Referensmodellen behöver endast dessa filer, i kompileringsordning:

1. `src/reference/turbo_types_pkg.vhd`
2. `src/reference/turbo_constants_pkg.vhd`
3. `src/reference/turbo_encoder_pkg.vhd`
4. `src/reference/turbo_interleaver_pkg.vhd`
5. `src/reference/turbo_serializer_pkg.vhd`
6. `src/reference/turbo_block_pkg.vhd`

Kompilera dem som VHDL-2008 i samma bibliotek. Interna referenser använder
`work`, vilket avser det bibliotek där respektive paket kompileras.
Inga filer från `tb/`, körskript, golden-filer eller loggfiler behövs.

## Anrop

Exempel inne i en process för ett informationsblock på 892 byte:

```vhdl
-- Import these packages in the calling design unit's context.
-- use work.turbo_types_pkg.all;
-- use work.turbo_block_pkg.all;

variable input_bytes : ByteVec_T(0 to 891);
variable expected_bytes : ByteVec_T(
    0 to encoded_byte_count(892, RATE_1_2) - 1);

-- In the process body, after collecting and validating the input bytes:
-- expected_bytes := encode_block(input_bytes, RATE_1_2);
```

`encode_block` tar ett helt informationsblock och returnerar ett komplett
kodord som bytearray med index från 0. Indatalängden härleds från arrayen;
tillåtna längder är 223, 446, 892 och 1115 byte. Välj `RATE_1_2`,
`RATE_1_4` eller `RATE_1_6`. Funktionen har inget bestående tillstånd mellan
anrop och förbrukar ingen simuleringstid.

Kodordet inkluderar termineringen men ingen ASM eller randomisering.
Byte behandlas i arrayordning, bit 7 först. Frameworket ansvarar för
insamling, blockgränser, konfigurationsval och jämförelse mot DUT:n.

För seriell jämförelse används samma förväntade bytearray:

```vhdl
-- bit_position is zero-based and advances only for a valid DUT output bit.
-- Check bit_position < expected_bytes'length * 8 before indexing.
expected_bit := expected_bytes(bit_position / 8)(7 - bit_position mod 8);
```

## Anslut frameworkets ByteVec_T

Den lokala `ByteVec_T` är temporär. Ett identiskt namn och elementformat
i två olika paket gör inte typerna identiska. Vid integration kan du:

- ersätta den lokala typdeklarationen med en subtype av frameworkets
  befintliga `ByteVec_T`, med rätt paket-/biblioteksreferens, eller
- behålla modellen oförändrad och göra en explicit arraykonvertering vid
  anrop och retur om typerna har kompatibla index- och elementtyper.

Frameworkets exakta typdeklaration behövs för att välja den slutliga
anslutningen. Inget DUT-gränssnitt antas här.

## Diagnostik och verifieringsstatus

Algoritmen skriver inga filer och loggar ingenting vid ett normalt anrop.
Assertions för ogiltiga värden, blocklängd och interna konsistensfel finns
kvar. Frameworket måste behandla dessa som fel.

Polynomkonstanterna har flyttats oförändrade från testbänkskonfigurationen
till `turbo_constants_pkg`. Inga kodningsekvationer har ändrats i denna
uppdelning. Tidigare GOLDEN-verifiering omfattar 892 byte för alla tre
kodraterna; övriga längder saknar ännu golden-vektorer.
