-- ================================================================
-- SAMBHI MOBILES — RIDER AUTH, PAYOUTS, LEAD CALL-TRACKING, CONDITION PRICING
-- Run this ENTIRE script once in Supabase Dashboard -> SQL Editor -> New Query.
--
-- DEPENDS ON supabase_real_schema_fix.sql already having been run
-- (needs: pgcrypto extension, assert_is_owner(), team_users table).
-- Run that file first if you haven't already, then run this one.
--
-- Safe to re-run (idempotent).
-- ================================================================

create extension if not exists pgcrypto;

-- ── 1. RIDERS: real auth + configurable payout ───────────────────
-- NOTE: your riders table already has username/password_hash/is_active/
-- created_at (added by an earlier run of supabase_real_schema_fix.sql or
-- directly in the dashboard) — these ADD COLUMN IF NOT EXISTS lines are
-- safe no-ops where that's already true, and fill the gap otherwise.
alter table riders add column if not exists username text;
alter table riders add column if not exists password_hash text;
alter table riders add column if not exists is_active boolean default true;
alter table riders add column if not exists created_at timestamptz default now();
alter table riders add column if not exists payout_per_lead numeric not null default 300;

create unique index if not exists riders_phone_unique
  on riders (phone) where phone is not null and phone <> '';

-- Convert any plaintext values already sitting in password_hash into real
-- bcrypt hashes (safe to re-run — skips rows already hashed). Mirrors the
-- same migration line used for team_users.
update riders
set password_hash = crypt(password_hash, gen_salt('bf'))
where password_hash is not null and password_hash !~ '^\$2[aby]\$';

-- password_hash lives directly on `riders` (matching how team_users
-- already does it), but riders is still a row-readable table (see the
-- pre-existing "public_all" policy noted at the bottom of this file) —
-- so on its own, any site visitor's anon key could read every rider's
-- hash straight out of the REST API. This column-level revoke blocks
-- that specifically, regardless of the table's row-level policy state.
revoke select (password_hash) on riders from anon, authenticated;

-- Lock down payout_per_lead specifically (it's a money field) so it
-- can only change via the Owner-gated RPC below, regardless of the
-- table's existing row-level policy state.
revoke update (payout_per_lead) on riders from anon, authenticated;

create or replace function verify_rider_login(p_phone text, p_password text)
returns table(id uuid, name text, phone text, zone text, payout_per_lead numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select r.id, r.name, r.phone, r.zone, r.payout_per_lead
  from riders r
  where r.phone = p_phone
    and r.password_hash is not null
    and r.password_hash = extensions.crypt(p_password, r.password_hash)
    and r.is_active = true;
end;
$$;
grant execute on function verify_rider_login(text, text) to anon, authenticated;

create or replace function set_rider_password(p_caller_username text, p_caller_password text, p_rider_id uuid, p_new_password text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_is_owner(p_caller_username, p_caller_password);
  update riders set password_hash = extensions.crypt(p_new_password, extensions.gen_salt('bf')) where id = p_rider_id;
  return found;
end;
$$;
grant execute on function set_rider_password(text, text, uuid, text) to anon, authenticated;

create or replace function set_rider_payout(p_caller_username text, p_caller_password text, p_rider_id uuid, p_payout numeric)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_is_owner(p_caller_username, p_caller_password);
  if p_payout < 0 then
    raise exception 'Payout cannot be negative';
  end if;
  update riders set payout_per_lead = p_payout where id = p_rider_id;
  return found;
end;
$$;
grant execute on function set_rider_payout(text, text, uuid, numeric) to anon, authenticated;

-- ── 2. LEADS: call-status tracking + per-lead payout override ────
alter table leads add column if not exists month text;
alter table leads add column if not exists rider_called boolean not null default false;
alter table leads add column if not exists rider_called_at timestamptz;
alter table leads add column if not exists payout_override numeric;

-- Same column-level lockdown for the per-lead payout override — only
-- the Owner-gated RPC below may set it.
revoke update (payout_override) on leads from anon, authenticated;

create or replace function set_lead_payout_override(p_caller_username text, p_caller_password text, p_lead_id uuid, p_override numeric)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_is_owner(p_caller_username, p_caller_password);
  update leads set payout_override = p_override where id = p_lead_id;
  return found;
end;
$$;
grant execute on function set_lead_payout_override(text, text, uuid, numeric) to anon, authenticated;

-- KNOWN, DELIBERATE LIMITATION: leads.status remains directly writable
-- via the anon key (admin.html's existing status stepper depends on
-- this), so a rider using devtools could in theory PATCH their own
-- lead to status='completed' and inflate their own earnings count.
-- Closing this fully would need a mark_lead_completed() RPC and
-- revoking status from the anon grant — intentionally left out of
-- this pass to keep scope proportionate. Add it later if you want the
-- DB itself (not just the rider-portal UI) to enforce this.

-- ── 3. CONDITION PRICING (global % per condition) ────────────────
create table if not exists condition_pricing (
  condition  text primary key check (condition in ('Like New','Good','Fair','Poor')),
  multiplier numeric not null check (multiplier > 0 and multiplier <= 2),
  updated_at timestamptz default now()
);
insert into condition_pricing (condition, multiplier) values
  ('Like New', 1.00), ('Good', 0.88), ('Fair', 0.72), ('Poor', 0.52)
on conflict (condition) do nothing;

alter table condition_pricing enable row level security;
drop policy if exists "public_read_condition_pricing" on condition_pricing;
create policy "public_read_condition_pricing" on condition_pricing for select using (true);
grant select on condition_pricing to anon, authenticated;
-- No write policy — writes only via the RPC below.

create or replace function set_condition_pricing(p_caller_username text, p_caller_password text, p_condition text, p_multiplier numeric)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_is_owner(p_caller_username, p_caller_password);
  if p_condition not in ('Like New','Good','Fair','Poor') then
    raise exception 'Invalid condition: %', p_condition;
  end if;
  if p_multiplier <= 0 or p_multiplier > 2 then
    raise exception 'Multiplier out of allowed range (0-2)';
  end if;
  update condition_pricing set multiplier = p_multiplier, updated_at = now() where condition = p_condition;
  return found;
end;
$$;
grant execute on function set_condition_pricing(text, text, text, numeric) to anon, authenticated;

-- ================================================================
-- Done. After running this:
--
-- 1. Go to Admin -> Riders -> Add Rider, once for each of:
--      Akash Sambhi    9560174987
--      Yogesh Kumar    8700425753
--      Nikhilesh       8448836376
--    Set a payout (default 300) and a real password (>= 6 chars) for
--    each — passwords are deliberately NOT seeded here; the Owner sets
--    them from the admin UI, which exercises the real create/reset flow.
--
-- 2. Go to Admin -> Price List -> Condition Pricing % and confirm the
--    4 defaults (100/88/72/52) look right, adjust if needed.
--
-- 3. Test rider-portal.html login with one rider before relying on it.
--
-- NOTE — pre-existing, separate security gap (not fixed by this file):
-- `leads` and `riders` still carry a wide-open "public_all" policy
-- from the original supabase_setup.sql (for all using (true)), meaning
-- the public anon key can already read/write/delete any row in those
-- tables directly, independent of any admin login. This file closes the
-- specific things that matter most (rider password hashes, payout
-- amounts, per-lead payout overrides) via column-level revokes above;
-- a full RLS hardening pass for `leads`/`riders` (mirroring what was
-- already done for team_users) is a separate, larger piece of work
-- worth doing later.
-- ================================================================
