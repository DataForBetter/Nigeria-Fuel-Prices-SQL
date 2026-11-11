-- Q4. Do fuel costs reach food prices?
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
