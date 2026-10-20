# Räkneexempel: en komponentkodare, en bit i taget

Vi följer en enda komponentkodare med informationsbitarna **1, 0, 0, 0**.
Målet är att förstå feedback, paritet och minne innan vi skriver funktionen.
Läs gärna till och med steg 2 först och följ bitarna med papper och penna.

Fyra informationsbitar är ett pedagogiskt deltest, inte en tillåten
blockstorlek för ett komplett CCSDS-Turbo-kodord. Vi använder ingen
interleaver, bytepackning eller punktering i detta exempel.

## 1. Fyra minnesplatser

Vi skriver minnet från nyast till äldst:

```text
Ny intern bit → [d_state(1)] → [d_state(2)] → [d_state(3)] → [d_state(4)]
                 nyast                                      äldst
```

När vi skriver `1000` betyder det alltså att `d_state(1) = 1`
och att de andra tre minnesbitarna är 0. Det är ingen byte eller ett
heltal som ska tolkas; det är bara fyra minnesvärden i den ordningen.

Minnet börjar på **0000**. Alla beräkningar i ett steg använder det gamla
minnet. Först när utgångarna är beräknade uppdaterar vi minnet.

## 2. XOR är vår enda räkneoperation

XOR skrivs här `⊕`:

| A | B | A ⊕ B |
| ---: | ---: | ---: |
| 0 | 0 | 0 |
| 0 | 1 | 1 |
| 1 | 0 | 1 |
| 1 | 1 | 0 |

För flera bitar blir resultatet 1 om antalet ettor är udda.
Exempel: `1 ⊕ 0 ⊕ 1 = 0`.

## 3. Från polynom till beräkning

