-- Q4. Do fuel costs reach food prices?
--
-- The honest difficulty is that fuel and food move together anyway, because
-- both follow the naira and the oil price. Finding them correlated nationally
-- would prove nothing.
--
-- Early 2025 solves that. For four months the six zones paid very different
-- amounts for the same petrol, from 1,414 naira in the North West down to
-- 1,062 in the South West, and then the gap closed. That is regional variation
-- in fuel cost that is not caused by a national shock, which is the thing
-- needed to isolate a fuel effect. The test below uses it.
-- Food is published by zone and fuel by state, so fuel is rolled up to zone
-- averages to meet it. Both series are rebased to January 2025 = 100, because
-- a naira average across items of wildly different prices is dominated by the
-- expensive ones and tells you nothing about the basket.

create or replace view v_zone_fuel_index as
with zone_month as (
    select p.product_name, z.zone_name, f.month_date,
           avg(f.price_naira) as zone_price
    from fact_fuel_price f
    join dim_product p on p.product_id = f.product_id
    join dim_state   s on s.state_id   = f.state_id
    join dim_zone    z on z.zone_id    = s.zone_id
    group by p.product_name, z.zone_name, f.month_date
),
base as (
    select product_name, zone_name, zone_price as base_price
    from zone_month where month_date = date '2025-01-01'
)
select zm.product_name, zm.zone_name, zm.month_date,
       round(zm.zone_price::numeric, 2)                              as zone_price,
       round((100.0 * zm.zone_price / b.base_price)::numeric, 1)     as price_index
from zone_month zm
join base b on b.product_name = zm.product_name and b.zone_name = zm.zone_name
where zm.month_date >= date '2025-01-01';

-- Food: index each item within its zone, then average the indices, so every
-- item carries equal weight regardless of its price level.
create or replace view v_zone_food_index as
with base as (
    select i.item_id, z.zone_id, f.price_naira as base_price
    from fact_food_price f
    join dim_item i on i.item_id = f.item_id
    join dim_zone z on z.zone_id = f.zone_id
    where f.month_date = date '2025-01-01'
),
indexed as (
    select z.zone_name, f.month_date, i.item_name,
           100.0 * f.price_naira / nullif(b.base_price, 0) as item_index
    from fact_food_price f
    join dim_item i on i.item_id = f.item_id
    join dim_zone z on z.zone_id = f.zone_id
    join base b     on b.item_id = f.item_id and b.zone_id = f.zone_id
    where f.month_date >= date '2025-01-01'
)
select zone_name, month_date,
       count(*)                           as items,
       round(avg(item_index)::numeric, 1) as food_index
from indexed
group by zone_name, month_date;

-- The two series side by side, with diesel lagged, since a haulage cost takes
-- time to reach a market stall.
create or replace view v_passthrough as
select fd.zone_name,
       fd.month_date,
       fd.food_index,
       dz.price_index                                                     as diesel_index,
       lag(dz.price_index, 1) over (partition by fd.zone_name order by fd.month_date) as diesel_lag1,
       lag(dz.price_index, 2) over (partition by fd.zone_name order by fd.month_date) as diesel_lag2,
       lag(dz.price_index, 3) over (partition by fd.zone_name order by fd.month_date) as diesel_lag3
from v_zone_food_index fd
join v_zone_fuel_index dz
  on dz.zone_name = fd.zone_name
 and dz.month_date = fd.month_date
 and dz.product_name = 'Diesel (AGO), litre';


-- ---------------------------------------------------------------------------
-- The natural experiment
-- ---------------------------------------------------------------------------

-- What each zone paid for petrol while the zones were far apart, and how far
-- above the cheapest zone that put it.

create or replace view v_episode_fuel_gap as
with zone_level as (
    select z.zone_name, avg(f.price_naira) as petrol_during
    from fact_fuel_price f
    join dim_product p on p.product_id = f.product_id
    join dim_state   s on s.state_id   = f.state_id
    join dim_zone    z on z.zone_id    = s.zone_id
    where p.product_name = 'Petrol (PMS), litre'
      and f.month_date between date '2025-01-01' and date '2025-04-01'
    group by z.zone_name
)
select zone_name,
       round(petrol_during::numeric, 0) as petrol_during,
       round((100.0 * petrol_during / min(petrol_during) over () - 100)::numeric, 1)
           as pct_above_cheapest_zone
from zone_level;


-- Each zone's fuel cost during the episode set against its food prices in the
-- months afterwards. If fuel feeds food, these two columns should rise together.

create or replace view v_passthrough_test as
select g.zone_name,
       g.petrol_during,
       g.pct_above_cheapest_zone,
       fi.month_date as food_month,
       fi.food_index
from v_episode_fuel_gap g
join v_zone_food_index fi on fi.zone_name = g.zone_name
where fi.month_date > date '2025-04-01';


-- The answer, one row per month after the episode. Correlation across the six
-- zones between what a zone paid for fuel and where its food prices sat.

create or replace view v_passthrough_result as
select food_month,
       count(*)                                            as zones,
       round(corr(petrol_during, food_index)::numeric, 3)  as correlation
from v_passthrough_test
group by food_month
order by food_month;

comment on view v_passthrough_result is
  'Read only the first few months. Six zones is six data points, and with n = 6 a '
  'correlation must exceed about 0.81 before it is distinguishable from chance. In '
  'May to September 2025, the window where a fuel effect could plausibly appear, '
  'the correlation sits between 0.17 and -0.30, which is nothing. From December '
  '2025 it reaches -0.87, and that figure is a trap rather than a finding: the fuel '
  'gap had been closed for eight months, the six food indices by then span only '
  'seven points, and those are the post-harvest months when Nigerian food prices '
  'normally fall. A correlation computed across six points over a seven-point range '
  'will swing wildly on noise. The conclusion is no detectable pass-through, not a '
  'negative one.';
