# Findings

Nineteen months of Nigerian fuel and food prices, November 2024 to May 2026, from
National Bureau of Statistics price watch releases. 4,093 state level fuel
observations across six products and 37 states, and 4,800 zone level food
observations across six zones, 42 to 43 items in any given month and 84 distinct
item labels in total, because the basket was rebased in January 2025.

All figures below come from the queries in `sql/`, run against the schema built by
`sql/01_schema.sql` and `sql/02_transform.sql`. Nothing here is estimated.

---

## 0. The pipeline agrees with NBS

Before any finding, the obvious question is whether 102 spreadsheets parsed by a
script actually reproduce what NBS published. Two independent checks, on two
different months:

| Month | NBS published national average | This pipeline |
|---|---|---|
| November 2025, petrol | ₦1,061.35 | ₦1,061.35 |
| March 2026, petrol | ₦1,288.54 | ₦1,288.54 |

Both match to the kobo.

One by-product of that check is worth recording. Press coverage of the November
2025 release reported that several northern states exceeded ₦1,200 per litre. In
the release itself the highest state is Borno at ₦1,133.86, and no state is above
₦1,200. The national average in the same article is correct, so the error is in the
state level reporting rather than in the source.

---

## 1. The dataset contains two fuel price shocks, and they are opposites

Decomposing every product into its **level** (the national mean) and its
**dispersion** (the coefficient of variation across the 37 states) separates two
episodes that look similar in a headline and are nothing alike underneath.

| Product | Level Nov–Dec 24 | Level Jan–Apr 25 | CV Nov–Dec 24 | CV Jan–Apr 25 |
|---|---|---|---|---|
| **Petrol, litre** | ₦1,202 | ₦1,251 | **5.0%** | **15.0%** |
| Diesel, litre | ₦1,447 | ₦1,581 | 13.0% | 15.6% |
| Kerosene, litre | ₦2,050 | ₦2,115 | 14.2% | 12.8% |
| Kerosene, gallon | ₦6,983 | ₦7,919 | 13.9% | 9.0% |
| Cooking gas, 12.5kg | ₦17,315 | ₦18,464 | 5.3% | 5.9% |
| Cooking gas, 5kg | ₦7,133 | ₦7,330 | 4.9% | 5.8% |

| Product | Level Jan–Feb 26 | Level Mar–May 26 | CV Jan–Feb 26 | CV Mar–May 26 |
|---|---|---|---|---|
| Petrol, litre | ₦1,043 | **₦1,473** | 4.8% | 4.1% |
| Diesel, litre | ₦1,391 | **₦2,467** | 7.0% | 7.4% |
| Kerosene, litre | ₦2,308 | ₦2,793 | 10.2% | 16.6% |
| Kerosene, gallon | ₦10,387 | ₦12,094 | 10.2% | 17.7% |
| Cooking gas, 12.5kg | ₦16,998 | ₦21,018 | 5.5% | 8.0% |
| Cooking gas, 5kg | ₦6,102 | ₦8,181 | 5.2% | 7.4% |

**Episode 1, January to April 2025.** One product moved. Petrol's level rose about
4 per cent, which is unremarkable, while its dispersion tripled. No other product
did this. Kerosene's dispersion actually fell.

**Episode 2, March to May 2026.** Every product moved. Levels rose between 16 and
77 per cent. Petrol's dispersion fell slightly and most other products' rose a
little, but nothing approaching Episode 1.

A national average reports the first episode as almost nothing happening and the
second as a large increase. Only one of those readings is right.

---

## 2. Episode 1 was a distribution failure, and it was geographic

Petrol is normally the **tightest priced** product in this dataset, not the
loosest. Diesel and kerosene run far wider in every ordinary month, diesel at 64 to 89 per
cent state spread and kerosene by the litre at 62 to 94 per cent, because they are
fully deregulated and thinly distributed. Petrol usually sits at 20 to 25 per cent.

For four months it did not.

