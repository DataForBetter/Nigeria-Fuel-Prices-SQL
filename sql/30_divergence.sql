-- Q3. What happened in early 2025, and who did it hit?
-- Compares each state against the national median for that month, so a state
-- is measured against the country rather than against its own history. The
-- shock window is January to April 2025, bounded by the dispersion view.

create or replace view v_state_vs_national as
with national as (
    select product_id,
           month_date,
           percentile_cont(0.5) within group (order by price_naira) as median_price
    from fact_fuel_price
    group by product_id, month_date
)
select p.product_name,
       m.month_date,
       m.month_name,
       s.state_name,
       z.zone_name,
       f.price_naira,
       round(n.median_price::numeric, 2)                                   as national_median,
       round((f.price_naira - n.median_price)::numeric, 2)                 as naira_vs_median,
       round((100.0 * (f.price_naira / nullif(n.median_price, 0) - 1))::numeric, 1) as pct_vs_median
from fact_fuel_price f
join national n  on n.product_id = f.product_id and n.month_date = f.month_date
join dim_product p on p.product_id = f.product_id
join dim_month   m on m.month_date = f.month_date
join dim_state   s on s.state_id   = f.state_id
join dim_zone    z on z.zone_id    = s.zone_id;

-- Who was above the national median during the shock, and were they above it
-- before and after? A state that was only dear during the window was shocked.
-- A state dear throughout is structurally expensive, which is a different thing.
create or replace view v_shock_states as
select product_name,
       state_name,
       zone_name,
       round(avg(pct_vs_median) filter (where month_date < '2025-01-01'), 1)                        as before_pct,
       round(avg(pct_vs_median) filter (where month_date between '2025-01-01' and '2025-04-01'), 1) as shock_pct,
       round(avg(pct_vs_median) filter (where month_date > '2025-04-01'), 1)                        as after_pct,
       round(avg(pct_vs_median) filter (where month_date between '2025-01-01' and '2025-04-01')
           - avg(pct_vs_median) filter (where month_date not between '2025-01-01' and '2025-04-01'), 1) as shock_gap
from v_state_vs_national
group by product_name, state_name, zone_name;

-- Did the shock hit every fuel, or only petrol? If only petrol, it points at
-- that supply chain rather than at a general cost shock.
create or replace view v_shock_by_zone_product as
select product_name,
       zone_name,
       round(avg(pct_vs_median) filter (where month_date between '2025-01-01' and '2025-04-01'), 1) as shock_pct,
       round(avg(pct_vs_median) filter (where month_date not between '2025-01-01' and '2025-04-01'), 1) as rest_pct,
       round(avg(pct_vs_median) filter (where month_date between '2025-01-01' and '2025-04-01')
           - avg(pct_vs_median) filter (where month_date not between '2025-01-01' and '2025-04-01'), 1) as gap
from v_state_vs_national
group by product_name, zone_name;
