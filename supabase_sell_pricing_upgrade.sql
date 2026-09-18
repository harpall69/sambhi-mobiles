-- ================================================================
-- SAMBHI MOBILES — SELL-FLOW PRICING & AUDIT-TRAIL UPGRADE
-- Run this in the Supabase SQL Editor AFTER supabase_setup.sql,
-- supabase_real_schema_fix.sql and supabase_rider_pricing_upgrade.sql
-- have already been applied (depends on: leads, condition_pricing,
-- assert_is_owner(), team_users).
--
-- What this adds, and why:
--   1. `leads.email` / `leads.diagnostics` — these were previously folded
--      into the `notes` text blob because the columns didn't exist (see
--      the code comment this replaces in shared.js). Real columns now.
--   2. `pricing_rules` — a generic question_key/answer_key → adjustment %
--      table, additive to the existing `condition_pricing` table (which
--      is untouched and still drives Overall Condition). Covers the
--      previously price-inert factors: screen condition, body condition,
--      water damage, repaired parts, accessories, and battery tiers
--      (migrating the old hardcoded BATT_DEDUCT into the same
--      admin-editable mechanism as everything else).
--   3. `set_pricing_rule()` — same assert_is_owner-gated RPC pattern as
--      the existing set_condition_pricing(), just generalized.
--   4. `price_adjustments` — one row per pricing step per lead, the full
--      audit trail the CRM needs to show *why* a customer got their price.
--   5. `submit_sell_lead()` — a SECURITY DEFINER RPC that validates every
--      required field server-side (never trust the frontend alone) and
--      inserts the lead + all of its price_adjustments rows in one
--      transaction. Replaces the previous direct `SB.insert('leads', ...)`
--      call from the browser.
--   6. Fixes a pre-existing bug found during this work: the lead-insert
--      code and the notify_new_lead() trigger both referenced a column
--      called `est_price`, which was never created by any migration —
--      only `ask_price` exists. Both are corrected to use `ask_price`.
-- ================================================================

-- ── 1. Missing leads columns ─────────────────────────────────────
alter table leads add column if not exists email text;
alter table leads add column if not exists diagnostics jsonb default '{}';

-- ── 2. Generic pricing_rules table ───────────────────────────────
create table if not exists pricing_rules (
  id                  uuid default uuid_generate_v4() primary key,
  question_key        text not null,
  answer_key          text not null,
  adjustment_percent  numeric not null check (adjustment_percent >= -100 and adjustment_percent <= 100),
  active              boolean not null default true,
  created_at          timestamptz default now(),
  updated_at          timestamptz default now(),
  unique (question_key, answer_key)
);

alter table pricing_rules enable row level security;
drop policy if exists "public_read_pricing_rules" on pricing_rules;
create policy "public_read_pricing_rules" on pricing_rules for select using (true);
grant select on pricing_rules to anon, authenticated;
-- No insert/update/delete policy — writes only via set_pricing_rule() below.

-- Seed data. These are starting points, not final answers — edit them from
-- the CRM's Prices tab (or directly here) at any time; the frontend reads
-- them live and falls back to its own hardcoded copy only if this table is
-- unreachable. Answer keys must match the exact strings the wizard sends
-- (case-sensitive) — see sell.html's pickSubCond/pickWater/togRepair/togAcc.
insert into pricing_rules (question_key, answer_key, adjustment_percent) values
  ('screen_condition', 'Perfect',              0),
  ('screen_condition', 'Minor scratches',      -5),
  ('screen_condition', 'Cracked',             -25),

  ('body_condition',   'Perfect',               0),
  ('body_condition',   'Minor scratches',      -5),
  ('body_condition',   'Dents/cracks',        -15),

  ('water_damage',     'true',                -20),
  ('water_damage',     'false',                 0),

  ('repaired_parts',   'Screen replaced',      -8),
  ('repaired_parts',   'Battery replaced',     -5),
  ('repaired_parts',   'Back panel replaced',  -6),

  ('accessories',      'Original Box',          2),
  ('accessories',      'Charger',               1),
  ('accessories',      'Earphones',             1),
  ('accessories',      'Cable',               0.5),
  ('accessories',      'Cover',               0.5),
  ('accessories',      'Invoice',               1),
  ('accessories',      'Screen Guard',        0.5),

  -- Battery tiers, migrated from the old hardcoded BATT_DEDUCT (iPhone-only
  -- deduction; key = battery % floored to the nearest 5).
  ('battery_tier', '100',   0), ('battery_tier', '95',  0), ('battery_tier', '90',  0),
  ('battery_tier', '85',   -3), ('battery_tier', '80', -6), ('battery_tier', '75', -10),
  ('battery_tier', '70',  -15), ('battery_tier', '60', -22), ('battery_tier', '50', -30)
