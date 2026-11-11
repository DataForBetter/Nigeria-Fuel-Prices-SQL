-- Nigeria price watch: build the star from the two staging tables.
-- Run after importing fuel_prices.csv and food_prices.csv into
-- stg_fuel_prices and stg_food_prices.

truncate fact_fuel_price, fact_food_price,
         dim_item, dim_product, dim_state, dim_zone, dim_month restart identity cascade;

-- ----------------------------------------------------------------- zones
insert into dim_zone (zone_name)
select distinct zone from (
    select zone from stg_fuel_prices
    union
    select zone from stg_food_prices
) z
where zone is not null and zone <> ''
order by 1;

-- ---------------------------------------------------------------- states
-- NBS is not internally consistent about zones: the petrol series files
-- Taraba under the North West while every other series has it in the North
-- East. Take the majority verdict rather than whichever row arrives first.
insert into dim_state (state_name, zone_id)
select s.state, z.zone_id
from (
    select state, mode() within group (order by zone) as zone
    from stg_fuel_prices
    where zone is not null and zone <> ''
    group by state
) s
join dim_zone z on z.zone_name = s.zone
order by 1;

-- -------------------------------------------------------------- products
-- Product labels arrive as "Petrol (PMS), litre", so split on the comma
-- into the fuel itself and the unit it is priced in.
insert into dim_product (product_name, fuel_type, unit)
select distinct
       product,
       btrim(split_part(product, ',', 1)),
       btrim(split_part(product, ',', 2))
from stg_fuel_prices
order by 1;

-- ----------------------------------------------------------------- items
-- NBS rebased the food basket between Dec 2024 and Jan 2025 and renamed
-- almost every label, so each item is tagged with the basket it belongs to.
insert into dim_item (item_name, basket)
select item,
       case when max(month) < date '2025-01-01' then 'Basket to Dec 2024'
            when min(month) >= date '2025-01-01' then 'Basket from Jan 2025'
            else 'Spans both baskets'
       end
from stg_food_prices
group by item
order by item;

-- ---------------------------------------------------------------- months
insert into dim_month (month_date, year, month_num, month_name, quarter)
select m, extract(year from m)::int, extract(month from m)::int,
       to_char(m, 'Mon YYYY'),
       'Q' || extract(quarter from m)::int
from (
    select distinct month as m from stg_fuel_prices
    union
    select distinct month from stg_food_prices
) x
order by m;

-- ------------------------------------------------------------ fuel facts
insert into fact_fuel_price (state_id, product_id, month_date, price_naira)
select st.state_id, p.product_id, s.month, s.price
from stg_fuel_prices s
join dim_state   st on st.state_name   = s.state
join dim_product p  on p.product_name  = s.product
where s.price > 0;

-- ------------------------------------------------------------ food facts
insert into fact_food_price (zone_id, item_id, month_date, price_naira)
select z.zone_id, i.item_id, f.month, f.price
from stg_food_prices f
join dim_zone z on z.zone_name = f.zone
join dim_item i on i.item_name = f.item
where f.price > 0;
