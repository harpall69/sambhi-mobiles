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
alter table riders add column if not exists username text;
alter table riders add column if not exists is_active boolean default true;
alter table riders add column if not exists created_at timestamptz default now();
alter table riders add column if not exists payout_per_lead numeric not null default 300;

create unique index if not exists riders_phone_unique
  on riders (phone) where phone is not null and phone <> '';

-- Password hashes live in a SEPARATE table with RLS enabled and NO
-- policies at all — the anon/authenticated REST API cannot read or
-- write this table under any circumstance, regardless of whatever
-- row-level policy exists on `riders` itself. Only the SECURITY
-- DEFINER functions below (which run as table owner, bypassing RLS)
-- can touch it — same principle already used for team_users.
create table if not exists rider_auth (
  rider_id      uuid primary key references riders(id) on delete cascade,
  password_hash text not null,
  updated_at    timestamptz default now()
);
alter table rider_auth enable row level security;

-- Lock down payout_per_lead specifically (it's a money field) so it
-- can only change via the Owner-gated RPC below, regardless of the
-- table's existing row-level policy state (riders currently still
-- has a wide-open legacy "public_all" policy from the original setup
-- script — this column-level revoke closes the payout bypass without
-- touching that broader, separate, pre-existing issue).
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
  join rider_auth a on a.rider_id = r.id
  where r.phone = p_phone
    and a.password_hash = extensions.crypt(p_password, a.password_hash)
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
  insert into rider_auth (rider_id, password_hash, updated_at)
  values (p_rider_id, extensions.crypt(p_new_password, extensions.gen_salt('bf')), now())
  on conflict (rider_id) do update set password_hash = excluded.password_hash, updated_at = now();
  return true;
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
-- tables directly, independent of any admin login. This file only
-- closes the two money-specific columns above; a full RLS hardening
-- pass for `leads`/`riders` (mirroring what was already done for
-- team_users) is a separate, larger piece of work worth doing later.
-- ================================================================