| Month | Median | Cheapest state | Dearest state | Spread |
|---|---|---|---|---|
| Nov 2024 | ₦1,204 | ₦1,093 | ₦1,365 | 25% |
| Dec 2024 | ₦1,176 | ₦1,089 | ₦1,307 | 20% |
| **Jan 2025** | ₦1,225 | ₦950 | ₦1,638 | **73%** |
| **Feb 2025** | ₦1,166 | ₦957 | ₦1,730 | **81%** |
| **Mar 2025** | ₦1,186 | ₦963 | ₦1,700 | **77%** |
| **Apr 2025** | ₦1,226 | ₦970 | ₦1,589 | **64%** |
| May 2025 | ₦1,022 | ₦951 | ₦1,100 | 16% |
| Jun 2025 | ₦1,035 | ₦951 | ₦1,108 | 17% |

The median moved by less than 5 per cent across the whole episode. The gap between
the cheapest and dearest state quadrupled, held for four months, then closed in a
single month.

The dispersion was not random. It mapped onto distance from Lagos.

| Zone | Average, Jan–Apr 2025 | Average, May–Aug 2025 |
|---|---|---|
| North West | ₦1,414 | ₦1,030 |
| South East | ₦1,311 | ₦1,036 |
| North Central | ₦1,277 | ₦1,014 |
| South South | ₦1,228 | ₦1,007 |
| North East | ₦1,194 | ₦1,016 |
| South West | ₦1,062 | ₦1,017 |

During the episode the North West paid 33 per cent more than the South West.
Afterwards every zone sat inside a ₦29 band. The four cheapest states in February
2025 were Oyo, Ekiti, Osun and Lagos, all South West, all near the refinery and the
import terminals. The four dearest were Jigawa at ₦1,730, Sokoto, Kaduna
and Kano, all North West.

For four months, the price of petrol in a state was a function of how far that
state was from where the petrol entered the country. Then it stopped being that.

### This is not a data artefact

A spread that collapses from 64 per cent to 16 per cent in one month invites the
suspicion that NBS changed how it collected or reported the series. It did not.
Every month carries 37 states, and 34 to 37 distinct prices, so state level survey
collection continued unbroken. The coefficient of variation moves smoothly into and
out of the episode (4.9, 5.2, 14.0, 17.9, 16.0, 12.0, 3.7) rather than stepping.
The raw February 2025 workbook independently flags North West at ₦1,484 against
South West at ₦995 in its own summary column.

---

## 3. Episode 2 was an input cost shock

March to May 2026 has the opposite signature. Every product rose, dispersion did
not change much, and diesel rose hardest.

| Product | Feb 2026 | May 2026 | Change |
|---|---|---|---|
| Diesel, litre | ₦1,420 | ₦3,277 | +131% |
| Petrol, litre | ₦1,051 | ₦1,596 | +52% |
| Kerosene, litre | ₦2,300 | ₦2,972 | +29% |
| Kerosene, gallon | ₦10,352 | ₦11,949 | +15% |

A shock that lifts every refined product at once, in proportion to how exposed each
is to import parity, is an upstream shock rather than a distribution one. Diesel
moving furthest is consistent with that, because diesel is the most
import-parity-exposed product in the set.

---

## 3b. Fuel costs did not reach food prices

The obvious way to ask whether fuel prices drive food prices is to correlate the
two national series, and it proves nothing. Both follow the naira and the oil
price, so they rise together whether or not one causes the other.

Episode 1 provides a way around that. For four months the six zones paid very
different amounts for the same petrol, and then the gap closed. That is
variation in fuel cost across regions that is **not** produced by a national
shock, which is what is needed to isolate a fuel effect.

| Zone | Petrol, Jan–Apr 2025 | Above cheapest zone | Food index, Jul 2025 |
|---|---|---|---|
| North West | ₦1,414 | +33.1% | 110.2 |
| South East | ₦1,311 | +23.4% | 117.6 |
| North Central | ₦1,277 | +20.2% | 110.1 |
| South South | ₦1,228 | +15.6% | 107.7 |
| North East | ₦1,194 | +12.4% | 112.3 |
| South West | ₦1,062 | baseline | 116.0 |