Underlaget är **CCSDS 131.0-B-5, Issue 5, september 2023**:
avsnitt 6.3 h och figur 6-2, sidorna 6-5–6-6, för anslutningarna;
avsnitt 6.3 j, sidorna 6-6–6-7, för start och terminering.
Se [CCSDS officiella PDF](https://ccsds.org/Pubs/131x0b5.pdf).
Figur 6-2 har nu även granskats visuellt i projektets lokala PDF-utdrag.
Feedbackledningen ansluter till tredje och fjärde registret. Detta
bekräftar ekvationen `f = d3 ⊕ d4` och vår koefficientordning för G0.

Här skriver vi polynomen med `D`, där `D` motsvarar en bitfördröjning.
Standardens figur betecknar fördröjningselementen med `D`.
Registerbenämningen är fortsatt `d_state`.

Koefficienterna i våra polynomkonstanter motsvarar ordningen D⁰ till D⁴:

| Namn | Polynom | Användning |
| --- | --- | --- |
| G0 | 1 + D³ + D⁴ | Feedback |
| G1 | 1 + D + D³ + D⁴ | Paritetsbit p1 |
| G2 | 1 + D² + D⁴ | Paritetsbit p2 |
| G3 | 1 + D + D² + D³ + D⁴ | Paritetsbit p3 |

Låt `u` vara biten på komponentkodarens ingång och `v` den interna
biten efter feedback-XOR, före första registret.
`d1`–`d4` är kortnamn för det gamla `d_state(1)`–`d_state(4)`.

**Först feedbacken:**

```text
f = d3 ⊕ d4
v = u ⊕ f
```

G0:s konstantterm 1 motsvarar den aktuella interna biten v.
De fördröjda termerna D³ och D⁴ väljer minnesbitarna till feedbacken f.

**Sedan paritetsbitarna:**

```text
p1 = v ⊕ d1 ⊕ d3 ⊕ d4
p2 = v ⊕ d2 ⊕ d4
p3 = v ⊕ d1 ⊕ d2 ⊕ d3 ⊕ d4
```

Här motsvarar polynomets konstantterm den interna biten **v**, inte u.
Det är viktigt eftersom feedbacken kan göra dem olika.

**Sist flyttas minnet:**

```text
nytt minne = [v, gamla d1, gamla d2, gamla d3]
```

Den gamla d4 lämnar kedjan. Den systematiska utgången är u;
paritetsutgångarna är p1, p2 och p3.

## 4. Första informationsbiten: 1

Vi börjar med minnet `0000`, alltså d1 = d2 = d3 = d4 = 0.

```text
u  = 1
f  = 0 ⊕ 0 = 0
v  = 1 ⊕ 0 = 1

p1 = 1 ⊕ 0 ⊕ 0 ⊕ 0     = 1
p2 = 1 ⊕ 0 ⊕ 0         = 1
p3 = 1 ⊕ 0 ⊕ 0 ⊕ 0 ⊕ 0 = 1

Nytt minne = [1, 0, 0, 0] = 1000
```

Vi har fått paritetsbitarna **1, 1, 1**. Den interna ettan sparas i
första minnesplatsen.

## 5. Andra informationsbiten: 0

Nu är det gamla minnet `1000`.

```text
u  = 0
f  = 0 ⊕ 0 = 0
v  = 0 ⊕ 0 = 0

p1 = 0 ⊕ 1 ⊕ 0 ⊕ 0     = 1
p2 = 0 ⊕ 0 ⊕ 0         = 0
p3 = 0 ⊕ 1 ⊕ 0 ⊕ 0 ⊕ 0 = 1

Nytt minne = [0, 1, 0, 0] = 0100
```

Pariteten blir **1, 0, 1**, trots att den nya informationsbiten är 0.
Kodaren minns alltså tidigare bitar. Ettan har flyttats till andra platsen.

## 6. Tredje och fjärde informationsbiten

Vid **steg 3** är u = 0 och minnet `0100`:

```text
f = 0 ⊕ 0 = 0, v = 0 ⊕ 0 = 0
p1 = 0 ⊕ 0 ⊕ 0 ⊕ 0     = 0
p2 = 0 ⊕ 1 ⊕ 0         = 1
p3 = 0 ⊕ 0 ⊕ 1 ⊕ 0 ⊕ 0 = 1
Nytt minne = 0010
```

Vid **steg 4** är u = 0 och minnet `0010`. Nu påverkar feedbacken:

```text
f = 1 ⊕ 0 = 1, v = 0 ⊕ 1 = 1
p1 = 1 ⊕ 0 ⊕ 1 ⊕ 0     = 0
p2 = 1 ⊕ 0 ⊕ 0         = 1
p3 = 1 ⊕ 0 ⊕ 0 ⊕ 1 ⊕ 0 = 0
Nytt minne = 1001
```

Informationsbiten var **0**, men den nya interna biten blev **1**.
Det är feedbacken som gör komponentkodaren rekursiv.

## 7. Fyra termineringssteg

Informationsbitarna är slut, men minnet är `1001`.
Nu väljer vi **u = f** i varje steg, enligt termineringskopplingen.
Därför blir alltid:

```text
v = u ⊕ f = f ⊕ f = 0
```

Vi matar alltså in nollor i den interna minneskedjan. Det betyder inte
att u eller paritetsutgångarna måste vara noll.

Första termineringssteget, **steg 5**, räknas så här:

```text
Gammalt minne = 1001
f  = 0 ⊕ 1 = 1
u  = f = 1
v  = 1 ⊕ 1 = 0
p1 = 0 ⊕ 1 ⊕ 0 ⊕ 1     = 0
p2 = 0 ⊕ 0 ⊕ 1         = 1
p3 = 0 ⊕ 1 ⊕ 0 ⊕ 0 ⊕ 1 = 0
Nytt minne = 0100
```

De följande tre stegen följer samma regel. Minnet går:

```text
1001 → 0100 → 0010 → 0001 → 0000
       steg 5  steg 6  steg 7  steg 8
```

De fyra ingångsbitarna u under termineringen blir **1, 0, 1, 1**.
För kodare A är dessa också de fyra extra systematiska utgångsbitarna.
Kodare B gör motsvarande beräkning från sitt eget tillstånd.

## 8. Alla steg samlade

Minneskolumnerna visar alltid d1, d2, d3, d4 från vänster till höger.

| Steg | Fas | Gammalt minne | u | f | v | p1 | p2 | p3 | Nytt minne |
| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | Information | 0000 | 1 | 0 | 1 | 1 | 1 | 1 | 1000 |
| 2 | Information | 1000 | 0 | 0 | 0 | 1 | 0 | 1 | 0100 |
| 3 | Information | 0100 | 0 | 0 | 0 | 0 | 1 | 1 | 0010 |
| 4 | Information | 0010 | 0 | 1 | 1 | 0 | 1 | 0 | 1001 |
| 5 | Terminering | 1001 | 1 | 1 | 0 | 0 | 1 | 0 | 0100 |
| 6 | Terminering | 0100 | 0 | 0 | 0 | 0 | 1 | 1 | 0010 |
| 7 | Terminering | 0010 | 1 | 1 | 0 | 1 | 0 | 1 | 0001 |
| 8 | Terminering | 0001 | 1 | 1 | 0 | 1 | 1 | 1 | 0000 |

Tabellen visar alla tre paritetsutgångarna före kodratsberoende urval.
Den är inte ett serialiserat Turbo-kodord.

## Vad har kontrollerats?

Tabellens aritmetik har räknats om med en kort Python-beräkning av
ovanstående XOR-ekvationer. Det kontrollerar räkningen men är inte ett
oberoende bevis på ekvationerna eller en validering mot golden-data.
Ingen VHDL-kod, kompilering eller simulering ingår i detta steg.

Våra namn `d_state`, u, v, f och p1–p3 är pedagogiska/implementationsmässiga
val. Standardens figur visar fördröjningarna som D och paritetsutgångarna
som out1a/out1b, out2a och out3a/out3b där de används.
