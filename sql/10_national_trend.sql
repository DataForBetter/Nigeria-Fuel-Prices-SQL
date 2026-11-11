-- Q1. What happened to fuel prices nationally, November 2024 to May 2026?
-- Establishes the baseline every later question is measured against.

create or replace view v_national_monthly as
select p.product_name,
       p.fuel_type,
       p.unit,
       m.month_date,
       m.month_name,
       count(*)                                                          as states_reporting,
       round(avg(f.price_naira), 2)                                      as mean_price,
       round(percentile_cont(0.5) within group (order by f.price_naira)::numeric, 2) as median_price,
       round(min(f.price_naira), 2)                                      as min_price,
       round(max(f.price_naira), 2)                                      as max_price,
       round(stddev_samp(f.price_naira), 2)                              as sd_price
from fact_fuel_price f
join dim_product p on p.product_id = f.product_id
join dim_month   m on m.month_date = f.month_date
group by p.product_name, p.fuel_type, p.unit, m.month_date, m.month_name;

-- Month on month and year on year off the national mean.
create or replace view v_national_change as
select product_name,
       month_date,
       month_name,
       mean_price,
       lag(mean_price) over w                                              as prev_month,
       round(100.0 * (mean_price / nullif(lag(mean_price) over w, 0) - 1), 1) as mom_pct,
       lag(mean_price, 12) over w                                          as year_ago,
       round(100.0 * (mean_price / nullif(lag(mean_price, 12) over w, 0) - 1), 1) as yoy_pct
from v_national_monthly
window w as (partition by product_name order by month_date);

-- Headline: where each product started, where it ended, and the swing between.
create or replace view v_product_summary as
select product_name,
       min(month_date)                                                    as first_month,
       max(month_date)                                                    as last_month,
       count(*)                                                           as months,
       (array_agg(mean_price order by month_date))[1]                     as first_price,
       (array_agg(mean_price order by month_date desc))[1]                as last_price,
       round(100.0 * ((array_agg(mean_price order by month_date desc))[1]
                    / (array_agg(mean_price order by month_date))[1] - 1), 1) as change_pct,
       round(min(mean_price), 2)                                          as lowest_month_price,
       round(max(mean_price), 2)                                          as highest_month_price
from v_national_monthly
group by product_name;