Food index is each zone's basket relative to January 2025 = 100.

If fuel costs fed food prices, those last two columns would rise together. They
do not. The zone that paid a third more for petrol than anyone else shows one of
the **smallest** food increases, and the two zones where food rose most, South
East and South West, sit at opposite ends of the fuel range.

Across the months when an effect could plausibly appear, May to September 2025,
the correlation between what a zone paid for fuel and where its food prices sat
runs between **0.17 and −0.30**. With six zones, a correlation has to exceed
about 0.81 before it is distinguishable from chance. Nothing here is close.

**The conclusion is no detectable effect, not a negative one.** This rules out a
large regional pass-through over this period. It cannot rule out a small one, and
it says nothing about the national relationship.

### A correlation worth not reporting

Run the same correlation further out and it reaches **−0.87** by December 2025,
which clears the significance threshold and would look like a real result.

It is not one. By December the fuel gap had been closed for eight months, so
there is no mechanism left to produce an effect. The six food indices by then
span only seven points, from 98.8 to 105.9, and a correlation computed across
six observations over a range that narrow will swing on noise alone. December is
also the post-harvest period, when Nigerian food prices fall for reasons that
have nothing to do with fuel.

The figure is recorded here, and in the comment on `v_passthrough_result`,
precisely so that nobody later reports it as a finding.

### What this question needs instead

Food prices are published by zone and fuel by state, so this test runs on six
observations and can only detect a large effect. State level food prices would
raise that to 37 and make a modest effect detectable. NBS collects across all
774 local government areas, so the data exists. It is simply not published at
that granularity.

---

## 4. The diagnostic

The method this project is really demonstrating is small and reusable.

1. Split a price series into level and dispersion rather than reading the average.
2. Ask whether the move is confined to one product or common to all of them.
3. The answer locates the problem in the supply chain.

| | Level moves | Dispersion moves |
|---|---|---|
| **One product** | that product's own pricing | that product's **distribution** |
| **All products** | a common **input cost** | a common logistics failure |

Episode 1 sits in the top right. Episode 2 sits in the bottom left. Neither is
visible in a national average, which is what most reporting of these releases uses.

---

## 5. What this analysis cannot tell you

Stated plainly, because the limitations are as much a part of the result as the
findings.

**These are correlations in a price series, not causes.** Nothing here establishes
why either episode happened. Section 6 records what public reporting says about the
same period, and that is context, not evidence produced by this analysis.

**The start of Episode 1 is not explained by the documented timeline.** The
dispersion is already at 73 per cent in January 2025. The best documented supply
disruption of that period begins at the end of February. Whatever began the
episode, it was underway before the event most often cited as its cause. This is an
open question, not a settled one.

**NBS surveys what consumers actually paid, not official prices.** This matters.
Press reporting for March 2025 put northern pump prices near ₦960 while this
dataset has Jigawa at ₦1,700. Both can be true, because the quoted figure is a
marketer's official rate and the NBS figure is the average price actually paid
across surveyed outlets, which during scarcity includes outlets selling above the
official rate. The gap between the two is itself a measure of how badly the official
price had stopped describing the market.

**Fuel is published by state and food by region, so fuel was rolled up to match.**
Section 3b averages the states in each region, which puts the two series on the same
footing and is the right move. It costs something specific, and the cost is worth
naming because it works against the conclusion.

Averaging compresses the thing being measured. Jigawa at ₦1,730 disappears into a
North West average of ₦1,414. At state level the gap between cheapest and dearest
was 81 per cent; at regional level it is 33 per cent. So the test is looking for the
effect of a shock less than half the size of the one the country actually
experienced, across six observations rather than thirty-seven. Both of those reduce
its power to detect anything.

The practical consequence: a null result at regional level is weaker evidence of no
effect than a null result at state level would have been. It rules out a large
regional effect. It does not rule out that Jigawa, which the North West average
hides, saw its food prices move. Only state level food data could answer that.

