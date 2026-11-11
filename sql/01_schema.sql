-- Nigeria price watch: schema
-- Two staging tables matching the CSVs exactly, then a star built from them.
-- Fuel is published by state, food only by zone, so they are separate facts
-- at different grain rather than forced into one table.

drop table if exists fact_food_price, fact_fuel_price,
                     dim_item, dim_product, dim_state, dim_zone, dim_month,
                     stg_fuel_prices, stg_food_prices cascade;

-- ---------------------------------------------------------------- staging
create table stg_fuel_prices (
    product     text,
    zone        text,
    state       text,
    month       date,
    price       numeric(12,2),
    source_file text
);

create table stg_food_prices (
    item        text,
    zone        text,
    month       date,
    price       numeric(12,2),
    source_file text
);

-- ------------------------------------------------------------- dimensions
create table dim_zone (
    zone_id   int generated always as identity primary key,
    zone_name text not null unique
);

create table dim_state (
    state_id   int generated always as identity primary key,
    state_name text not null unique,
    zone_id    int not null references dim_zone (zone_id)
);

create table dim_product (
    product_id   int generated always as identity primary key,
    product_name text not null unique,
    fuel_type    text not null,
    unit         text not null
);

create table dim_item (
    item_id   int generated always as identity primary key,
    item_name text not null unique,
    basket    text not null          -- which NBS basket the label belongs to
);

create table dim_month (
    month_date date primary key,
    year       int  not null,
    month_num  int  not null,
    month_name text not null,
    quarter    text not null
);

-- ------------------------------------------------------------------ facts
create table fact_fuel_price (
    state_id    int   not null references dim_state (state_id),
    product_id  int   not null references dim_product (product_id),
    month_date  date  not null references dim_month (month_date),
    price_naira numeric(12,2) not null check (price_naira > 0),
    primary key (state_id, product_id, month_date)
);

create table fact_food_price (
    zone_id     int   not null references dim_zone (zone_id),
    item_id     int   not null references dim_item (item_id),
    month_date  date  not null references dim_month (month_date),
    price_naira numeric(12,2) not null check (price_naira > 0),
    primary key (zone_id, item_id, month_date)
);

create index on fact_fuel_price (month_date);
create index on fact_fuel_price (product_id);
create index on fact_food_price (month_date);
