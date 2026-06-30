-- ============================================================================
--  TORIA'S GLAM HAVEN — Backend database schema
--  Run this ONCE in your Supabase project:  SQL Editor → New query → paste → Run
--  Safe to re-run: it uses "if not exists" / "on conflict" everywhere.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------------

-- Products (commerce fields the dashboard manages: price, stock, tag, active).
-- Your 30 existing products are seeded below. New products you upload from the
-- dashboard live fully here (with their own description, tip and image_url).
create table if not exists products (
  id           bigint primary key,          -- matches the id used on the storefront
  cat          text   not null,             -- earrings | necklaces | sets | giftsets
  name         text   not null,
  price        integer not null,
  was          integer,                     -- original/compare-at price (optional)
  tag          text,                        -- e.g. Best Seller, New, Sale
  description  text,                         -- used for NEW products created here
  tip          text,                         -- styling tip for NEW products
  image_url    text,                         -- uploaded image for NEW products
  includes     jsonb,                        -- gift-box contents (array of strings)
  stock        integer not null default 10,  -- units on hand
  low_stock_at integer not null default 3,   -- "low stock" warning threshold
  active       boolean not null default true,-- false = hidden from the shop
  sort         integer not null default 100, -- display order (lower = first)
  created_at   timestamptz not null default now()
);

-- Orders — one row per checkout.
create table if not exists orders (
  id             uuid primary key default gen_random_uuid(),
  order_no       text unique not null,
  customer_name  text,
  customer_phone text,
  town           text,
  county         text,
  delivery_type  text,                       -- town | mtaani | express
  delivery_detail text,
  delivery_fee   integer not null default 0,
  is_gift        boolean not null default false,
  occasion       text,
  card_message   text,
  subtotal       integer not null default 0,
  discount_code  text,
  discount_amount integer not null default 0,
  total          integer not null default 0,
  status         text not null default 'new',-- new|confirmed|paid|packed|delivered|cancelled
  notes          text,
  created_at     timestamptz not null default now()
);

-- Order line items — one row per product in an order (powers analytics).
create table if not exists order_items (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references orders(id) on delete cascade,
  product_id  bigint,
  name        text,
  price       integer not null default 0,
  qty         integer not null default 1,
  line_total  integer not null default 0,
  includes    jsonb,
  created_at  timestamptz not null default now()
);

-- Newsletter / "Glam Circle" sign-ups.
create table if not exists subscribers (
  id         uuid primary key default gen_random_uuid(),
  email      text unique not null,
  source     text default 'newsletter',
  created_at timestamptz not null default now()
);

-- Discount codes (created & tracked from the dashboard).
create table if not exists discount_codes (
  id         uuid primary key default gen_random_uuid(),
  code       text unique not null,
  type       text not null check (type in ('pct','flat')),  -- percent or flat KSh
  value      integer not null,
  active     boolean not null default true,
  max_uses   integer,                        -- null = unlimited
  used_count integer not null default 0,
  expires_at timestamptz,                     -- null = no expiry
  created_at timestamptz not null default now()
);

-- Product views — lets the dashboard show "viewed but not selling".
create table if not exists product_views (
  id         uuid primary key default gen_random_uuid(),
  product_id bigint,
  created_at timestamptz not null default now()
);

create index if not exists idx_order_items_order on order_items(order_id);
create index if not exists idx_order_items_product on order_items(product_id);
create index if not exists idx_orders_created on orders(created_at);
create index if not exists idx_views_product on product_views(product_id);

-- ---------------------------------------------------------------------------
-- 2. SECURITY (Row Level Security)
--    The storefront uses a PUBLIC key, so we lock everything down:
--    visitors can only read the shop and place orders through safe functions.
--    You (logged in to the dashboard) can do everything.
-- ---------------------------------------------------------------------------

alter table products       enable row level security;
alter table orders         enable row level security;
alter table order_items    enable row level security;
alter table subscribers    enable row level security;
alter table discount_codes enable row level security;
alter table product_views  enable row level security;

-- Shop: anyone may READ active products. Only logged-in admin may change them.
drop policy if exists p_products_read on products;
create policy p_products_read on products
  for select using (active = true or auth.role() = 'authenticated');
