-- ============================================================================
--  MIGRATION 2 — Profit tracking
--  Run this ONCE in Supabase → SQL Editor (same as schema.sql).
--  Adds a private "cost" price so the dashboard can show real profit.
--  IMPORTANT: cost is hidden from the public shop (revoked from anon).
-- ============================================================================

-- 1. Cost columns
alter table products    add column if not exists cost integer not null default 0;
alter table order_items add column if not exists cost integer not null default 0;

-- 2. Hide cost from the public storefront (anon can read everything EXCEPT cost).
--    The dashboard (logged-in / authenticated) still sees it.
revoke select (cost) on products from anon;

-- 3. When an order is placed, snapshot each item's cost from the product,
--    server-side (the public site never sends or sees cost).
create or replace function place_order(payload jsonb)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_order_id uuid;
  v_order_no text;
  v_item jsonb;
  v_cost integer;
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
    -- look up this product's cost (defaults to 0 if unknown)
    select coalesce(cost,0) into v_cost from products
      where id = nullif(v_item->>'product_id','')::bigint;
    v_cost := coalesce(v_cost,0);

    insert into order_items(order_id, product_id, name, price, qty, line_total, cost, includes)
    values(
      v_order_id,
      nullif(v_item->>'product_id','')::bigint,
      v_item->>'name',
      coalesce((v_item->>'price')::int,0),
      coalesce((v_item->>'qty')::int,1),
      coalesce((v_item->>'price')::int,0) * coalesce((v_item->>'qty')::int,1),
      v_cost,
      v_item->'includes');

    update products
      set stock = greatest(stock - coalesce((v_item->>'qty')::int,1), 0)
      where id = nullif(v_item->>'product_id','')::bigint;
  end loop;

  if coalesce(payload->>'discount_code','') <> '' then
    update discount_codes
      set used_count = used_count + 1
      where upper(code) = upper(payload->>'discount_code');
  end if;

  return v_order_no;
end;
$$;

grant execute on function place_order(jsonb) to anon, authenticated;

-- Done. ✅  Set your cost prices in the dashboard (Stock or Catalogue).
