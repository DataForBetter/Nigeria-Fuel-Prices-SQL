# Does Nigeria have one fuel market, or thirty-seven?

Nigeria deregulated petrol in 2023, on the premise that competition would even prices out across the country. This project tests that against nineteen months of official price data, using PostgreSQL.

Part of my portfolio at **https://dataforbetter.github.io/**.

## The short version

The national average says the market is calm. Between December 2024 and February 2025 it moved 6%. Over the same two months the gap between the cheapest and dearest state went from 20% to **81%**, and one state was paying ₦1,730 a litre while another paid ₦957.

Three things came out of the data.

**Diesel, not petrol, is the real story.** Diesel rose **126%** across the period, from ₦1,447 to ₦3,277 a litre. Kerosene by the gallon rose 71%. Petrol, which gets the headlines, rose 31%.

**The market is more integrated now than when the series starts.** The coefficient of variation for petrol across states runs around 5% in late 2024, spikes to 17.9% in February 2025, then settles at **2.3 to 4%** from October 2025 on.

**The early 2025 shock was petrol only, and it hit states that are not otherwise expensive.** Kaduna sat 1.1% below the national median before the window, 32.3% above during it, and 2.2% below after. Jigawa, Sokoto, Kano, Imo and Enugu show the same shape. In the North West during those months petrol ran 18.1% above its own normal while diesel and kerosene moved 0.3% and cooking gas fell. Diesel and kerosene travel the same roads through the same depots, so this was not a transport or general energy shock. Something specific to petrol distribution broke.

## The data

Everything comes from the National Bureau of Statistics of Nigeria, published monthly at [microdata.nigerianstat.gov.ng](https://microdata.nigerianstat.gov.ng), collected from over 10,000 outlets across all 774 local government areas.

4,093 state-level fuel prices across six products and nineteen months, and 4,800 zone-level food prices across 41 items and seventeen months.

## Running it

```bash
pip install -r requirements.txt
python scripts/download.py      # fetches ~102 source files from NBS
python scripts/parse_fuel.py    # -> data/fuel_prices.csv
python scripts/parse_food.py    # -> data/food_prices.csv
```

The parsed CSVs are committed, so you can skip straight to the database.

```
psql -f sql/01_schema.sql
\copy stg_fuel_prices from 'data/fuel_prices.csv' csv header
\copy stg_food_prices from 'data/food_prices.csv' csv header
psql -f sql/02_transform.sql
psql -f sql/10_national_trend.sql -f sql/20_dispersion.sql \
     -f sql/30_divergence.sql -f sql/40_passthrough.sql
```

Built and tested on PostgreSQL 16, running on Supabase.

## Repository

| Path | Contents |
| --- | --- |
| `scripts/download.py` | Pulls every published file from the NBS catalog |
| `scripts/parse_fuel.py` | Turns the fuel workbooks into one tidy table |
| `scripts/parse_food.py` | Turns the food workbooks into one tidy table |
| `sql/01_schema.sql` | Staging tables and a star schema |
| `sql/02_transform.sql` | Builds the dimensions and facts from staging |
| `sql/10` to `sql/40` | One file per question, each creating views |
| `docs/SCOPE.md` | Questions, data, what is out of scope, limitations |
| `docs/ETL_NOTES.md` | What the source files do and how it was handled |
| `docs/DATA_DICTIONARY.md` | Every table, column and view |

## A note on the source data

NBS publishes these as formatted reports rather than as data, and most of the work in this project was getting them into a state where a query could run. Header rows move between the first and third row. Two products share one sheet in the kerosene and gas series. Consecutive files overlap by two months. The petrol series omits the zone headers every other series carries, and files Taraba in the wrong zone for all nineteen months. The food basket was rebased between December 2024 and January 2025, with exactly one item label surviving unchanged.

None of that is hidden in the analysis. `docs/ETL_NOTES.md` sets out each case and how it was resolved.
