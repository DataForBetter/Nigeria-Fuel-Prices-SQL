-- Q5. When a fuel price moves, is it the whole country moving together,
-- or is it the states coming apart?
--
-- Every month a product has two separable properties: how expensive it is on
-- average (the level), and how much the 36 states and the FCT disagree with each other
-- (the dispersion). A national average reports only the first, which is why a
-- month where every state agrees on a high price and a month where half the
-- country pays double look identical in the headline.
--
-- Dispersion is measured as the coefficient of variation, the standard
-- deviation as a percentage of the mean. A percentage rather than a naira
-- figure, so that cooking gas at 17,000 naira and petrol at 1,200 can be
-- compared on the same scale.

create or replace view v_product_profile as
select p.product_name,
       f.month_date,
       count(*)                                           as states,
       round(avg(f.price_naira)::numeric, 2)              as mean_price,
       round((percentile_cont(0.5) within group (order by f.price_naira))::numeric, 2)
                                                          as median_price,
       round(min(f.price_naira)::numeric, 2)              as cheapest,
       round(max(f.price_naira)::numeric, 2)              as dearest,
       round(stddev(f.price_naira)::numeric, 2)           as sd,
       round((100 * stddev(f.price_naira) / avg(f.price_naira))::numeric, 2)
                                                          as cv_pct,
       round((100 * (max(f.price_naira) - min(f.price_naira)) / min(f.price_naira))::numeric, 1)
                                                          as spread_pct,
       count(distinct round(f.price_naira::numeric, 2))   as distinct_prices
from fact_fuel_price f
join dim_product p on p.product_id = f.product_id
group by p.product_name, f.month_date;

comment on view v_product_profile is
  'Level and dispersion of every fuel product in every month. distinct_prices is '
  'a data-integrity column: if NBS ever stopped surveying states individually and '
  'started repeating one figure, it would collapse toward 1.';


-- The two episodes in this dataset, and the ordinary months on either side of
-- them, named once here so that nothing downstream hard-codes a date.

create or replace view v_shock_window as
select *
from (values
    ('baseline 2024',  date '2024-11-01', date '2024-12-01'),
    ('episode 1',      date '2025-01-01', date '2025-04-01'),
    ('recovery 2025',  date '2025-05-01', date '2025-08-01'),
    ('baseline 2026',  date '2026-01-01', date '2026-02-01'),
    ('episode 2',      date '2026-03-01', date '2026-05-01')
) as t(window_name, starts, ends);


-- The comparison the findings are built on. One row per product per window,
-- showing what the level did and what the dispersion did.

create or replace view v_shock_profile as
select w.window_name,
       pr.product_name,
       w.starts,
       w.ends,
       round(avg(pr.mean_price), 0) as level,
       round(avg(pr.cv_pct), 1)     as dispersion_pct,
       round(avg(pr.spread_pct), 0) as spread_pct
from v_shock_window w
join v_product_profile pr
  on pr.month_date between w.starts and w.ends
group by w.window_name, pr.product_name, w.starts, w.ends;


-- The same thing stated as a verdict rather than a table. For each product,
-- how far did the level move between a window and its baseline, and how far
-- did the dispersion move. A distribution failure shows a large dispersion
-- change and a small level change. An input cost shock shows the reverse.

create or replace view v_shock_verdict as
with paired as (
    select e.product_name,
           e.window_name,
           e.level            as level_now,
           b.level            as level_base,
           e.dispersion_pct   as disp_now,
           b.dispersion_pct   as disp_base
    from v_shock_profile e
    join v_shock_profile b
      on b.product_name = e.product_name
     and b.window_name = case e.window_name
                             when 'episode 1' then 'baseline 2024'
                             when 'episode 2' then 'baseline 2026'
                         end
)
select product_name,
       window_name,
       level_base,
       level_now,
       round(100 * (level_now - level_base) / nullif(level_base, 0), 1) as level_change_pct,
       disp_base,
       disp_now,
       round(disp_now - disp_base, 1)                                   as dispersion_change_pp,
       case
         when abs(100 * (level_now - level_base) / nullif(level_base, 0)) >= 15
              and (disp_now - disp_base) >= 5             then 'level and dispersion'
         when abs(100 * (level_now - level_base) / nullif(level_base, 0)) >= 15
                                                          then 'level shock'
         when (disp_now - disp_base) >= 5                 then 'dispersion shock'
         else 'no clear shock'
       end                                                              as signature
from paired
order by window_name, level_change_pct desc;

comment on view v_shock_verdict is
  'The 15 per cent and 5 percentage point thresholds are judgement, not a test. '
  'They are set where they are because the two episodes in this dataset sit far '
  'outside them and the ordinary months sit far inside. On a longer series they '
  'would need revisiting.';


-- Where a dispersion shock lands geographically. If price is tracking distance
-- from the point of supply, the zones furthest from Lagos pay most during the
-- episode and that ordering disappears afterwards.

create or replace view v_shock_geography as
select w.window_name,
       p.product_name,
       z.zone_name,
       round(avg(f.price_naira)::numeric, 0) as zone_level
from v_shock_window w
join fact_fuel_price f on f.month_date between w.starts and w.ends
join dim_product p on p.product_id = f.product_id
join dim_state   s on s.state_id   = f.state_id
join dim_zone    z on z.zone_id    = s.zone_id
group by w.window_name, p.product_name, z.zone_name;
