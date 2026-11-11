# Project scope: Nigerian fuel and food prices

## The question

Nigeria deregulated petrol in 2023. The implicit promise of deregulation is that competition evens prices out across the country. This project tests whether that happened, using the nineteen months of official price data published since.

**Does Nigeria have one fuel market, or thirty-seven?**

A national average is the obvious way to answer and the wrong one. Between December 2024 and February 2025 the national average petrol price moved by 6%, which reads as nothing happening. Over the same two months the spread between the cheapest and dearest state went from 20% to 81%. The average is the calm number. The distribution is where the story is.

## Questions

| # | Question | Queries |
| --- | --- | --- |
| 1 | What happened to fuel prices nationally across the period? | `sql/10_national_trend.sql` |
| 2 | How much does what you pay depend on where you live, and is the gap closing? | `sql/20_dispersion.sql` |
| 3 | What happened in early 2025, and who did it hit? | `sql/30_divergence.sql` |
| 4 | Do fuel costs reach food prices? | `sql/40_passthrough.sql` |

## Who would use this

A distribution or logistics business setting regional delivery pricing. An FMCG company deciding whether to price uniformly across the country. A policy analyst asking whether deregulation delivered what it promised.

## Data

All figures come from the National Bureau of Statistics of Nigeria, published monthly at [microdata.nigerianstat.gov.ng](https://microdata.nigerianstat.gov.ng). NBS collects prices from more than 10,000 outlets across all 774 local government areas.

| Series | Coverage | Granularity |
| --- | --- | --- |
| Petrol (PMS) | Nov 2024 to May 2026 | State |
| Diesel (AGO) | Nov 2024 to May 2026 | State |
| Kerosene, litre and gallon | Nov 2024 to May 2026 | State |
| Cooking gas, 5kg and 12.5kg | Nov 2024 to Apr 2026 | State |
| Selected food items | Jan 2025 to May 2026 | Zone |

4,093 state-level fuel prices and 4,800 zone-level food prices, loaded into PostgreSQL.

## In scope

Retail price levels, trends, rankings and dispersion. Comparison between fuel and food series at zone level. Descriptive and comparative analysis only.

## Out of scope

- **Causation.** The data shows the North West diverged in early 2025. It cannot say why. Any explanation must be sourced and cited, not inferred from the prices.
- **Household impact.** No income or consumption data, so nothing here supports a claim about affordability or living standards.
- **Anything below state level.** NBS collects across all 774 LGAs and publishes state averages only.
- **Food at state level.** Published by zone only, which holds question 4 at a coarser geography than question 2.
- **Food before January 2025.** NBS rebased the basket between December 2024 and January 2025. See the limitation below.

## Limitations

1. **The food basket is not continuous.** NBS renamed or replaced almost every item label between December 2024 and January 2025. Of 43 items in the 2024 basket and 42 in the 2025 one, exactly **one** label survives unchanged. Units changed too: bread moved from 500g to 450g, evaporated milk from 170g to 150g. The food series therefore starts in January 2025, seventeen months.
2. **Cooking gas has gaps.** NBS has not published a May 2026 gas file, and the January 2026 file omits the 12.5kg cylinder.
3. **Nineteen months is short.** Year-on-year comparison is available for seven months of the fuel series and five of the food series. Correlations over a series this short are fragile, and both fuel and food trend upward, so shared trend inflates any correlation between them.
4. **Prices are averages of averages.** A state figure is NBS's mean across its outlets. Dispersion within a state is invisible here.
5. **NBS contradicts itself on geography.** The petrol series files Taraba in the North West, every other series puts it in the North East. See `docs/ETL_NOTES.md`.

## Deliverables

- `scripts/` download the source files, parse them into tidy CSVs
- `data/` the parsed CSVs
- `sql/` schema, transform, and one query file per question
- `docs/` scope, data dictionary, ETL notes, findings
