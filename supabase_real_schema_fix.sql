-- ================================================================
-- SAMBHI MOBILES — REAL SCHEMA FIX
-- Run this ENTIRE script once in Supabase Dashboard -> SQL Editor -> New Query
--
-- IMPORTANT: ignore/do NOT run these older files — they were written against
-- an assumed schema that turned out not to match your real database:
--   supabase_security_upgrade.sql
--   supabase_sell_form_upgrade.sql
-- This file replaces both, matched against your actual tables.
-- ================================================================

-- ── 1. URGENT — stop anyone from reading admin passwords ─────────
-- Your team_users table currently has NO row-level security, meaning
-- the public anon key (sitting in your live site's config.js) can read
-- every admin username and password. This closes that immediately.
alter table team_users enable row level security;
-- No policy is created for anon/authenticated — this means zero direct
-- access from the browser. All login checks go through the secure
-- function below instead, which never exposes the password itself.

create extension if not exists pgcrypto;

-- Convert existing plaintext passwords to real bcrypt hashes (safe to
-- re-run — it skips rows that are already hashed).
update team_users
set password_hash = crypt(password_hash, gen_salt('bf'))
where password_hash !~ '^\$2[aby]\$';

-- Secure login check — verifies the password server-side and returns
-- only the profile info (never the password/hash) on success.
create or replace function verify_admin_login(p_username text, p_password text)
returns table(id uuid, name text, role text, phone text, email text, color text, initials text)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select t.id, t.name, t.role, t.phone, t.email, t.color, t.initials
  from team_users t
  where t.username = p_username
    and t.password_hash = crypt(p_password, t.password_hash)
    and t.is_active = true;
end;
$$;

grant execute on function verify_admin_login(text, text) to anon, authenticated;

-- ── 2. Fix the actual live bug — new leads aren't saving ─────────
-- Your leads table blocks ALL inserts right now (even from the website's
-- own sell form), so every sell request submitted on your live site is
-- silently being lost. This adds the missing permission.
alter table leads enable row level security;
drop policy if exists "public_insert_leads" on leads;
create policy "public_insert_leads" on leads
  for insert
  with check (true);

-- ── 3. New lead detail fields used by the upgraded sell form ─────
alter table leads add column if not exists pincode text;
alter table leads add column if not exists condition text;
alter table leads add column if not exists ram text;
alter table leads add column if not exists accessories text[] default '{}';
alter table leads add column if not exists photos text[] default '{}';
alter table leads add column if not exists screen_condition text;
alter table leads add column if not exists body_condition text;
alter table leads add column if not exists water_damage boolean default false;
alter table leads add column if not exists repaired_parts text[] default '{}';
alter table leads add column if not exists frp_cleared boolean default false;
alter table leads add column if not exists bill_photo text;

-- ── 4. New rider fields for pincode auto-assignment + Aadhaar ────
alter table riders add column if not exists pincodes text[] default '{}';
alter table riders add column if not exists aadhaar_number text;
alter table riders add column if not exists aadhaar_image_path text;

-- Pincode -> rider matching for the website (doesn't expose rider phone/Aadhaar)
create or replace function match_rider_for_pincode(p text)
returns uuid
language sql
security definer
set search_path = public
as $$
  select id from riders
  where is_active = true and p = any(pincodes)
  order by created_at asc
  limit 1
$$;
grant execute on function match_rider_for_pincode(text) to anon, authenticated;

-- ── 4b. Inventory table (used by the Buy page + admin inventory tab) ──
-- This table didn't exist in your project at all yet — needed for the
-- CSV inventory import/export feature and the Buy page catalog.
create extension if not exists "uuid-ossp";
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
alter table inventory enable row level security;
drop policy if exists "public_read_inventory" on inventory;
create policy "public_read_inventory" on inventory for select using (true);
drop policy if exists "anyone_write_inventory" on inventory;
create policy "anyone_write_inventory" on inventory for all using (true) with check (true);

-- ── 5. Private photo storage (rider Aadhaar cards + device/bill photos) ──
insert into storage.buckets (id, name, public) values ('rider-docs', 'rider-docs', false) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('lead-photos', 'lead-photos', false) on conflict (id) do nothing;

-- Public can upload lead/device photos (customers submitting a sell request),
-- but not read them back. Rider docs: uploads only happen from the admin panel.
drop policy if exists "public_upload_lead_photos" on storage.objects;
create policy "public_upload_lead_photos" on storage.objects
  for insert
  with check (bucket_id = 'lead-photos');

drop policy if exists "anyone_upload_rider_docs" on storage.objects;
create policy "anyone_upload_rider_docs" on storage.objects
  for insert
  with check (bucket_id = 'rider-docs');

-- NOTE: because your admin login isn't (yet) real Supabase Auth, these photo
-- buckets can't be locked to "logged-in admins only" at the database level —
-- there's no auth.uid() to check against. For now, anyone with the direct
-- file path could view a photo, but paths are random/unguessable and never
-- listed publicly. If you want these truly locked to admin-only later, say
-- so — it requires setting up real Supabase Auth accounts for your team
-- (a bit more setup, previously described), which I'd be glad to do.

-- ── 6. NOTIFY ON NEW LEAD — phone push (ntfy.sh) + optional WhatsApp ──
-- THIS SECTION IS OPTIONAL — fill in the two placeholders below (see the
-- plain-English instructions you were given) then re-run just this part.
-- Safe to skip for now; nothing else depends on it.
create extension if not exists pg_net;

create or replace function notify_new_lead()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  msg text;
  ntfy_topic text := 'REPLACE-WITH-YOUR-NTFY-TOPIC';   -- e.g. sambhi-leads-8f3k2x (pick something hard to guess)
  wa_phone   text := '';                                -- e.g. 917827505579 (your own WhatsApp, country code, no +)
  wa_apikey  text := '';                                -- the API key CallMeBot texts you back
begin
  msg := 'New lead: ' || coalesce(new.name,'Unknown') || ' - ' || coalesce(new.device,'device not specified')
         || ' - ' || coalesce(new.phone,'') || ' - ' || coalesce(new.area,'') || ' - price: ' || coalesce(new.est_price::text,'?');

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

drop trigger if exists trg_notify_new_lead on leads;
create trigger trg_notify_new_lead
  after insert on leads
  for each row
  execute function notify_new_lead();

-- ================================================================
-- Done. After running this:
-- 1. Try submitting a test sell request on your live site — it should
--    now actually save (check Supabase Table Editor -> leads).
-- 2. Admin login now uses your existing team_users accounts (amrik,
--    manager1, exec1) with their existing passwords — the code has
--    already been updated to match.
-- 3. (Optional) fill in ntfy_topic / wa_phone / wa_apikey above and
--    re-run section 6 to turn on lead notifications.
-- ================================================================