on conflict (question_key, answer_key) do nothing;

-- ── 3. set_pricing_rule RPC (same owner-gated pattern as set_condition_pricing) ──
create or replace function set_pricing_rule(
  p_caller_username text,
  p_caller_password text,
  p_question_key text,
  p_answer_key text,
  p_adjustment_percent numeric
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_is_owner(p_caller_username, p_caller_password);
  if p_adjustment_percent < -100 or p_adjustment_percent > 100 then
    raise exception 'Adjustment percent out of allowed range (-100 to 100)';
  end if;
  insert into pricing_rules (question_key, answer_key, adjustment_percent)
  values (p_question_key, p_answer_key, p_adjustment_percent)
  on conflict (question_key, answer_key)
  do update set adjustment_percent = excluded.adjustment_percent, updated_at = now();
  return true;
end;
$$;
grant execute on function set_pricing_rule(text, text, text, text, numeric) to anon, authenticated;

-- ── 4. price_adjustments — the full per-lead pricing audit trail ────
create table if not exists price_adjustments (
  id                     uuid default uuid_generate_v4() primary key,
  lead_id                uuid not null references leads(id) on delete cascade,
  question_key           text not null,
  question_label         text not null,
  answer                 text,
  base_price             numeric not null,
  adjustment_percentage  numeric not null,
  adjustment_amount      numeric not null,
  resulting_price        numeric not null,
  created_at             timestamptz default now()
);
create index if not exists price_adjustments_lead_id_idx on price_adjustments(lead_id);

alter table price_adjustments enable row level security;
drop policy if exists "public_read_price_adjustments" on price_adjustments;
create policy "public_read_price_adjustments" on price_adjustments for select using (true);
grant select on price_adjustments to anon, authenticated;
-- No insert/update/delete policy — rows are only ever written by
-- submit_sell_lead() below (SECURITY DEFINER bypasses RLS for that insert).

-- ── 5. submit_sell_lead — validated, atomic lead + audit-trail insert ──
-- p_price_steps is a jsonb array of objects shaped like:
--   {"question_key":"screen_condition","question_label":"Screen Condition",
--    "answer":"Minor scratches","base_price":30000,"adjustment_percentage":-5,
--    "adjustment_amount":-1500,"resulting_price":28500}
create or replace function submit_sell_lead(
  p_name text,
  p_phone text,
  p_email text default null,
  p_address text default null,
  p_area text default null,
  p_zone text default null,
  p_pincode text default null,
  p_dev_type text default null,
  p_device text default null,
  p_model text default null,
  p_storage text default null,
  p_ram text default null,
  p_color text default null,
  p_year text default null,
  p_month text default null,
  p_imei text default null,
  p_battery text default null,
  p_condition text default null,
  p_screen_condition text default null,
  p_body_condition text default null,
  p_water_damage boolean default false,
  p_repaired_parts text[] default '{}',
  p_accessories text[] default '{}',
  p_photos text[] default '{}',
  p_bill_photo text default null,
  p_base_price numeric default 0,
  p_ask_price numeric default 0,
  p_is_loyalty boolean default false,
  p_customer_id uuid default null,
  p_diagnostics jsonb default '{}',
  p_notes jsonb default '[]',
  p_price_steps jsonb default '[]'
)
returns table(lead_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lead_id uuid;
  v_phone_digits text;
  v_step jsonb;
begin
  -- ── Server-side validation — the frontend already checks these, but a
  -- direct API call (curl, devtools, a malicious client) must not be able
  -- to bypass them. Never trust the frontend alone.
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Name is required';
  end if;

  v_phone_digits := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if length(v_phone_digits) <> 10 then
    raise exception 'A valid 10-digit phone number is required';
  end if;

  if p_email is not null and trim(p_email) <> '' and p_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Email address is not valid';
  end if;

  if coalesce(trim(p_dev_type), '') = '' or coalesce(trim(p_model), '') = '' then
    raise exception 'Brand and model are required';
  end if;

  if p_condition is not null and p_condition <> '' and p_condition not in ('Like New','Good','Fair','Poor') then
    raise exception 'Invalid condition value: %', p_condition;
  end if;

  if p_pincode is not null and trim(p_pincode) <> '' and p_pincode !~ '^[0-9]{6}$' then
    raise exception 'Pincode must be exactly 6 digits';
  end if;

  if p_ask_price < 0 or p_base_price < 0 then
    raise exception 'Price cannot be negative';
  end if;

  -- ── Insert the lead ────────────────────────────────────────────
  insert into leads (
    name, phone, email, area, address, pincode, dev_type, device, model, storage, ram, color, year, month,
    battery, imei, condition, screen_condition, body_condition, water_damage, repaired_parts, accessories,
    photos, bill_photo, ask_price, base_price, is_loyalty, customer_id, diagnostics, source, status, notes
  ) values (
    trim(p_name), v_phone_digits, nullif(trim(p_email), ''), p_area, p_address, nullif(trim(p_pincode), ''),
    p_dev_type, p_device, p_model, p_storage, p_ram, p_color, p_year, p_month,
    p_battery, p_imei, p_condition, p_screen_condition, p_body_condition, coalesce(p_water_damage, false),
    coalesce(p_repaired_parts, '{}'), coalesce(p_accessories, '{}'),
    coalesce(p_photos, '{}'), p_bill_photo, p_ask_price, p_base_price, coalesce(p_is_loyalty, false),
    p_customer_id, coalesce(p_diagnostics, '{}'), 'website', 'new', coalesce(p_notes, '[]')
  ) returning id into v_lead_id;

  -- ── Full price audit trail — one row per adjustment step ───────
  for v_step in select * from jsonb_array_elements(coalesce(p_price_steps, '[]'))
  loop
    insert into price_adjustments (
      lead_id, question_key, question_label, answer,
      base_price, adjustment_percentage, adjustment_amount, resulting_price
    ) values (
      v_lead_id,
      v_step->>'question_key',
      v_step->>'question_label',
      v_step->>'answer',
      (v_step->>'base_price')::numeric,
      (v_step->>'adjustment_percentage')::numeric,
      (v_step->>'adjustment_amount')::numeric,
      (v_step->>'resulting_price')::numeric
    );
  end loop;

  return query select v_lead_id;
end;
$$;
grant execute on function submit_sell_lead(
  text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text,
  text, text, boolean, text[], text[], text[], text, numeric, numeric, boolean, uuid, jsonb, jsonb, jsonb
) to anon, authenticated;

-- ── 6. Fix the est_price/ask_price mismatch in the notify trigger ──
-- notify_new_lead() (from supabase_real_schema_fix.sql) references
-- new.est_price, a column that doesn't exist anywhere in `leads` — only
-- ask_price does. As written today the ntfy/WhatsApp branches are both
-- skipped (placeholder credentials), so this has stayed silent, but the
-- `msg` string concatenation still runs new.est_price::text on every
-- insert and would start raising "record new has no field est_price" the
-- moment this trigger's guard conditions are ever satisfied. Recreating it
-- here with the correct column name — everything else is unchanged from
-- the original definition.
create or replace function notify_new_lead()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  msg text;
  ntfy_topic text := 'REPLACE-WITH-YOUR-NTFY-TOPIC';
  wa_phone   text := '';
  wa_apikey  text := '';
begin
  msg := 'New lead: ' || coalesce(new.name,'Unknown') || ' - ' || coalesce(new.device,'device not specified')
         || ' - ' || coalesce(new.phone,'') || ' - ' || coalesce(new.area,'') || ' - price: ' || coalesce(new.ask_price::text,'?');

  if ntfy_topic is not null and ntfy_topic <> '' and ntfy_topic <> 'REPLACE-WITH-YOUR-NTFY-TOPIC' then
    perform net.http_post(
      url := 'https://ntfy.sh/' || ntfy_topic,
      headers := jsonb_build_object('X-Title','New Lead - Sambhi Mobiles','X-Priority','4'),
      body := '{}'::jsonb,
      params := jsonb_build_object('message', msg),
      timeout_milliseconds := 5000
    );
  end if;

  if wa_phone <> '' and wa_apikey <> '' then
    perform net.http_get(
      url := 'https://api.callmebot.com/whatsapp.php',
      params := jsonb_build_object('phone', wa_phone, 'text', msg, 'apikey', wa_apikey),
      timeout_milliseconds := 5000
    );
  end if;

  return new;
end;
$$;
-- (trigger itself already exists from supabase_real_schema_fix.sql and
-- doesn't need recreating — it points at the function by name, and
-- `create or replace function` above updates its body in place.)
