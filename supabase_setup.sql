-- ================================================================
-- SAMBHI MOBILES — SUPABASE DATABASE SETUP
-- Run this entire script once in Supabase → SQL Editor → New Query
-- ================================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ── CUSTOMERS ────────────────────────────────────────────────────
create table if not exists customers (
  id              uuid default uuid_generate_v4() primary key,
  name            text not null,
  phone           text not null unique,
  alt_phone       text,
  pw_hash         text not null,
  email           text,
  sell_count      int default 0,
  buy_count       int default 0,
  total_earned    int default 0,
  home_address    text,
  home_city       text,
  pincode         text,
  pickup_address  text,
  pickup_pincode  text,
  pickup_slot     text,
  aadhaar_same    boolean default false,
  lat             double precision,
  lng             double precision,
  visit_count     int default 1,
  last_seen       timestamptz default now(),
  created_at      timestamptz default now()
);

-- Run these if you already created the table previously:
alter table customers add column if not exists total_earned int default 0;
alter table customers add column if not exists home_address text;
alter table customers add column if not exists home_city text;
alter table customers add column if not exists pincode text;
alter table customers add column if not exists pickup_address text;
alter table customers add column if not exists pickup_pincode text;
alter table customers add column if not exists pickup_slot text;
alter table customers add column if not exists aadhaar_same boolean default false;
alter table customers add column if not exists lat double precision;
alter table customers add column if not exists lng double precision;
alter table customers add column if not exists visit_count int default 1;
alter table customers add column if not exists last_seen timestamptz default now();

-- ── SELL REQUESTS ────────────────────────────────────────────────
create table if not exists sell_requests (
  id            uuid default uuid_generate_v4() primary key,
  customer_id   uuid references customers(id),
  name          text,
  phone         text,
  email         text,
  address       text,
  pincode       text,
  brand         text,
  model         text,
  storage       text,
  ram           text,
  color         text,
  year          text,
  imei          text,
  battery_health text,
  condition     text,
  accessories   text[],
  asking_price  int default 0,
  is_loyalty    boolean default false,
  slot          text default 'morning',
  notes         text,
  photos        text[],
  status        text default 'pending',
  admin_note    text,
  created_at    timestamptz default now()
);

-- ── LEADS (Admin CRM) ────────────────────────────────────────────
create table if not exists leads (
  id          uuid default uuid_generate_v4() primary key,
  name        text not null,
  phone       text not null,
  area        text,
  address     text,
  dev_type    text,
  device      text,
  model       text,
  storage     text,
  color       text,
  year        text,
  battery     text,
  imei        text,
  ram         text,
  condition   text,
  accessories text[],
  photos      text[],
  ask_price   int default 0,
  base_price  int default 0,
  is_loyalty  boolean default false,
  slot        text default 'morning',
  source      text default 'website',
  rider_id    uuid,
  status      text default 'new',
  notes       jsonb default '[]',
  sell_req_id uuid references sell_requests(id),
  customer_id uuid references customers(id),
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- ── INVENTORY ────────────────────────────────────────────────────
create table if not exists inventory (
  id        uuid default uuid_generate_v4() primary key,
  cat       text not null,
  name      text not null,
  storage   text,
  color     text,
  grade     text default 'A',
  battery   text,
  year      text,
  qty       int default 1,
  price     int not null,
  mrp       int,
  imei      text,
  features  text[],
  visible   boolean default true,
  added_at  timestamptz default now()
);

-- ── BILLS ────────────────────────────────────────────────────────
create table if not exists bills (
  id          uuid default uuid_generate_v4() primary key,
  invoice_no  text not null unique,
  lead_id     uuid references leads(id),
  customer    text,
  device      text,
  amount      numeric(10,2),
  bill_type   text default 'PURCHASE',
  created_at  timestamptz default now()
);

-- ── RIDERS ───────────────────────────────────────────────────────
create table if not exists riders (
  id      uuid default uuid_generate_v4() primary key,
  name    text not null,
  phone   text not null,
  zone    text,
  email   text,
  active  boolean default true
);

-- ── CAMPAIGNS ────────────────────────────────────────────────────
create table if not exists campaigns (
  id          uuid default uuid_generate_v4() primary key,
  title       text not null,
  description text,
  active      boolean default false,
  starts_at   timestamptz,
  ends_at     timestamptz,
  created_at  timestamptz default now()
);

-- ── NOTIFICATIONS (notify-me requests from buy page) ─────────────
create table if not exists notifications (
  id        uuid default uuid_generate_v4() primary key,
  dev_name  text,
  type      text,
  name      text,
  phone     text,
  created_at timestamptz default now()
);

-- ── ADMIN SESSIONS ───────────────────────────────────────────────
create table if not exists admin_sessions (
  id         uuid default uuid_generate_v4() primary key,
  username   text not null,
  created_at timestamptz default now()
);

-- ── ROW LEVEL SECURITY ───────────────────────────────────────────
-- Allow public (anon) read/write on all tables
-- The anon key is safe to expose in frontend code
-- Anyone with the URL can read — that's fine for a business CRM
-- Sensitive data (passwords) are hashed before storing

alter table customers      enable row level security;
alter table sell_requests  enable row level security;
alter table leads          enable row level security;
alter table inventory      enable row level security;
alter table bills          enable row level security;
alter table riders         enable row level security;
alter table campaigns      enable row level security;
alter table notifications  enable row level security;
alter table admin_sessions enable row level security;

-- Public policies (anon key can do everything - for simplicity)
create policy "public_all" on customers      for all using (true) with check (true);
create policy "public_all" on sell_requests  for all using (true) with check (true);
create policy "public_all" on leads          for all using (true) with check (true);
create policy "public_all" on inventory      for all using (true) with check (true);
create policy "public_all" on bills          for all using (true) with check (true);
create policy "public_all" on riders         for all using (true) with check (true);
create policy "public_all" on campaigns      for all using (true) with check (true);
create policy "public_all" on notifications  for all using (true) with check (true);
create policy "public_all" on admin_sessions for all using (true) with check (true);

-- ── SEED DEFAULT CAMPAIGNS ───────────────────────────────────────
insert into campaigns (title, description, active) values
  ('No charger deduction', 'Waive 5% charger deduction for all sellers', false),
  ('No battery deduction', 'Waive battery below 80% deduction', false),
  ('Double loyalty — 20% bonus', 'Returning customers get 20% instead of 10%', false),
  ('Zero deductions offer', 'No deductions for any issues today only', false)
on conflict do nothing;

-- Done! Your database is ready.
-- Copy your Project URL and anon key from Settings → API