drop policy if exists p_products_admin on products;
create policy p_products_admin on products
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Orders / items / subscribers / views: visitors CANNOT read them (privacy).
-- Writes happen only through the SECURITY DEFINER functions below.
-- Logged-in admin has full access.
drop policy if exists p_orders_admin on orders;
create policy p_orders_admin on orders
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
drop policy if exists p_items_admin on order_items;
create policy p_items_admin on order_items
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
drop policy if exists p_subs_admin on subscribers;
create policy p_subs_admin on subscribers
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
drop policy if exists p_codes_admin on discount_codes;
create policy p_codes_admin on discount_codes
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
drop policy if exists p_views_admin on product_views;
create policy p_views_admin on product_views
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ---------------------------------------------------------------------------
-- 3. SAFE PUBLIC FUNCTIONS (callable by the storefront)
-- ---------------------------------------------------------------------------

-- Validate a discount code without exposing the whole codes table.
create or replace function validate_discount(p_code text)
returns table(code text, type text, value integer)
language sql security definer set search_path = public as $$
  select c.code, c.type, c.value
  from discount_codes c
  where upper(c.code) = upper(p_code)
    and c.active = true
    and (c.expires_at is null or c.expires_at > now())
    and (c.max_uses is null or c.used_count < c.max_uses)
  limit 1;
$$;

-- Save a newsletter sign-up (ignores duplicates).
create or replace function subscribe(p_email text, p_source text default 'newsletter')
returns void
language sql security definer set search_path = public as $$
  insert into subscribers(email, source)
  values (lower(trim(p_email)), coalesce(p_source,'newsletter'))
  on conflict (email) do nothing;
$$;

-- Record a product view (for analytics).
create or replace function track_view(p_id bigint)
returns void
language sql security definer set search_path = public as $$
  insert into product_views(product_id) values (p_id);
$$;

-- Place an order: writes the order + items, bumps discount usage, lowers stock.
-- Returns the order number. payload is a JSON object from the checkout page.
create or replace function place_order(payload jsonb)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_order_id uuid;
  v_order_no text;
  v_item jsonb;
begin
  v_order_no := coalesce(payload->>'order_no', 'TGH-'||to_char(now(),'YYYYMMDD')||'-'||floor(random()*900+100)::text);

  insert into orders(
    order_no, customer_name, customer_phone, town, county,
    delivery_type, delivery_detail, delivery_fee,
    is_gift, occasion, card_message,
    subtotal, discount_code, discount_amount, total)
  values(
    v_order_no,
    payload->>'customer_name', payload->>'customer_phone', payload->>'town', payload->>'county',
    payload->>'delivery_type', payload->>'delivery_detail', coalesce((payload->>'delivery_fee')::int,0),
    coalesce((payload->>'is_gift')::boolean,false), payload->>'occasion', payload->>'card_message',
    coalesce((payload->>'subtotal')::int,0), nullif(payload->>'discount_code',''),
    coalesce((payload->>'discount_amount')::int,0), coalesce((payload->>'total')::int,0))
  returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(coalesce(payload->'items','[]'::jsonb))
  loop
    insert into order_items(order_id, product_id, name, price, qty, line_total, includes)
    values(
      v_order_id,
      nullif(v_item->>'product_id','')::bigint,
      v_item->>'name',
      coalesce((v_item->>'price')::int,0),
      coalesce((v_item->>'qty')::int,1),
      coalesce((v_item->>'price')::int,0) * coalesce((v_item->>'qty')::int,1),
      v_item->'includes');

    -- lower stock if this maps to a known product
    update products
      set stock = greatest(stock - coalesce((v_item->>'qty')::int,1), 0)
      where id = nullif(v_item->>'product_id','')::bigint;
  end loop;

  -- count the discount usage
  if coalesce(payload->>'discount_code','') <> '' then
    update discount_codes
      set used_count = used_count + 1
      where upper(code) = upper(payload->>'discount_code');
  end if;

  return v_order_no;
end;
$$;

