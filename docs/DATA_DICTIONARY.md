# Data dictionary

## Staging

Loaded directly from the CSVs in `data/`. Text and dates as published, one row per observation.

### stg_fuel_prices
| Column | Type | Notes |
| --- | --- | --- |
| product | text | Fuel and unit, e.g. `Petrol (PMS), litre` |
| zone | text | One of six geopolitical zones |
| state | text | One of 37 states including FCT Abuja |
| month | date | First of the reference month |
| price | numeric | Average retail price in naira |
| source_file | text | The NBS workbook the row came from |

### stg_food_prices
| Column | Type | Notes |
| --- | --- | --- |
| item | text | Commodity label as published |
| zone | text | One of six geopolitical zones |
| month | date | First of the reference month |
| price | numeric | Average retail price in naira |
| source_file | text | The NBS workbook the row came from |

## Dimensions

| Table | Rows | Contents |
| --- | --- | --- |
| dim_zone | 6 | The six geopolitical zones |
| dim_state | 37 | State name and its zone |
| dim_product | 6 | Product name, split into fuel type and unit |
| dim_item | 84 | Food item and which NBS basket it belongs to |
| dim_month | 19 | Date, year, month number, readable name, quarter |

`dim_item.basket` takes one of three values: `Basket to Dec 2024`, `Basket from Jan 2025`, or `Spans both baskets`, which applies to Chicken Wings alone.

## Facts

| Table | Rows | Grain |
| --- | --- | --- |
| fact_fuel_price | 4,093 | One price per state, product and month |
| fact_food_price | 4,800 | One price per zone, item and month |

Two facts at different grain, because fuel is published by state and food only by zone. Forcing them into one table would mean inventing state-level food prices that NBS does not publish.

## Views

Created by the numbered query files. Each is a saved query, not stored rows.

| View | From | Gives |
| --- | --- | --- |
| v_national_monthly | 10 | Mean, median, min, max and standard deviation by product and month |
| v_national_change | 10 | Month on month and year on year off the national mean |
| v_product_summary | 10 | First and last price per product, and the swing between |
| v_dispersion_monthly | 20 | Spread, standard deviation and coefficient of variation by month, with the cheapest and dearest state |
| v_dispersion_trend | 20 | Each month's dispersion against the three before it |
| v_state_persistence | 20 | Average rank per state, to separate a shock from structural cost |
| v_state_vs_national | 30 | Every state priced against the national median for that month |
| v_shock_states | 30 | Each state before, during and after the Jan to Apr 2025 window |
| v_shock_by_zone_product | 30 | Whether the shock hit one fuel or all of them |
| v_zone_fuel_index | 40 | Fuel rolled up to zone, rebased to Jan 2025 = 100 |
| v_zone_food_index | 40 | Food basket by zone, each item indexed then averaged |
| v_passthrough | 40 | Food and diesel indices side by side, diesel lagged one to three months |

## Relationships

```
dim_zone 1---* dim_state 1---* fact_fuel_price *---1 dim_product
                                      *
                                      |
                                      1
                                 dim_month
                                      1
                                      |
                                      *
dim_zone 1---------------------* fact_food_price *---1 dim_item
```
