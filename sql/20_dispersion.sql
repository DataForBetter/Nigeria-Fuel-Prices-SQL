-- Q2. How much does what you pay depend on where you live, and is the gap closing?
-- The coefficient of variation is the comparable measure here, since the six
-- products sit at wildly different price levels and a raw spread in naira
-- cannot be compared between a litre of petrol and a 12.5kg gas cylinder.

create or replace view v_dispersion_monthly as
with priced as (
    select p.product_name, p.fuel_type, m.month_date, m.month_name,
           s.state_name, z.zone_name, f.price_naira
    from fact_fuel_price f
    join dim_product p on p.product_id = f.product_id
    join dim_month   m on m.month_date = f.month_date
    join dim_state   s on s.state_id   = f.state_id
    join dim_zone    z on z.zone_id    = s.zone_id
)
select product_name,
       month_date,
       month_name,
       round(avg(price_naira), 2)                                  as mean_price,
       round(min(price_naira), 2)                                  as cheapest_price,
       round(max(price_naira), 2)                                  as dearest_price,
       round(max(price_naira) - min(price_naira), 2)               as spread_naira,
       round(100.0 * (max(price_naira) - min(price_naira)) / min(price_naira), 1) as spread_pct,
       round(stddev_samp(price_naira), 2)                          as sd_price,
       round(100.0 * stddev_samp(price_naira) / avg(price_naira), 1) as cv_pct,
       (array_agg(state_name order by price_naira))[1]             as cheapest_state,
       (array_agg(state_name order by price_naira desc))[1]        as dearest_state,
       (array_agg(zone_name  order by price_naira desc))[1]        as dearest_zone
from priced
group by product_name, month_date, month_name;

-- Is dispersion trending anywhere, or just noisy? Compare each month's
-- coefficient of variation with the rolling average of the three before it.
create or replace view v_dispersion_trend as
select product_name,
       month_date,
       month_name,
       cv_pct,
       round(avg(cv_pct) over (partition by product_name order by month_date
                               rows between 3 preceding and 1 preceding), 1) as cv_prior_3m,
       round(cv_pct - avg(cv_pct) over (partition by product_name order by month_date
                               rows between 3 preceding and 1 preceding), 1) as cv_vs_prior
from v_dispersion_monthly;

-- Persistence: is a state dear because of a one-off shock, or every month?
-- Ranks each state within each month, then averages the rank across the period.
create or replace view v_state_persistence as
with ranked as (
    select p.product_name, s.state_name, z.zone_name, f.month_date,
           f.price_naira,
           rank() over (partition by p.product_name, f.month_date
                        order by f.price_naira desc) as dearest_rank
    from fact_fuel_price f
    join dim_product p on p.product_id = f.product_id
    join dim_state   s on s.state_id   = f.state_id
    join dim_zone    z on z.zone_id    = s.zone_id
)
select product_name, state_name, zone_name,
       count(*)                                   as months,
       round(avg(dearest_rank), 1)                as avg_rank,
       count(*) filter (where dearest_rank <= 5)  as months_in_top5,
       count(*) filter (where dearest_rank >= 33) as months_in_bottom5,
       round(avg(price_naira), 2)                 as avg_price
from ranked
group by product_name, state_name, zone_name;