-- Let the public (storefront) call only these safe functions.
grant execute on function validate_discount(text) to anon, authenticated;
grant execute on function subscribe(text, text)   to anon, authenticated;
grant execute on function track_view(bigint)       to anon, authenticated;
grant execute on function place_order(jsonb)        to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. IMAGE STORAGE (for catalogue uploads from the dashboard)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('catalogue','catalogue', true)
on conflict (id) do nothing;

drop policy if exists p_cat_read on storage.objects;
create policy p_cat_read on storage.objects
  for select using (bucket_id = 'catalogue');
drop policy if exists p_cat_write on storage.objects;
create policy p_cat_write on storage.objects
  for insert with check (bucket_id = 'catalogue' and auth.role() = 'authenticated');
drop policy if exists p_cat_update on storage.objects;
create policy p_cat_update on storage.objects
  for update using (bucket_id = 'catalogue' and auth.role() = 'authenticated');
drop policy if exists p_cat_delete on storage.objects;
create policy p_cat_delete on storage.objects
  for delete using (bucket_id = 'catalogue' and auth.role() = 'authenticated');

-- ---------------------------------------------------------------------------
-- 5. SEED — your current catalogue (commerce fields) and discount codes
--    Visual content (photos, descriptions) for these stays on the storefront;
--    here we track price, stock, tag and visibility so the dashboard can manage
--    them. Re-running updates nothing you've since changed (on conflict do nothing).
-- ---------------------------------------------------------------------------
insert into products (id, cat, name, price, was, tag, stock, sort) values
  (1,'earrings','Solar Flare Pearl Studs',1500,null,'Best Seller',10,10),
  (2,'earrings','Aurelia Twisted Hoops',1100,1200,'Best Seller',10,11),
  (3,'earrings','Trinity Triple Hoops',1300,null,'New',10,12),
  (22,'earrings','Entwine Knot Earrings',1100,null,'New',10,13),
  (21,'earrings','Gilded Trio Earrings',1900,null,'New',10,14),
  (31,'earrings','Cascade Link Drops',1300,null,'New',10,15),
  (6,'necklaces','Emerald Noir Pendant',1350,null,'Best Seller',10,20),
  (7,'necklaces','Amethyst Glow Necklace',1250,null,null,10,21),
  (23,'necklaces','Pearl Cascade Lariat',1800,null,'New',10,22),
  (24,'necklaces','Onyx Cascade Lariat',1800,null,'New',10,23),
  (25,'necklaces','Baroque Pearl Pendant',1500,null,'New',10,24),
  (26,'necklaces','Gilded Link Pendant',1300,null,'New',10,25),
  (27,'necklaces','Eternity Swirl Pendant',1300,null,'New',10,26),
  (28,'necklaces','Union Twin Pendant',1300,null,'New',10,27),
  (29,'necklaces','Scarlet Solitaire Pendant',1300,null,'New',10,28),
  (30,'necklaces','Helios Sunray Pendant',1500,null,'New',10,29),
  (32,'necklaces','Black Opal Trio Necklace',1500,null,'New',10,30),
  (8,'sets','Celestial Halo Set',2150,null,'Best Seller',10,40),
  (15,'sets','Luna Glow Set',2150,null,'New',10,41),
  (16,'sets','Minimal Luxe Set',2150,null,'New',10,42),
  (17,'sets','Luxe Lattice Set',2150,null,'New',10,43),
  (18,'sets','Black Opal Set',2150,null,'New',10,44),
  (19,'sets','Aurelia Luxe Set',2500,null,'New',10,45),
  (10,'giftsets','The Amour Box',4000,null,'Valentine',99,50),
  (11,'giftsets','The Allure Box',5500,null,'Perfume',99,51),
  (12,'giftsets','The Gilded Box',5000,null,'Popular',99,52),
  (13,'giftsets','The Opulence Box',7500,null,'Top Tier',99,53),
  (14,'giftsets','The Sovereign Box',5500,null,'For Mum',99,54)
on conflict (id) do nothing;

insert into discount_codes (code, type, value, active) values
  ('GLAM10','pct',10,true),
  ('WELCOME100','flat',100,true)
on conflict (code) do nothing;

-- Done. ✅