**The series starts in November 2024, and the question starts in mid-2023.** Nigeria
removed the petrol subsidy in May 2023, and that removal is the event this whole
question hangs on. The eighteen months between the removal and the start of this
series are missing, which means the analysis can describe what the deregulated market
did in 2025 and 2026 without showing how it got there.

What nineteen months does support is exactly what is above: two shocks characterised
in close detail, separated by a diagnostic that distinguishes them. What it does not
support is a claim about what an ordinary year looks like, since the claim that petrol
is normally the tightest priced product rests on fifteen ordinary months.

Extending the series back to May 2023 is the single change that would add the most to
this project. It is a sourcing job on the earlier NBS releases rather than a limit of
the method, and the pipeline would ingest them unchanged.

**One known source defect is preserved rather than corrected.** See `ETL_NOTES.md`
for the zone misclassification NBS repeats across one series, which is carried
through to the staging tables and fixed only at the dimension level, by majority
vote, with the original retained.

---

## 6. Context from public reporting

Recorded for orientation. None of it is produced by this analysis and none of it is
tested by it.

On Episode 1, the crude-for-naira arrangement under which Dangote refinery bought
domestic crude in naira lapsed on 1 March 2025, and the refinery suspended naira
denominated product sales, saying its naira sales had exceeded the value of naira
denominated crude it had received
([AllAfrica, 19 March 2025](https://allafrica.com/stories/202503200033.html)).
Pump prices rose in late March, with Lagos moving from ₦860 to ₦930 and northern
cities quoted at ₦950 to ₦970
([Channels TV, 31 March 2025](https://www.channelstv.com/2025/03/31/filling-stations-hike-petrol-price-amid-dangote-nnpcl-crude-dispute/)).
The federal government confirmed in early April that naira denominated crude and
product sales would continue as policy, and the refinery cut its gantry price
([AllAfrica, 10 April 2025](https://allafrica.com/stories/202504110041.html)),
cutting again to ₦835 on 16 April alongside regulatory approval for marketers to
import roughly 157 million litres within eight days
([Punch summary](https://kolaking.substack.com/p/n800litre-petrol-in-sight-as-oil)).
This timeline is consistent with the April to May collapse in dispersion and does
not account for the January onset.

Separately, Nigerian reporting has long attributed persistent northern scarcity to
distance from the private depots and tank farms concentrated in the south
([Daily Trust](https://dailytrust.com/why-fuel-scarcity-persists-in-abuja-northern-states/)),
which is the same structural feature the zone table in Section 2 picks up.

On Episode 2, UNCTAD's *Trade and Development Report 2026* found Nigeria had the
steepest diesel price increase of any country assessed, 82.7 per cent between 23
February and 31 August 2026, and the fourth largest petrol increase
([BusinessAM, 10 October 2026](https://businessamlive.com/global-energy-crisis-pushes-nigeria-to-worlds-highest-diesel-price-increase/)).
IFPRI attributes the Nigerian figure to a combination of global prices, exchange
rate depreciation and import parity, noting that transmission to the pump was
unusually fast because petroleum subsidies had already been unwound
([IFPRI](https://www.ifpri.org/blog/how-african-economies-are-absorbing-the-2026-oil-price-shock-so-far/)).
Brent crossed $100 per barrel in April 2026
([Legit, 2 April 2026](https://www.legit.ng/business-economy/energy/1703962-n1901-litre-petrol-diesel-prices-surge-depots-crude-crosses-100-barrel/)).

---

## Reproducing this

```bash
python scripts/download.py          # fetch and unpack the NBS releases
python scripts/parse_fuel.py        # -> data/fuel_prices.csv
python scripts/parse_food.py        # -> data/food_prices.csv
psql -f sql/01_schema.sql
# \copy the two CSVs into stg_fuel_prices and stg_food_prices
psql -f sql/02_transform.sql
psql -f sql/10_national_trend.sql -f sql/20_dispersion.sql \
     -f sql/30_divergence.sql -f sql/40_passthrough.sql
```
