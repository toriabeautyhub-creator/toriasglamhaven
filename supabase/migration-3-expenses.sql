-- ============================================================================
--  MIGRATION 3 — Cost breakdown + Expenses ledger (net profit)
--  Run ONCE in Supabase → SQL Editor.  Run AFTER migration-2-profit.sql.
-- ============================================================================

-- 1. Per-item cost breakdown (all private — hidden from the public shop).
--    Your item's total `cost` = buy_price + ship_cost + pack_cost.
alter table products add column if not exists buy_price  integer not null default 0;
alter table products add column if not exists ship_cost  integer not null default 0;
alter table products add column if not exists pack_cost  integer not null default 0;

revoke select (buy_price) on products from anon;
revoke select (ship_cost) on products from anon;
revoke select (pack_cost) on products from anon;

-- 2. Expenses ledger — every business cost (packaging restock, shipping, rent…).
create table if not exists expenses (
  id          uuid primary key default gen_random_uuid(),
  spent_on    date not null default current_date,
  category    text not null default 'other',   -- packaging | shipping | stock | transport | marketing | rent | other
  description text,
  amount      integer not null default 0,
  created_at  timestamptz not null default now()
);

-- Only you (logged in) can see or touch expenses. The public has no access.
alter table expenses enable row level security;
drop policy if exists p_exp_admin on expenses;
create policy p_exp_admin on expenses
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create index if not exists idx_expenses_date on expenses(spent_on);

-- Done. ✅  Set cost breakdowns in Stock/Catalogue, log costs in the Expenses tab.
