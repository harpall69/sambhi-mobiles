-- ================================================================
-- SAMBHI MOBILES — SECURITY + FEATURE UPGRADE
-- Run this ENTIRE script once in Supabase Dashboard -> SQL Editor -> New Query
-- Safe to run even if some parts already exist (uses "if not exists" everywhere)
-- ================================================================

-- ── 1. ADMIN USERS (owner / manager accounts) ────────────────────
-- This links to Supabase's real login system (auth.users) instead of
-- the old plaintext-in-the-webpage login.
create table if not exists admin_users (
  id         uuid primary key references auth.users(id) on delete cascade,
  name       text not null,
  role       text not null check (role in ('Owner','Manager')),
  phone      text,
  email      text,
  created_at timestamptz default now()
);

alter table admin_users enable row level security;

drop policy if exists "self_read" on admin_users;
create policy "self_read" on admin_users
  for select using (auth.uid() = id);
-- No public insert/update/delete policy at all — rows are added manually
-- by you (or by me giving you the exact SQL) in the SQL Editor, using your
-- own Supabase login, which always bypasses RLS. This is intentional:
-- nobody should be able to grant themselves admin access.

-- ── 2. RIDERS — add pincode coverage + Aadhaar fields ────────────
alter table riders add column if not exists pincodes text[] default '{}';
alter table riders add column if not exists aadhaar_number text;
alter table riders add column if not exists aadhaar_image_path text;
alter table riders add column if not exists created_at timestamptz default now();

-- Lock riders down to admin-only. Remove the old wide-open policy first.
drop policy if exists "public_all" on riders;
alter table riders enable row level security;

drop policy if exists "admin_all_riders" on riders;
create policy "admin_all_riders" on riders
  for all
  using (exists (select 1 from admin_users where id = auth.uid()))
  with check (exists (select 1 from admin_users where id = auth.uid()));

-- ── 3. LEADS — public can create, only admins can read/manage ────
alter table leads add column if not exists pincode text;

drop policy if exists "public_all" on leads;
alter table leads enable row level security;

drop policy if exists "public_insert_leads" on leads;
create policy "public_insert_leads" on leads
  for insert
  with check (true);
-- Anyone (including anonymous website visitors) can CREATE a lead —
-- this is required for the "sell your phone" form to keep working.

drop policy if exists "admin_manage_leads" on leads;
create policy "admin_manage_leads" on leads
  for select
  using (exists (select 1 from admin_users where id = auth.uid()));

drop policy if exists "admin_update_leads" on leads;
create policy "admin_update_leads" on leads
  for update
  using (exists (select 1 from admin_users where id = auth.uid()))
  with check (exists (select 1 from admin_users where id = auth.uid()));

drop policy if exists "admin_delete_leads" on leads;
create policy "admin_delete_leads" on leads
  for delete
  using (exists (select 1 from admin_users where id = auth.uid()));

-- ── 4. Pincode -> rider matching, without exposing rider PII ─────
-- This lets the public website figure out which rider covers a pincode
-- WITHOUT being able to read rider phone numbers / Aadhaar data directly
-- (riders table itself stays admin-only per section 2 above).
create or replace function match_rider_for_pincode(p text)
returns uuid
language sql
security definer
set search_path = public
as $$
  select id from riders
  where active = true and p = any(pincodes)
  order by created_at asc
  limit 1
$$;

grant execute on function match_rider_for_pincode(text) to anon, authenticated;

-- ── 5. Secure file storage for rider Aadhaar card images ─────────
insert into storage.buckets (id, name, public)
values ('rider-docs', 'rider-docs', false)
on conflict (id) do nothing;

drop policy if exists "admin_read_rider_docs" on storage.objects;
create policy "admin_read_rider_docs" on storage.objects
  for select
  using (bucket_id = 'rider-docs' and exists (select 1 from admin_users where id = auth.uid()));

drop policy if exists "admin_write_rider_docs" on storage.objects;
create policy "admin_write_rider_docs" on storage.objects
  for insert
  with check (bucket_id = 'rider-docs' and exists (select 1 from admin_users where id = auth.uid()));

drop policy if exists "admin_update_rider_docs" on storage.objects;
create policy "admin_update_rider_docs" on storage.objects
  for update
  using (bucket_id = 'rider-docs' and exists (select 1 from admin_users where id = auth.uid()));

drop policy if exists "admin_delete_rider_docs" on storage.objects;
create policy "admin_delete_rider_docs" on storage.objects
  for delete
  using (bucket_id = 'rider-docs' and exists (select 1 from admin_users where id = auth.uid()));

-- ================================================================
-- 6. NOTIFY ON NEW LEAD — sends a phone notification (ntfy.sh) and,
--    optionally, a WhatsApp message (CallMeBot) the moment a new lead
--    is created — no server or app code needed, it all runs inside
--    the database itself.
--
--    THIS SECTION IS OPTIONAL / SKIP FOR NOW — it needs 2 values only
--    you can get (see the plain-English instructions given alongside
--    this file). Fill in the placeholders below, then run just this
--    section (or the whole file again, it's safe to re-run).
-- ================================================================
create extension if not exists pg_net;

create or replace function notify_new_lead()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  msg text;
  ntfy_topic text := 'REPLACE-WITH-YOUR-NTFY-TOPIC';        -- e.g. sambhi-leads-8f3k2x (pick something hard to guess)
  wa_phone   text := '';                                     -- e.g. 917827505579 (your own WhatsApp, country code, no +)
  wa_apikey  text := '';                                     -- the API key CallMeBot texts you back (see instructions)
begin
  msg := 'New lead: ' || coalesce(new.name,'Unknown') || ' - ' || coalesce(new.device,'device not specified')
         || ' - ' || coalesce(new.phone,'') || ' - ' || coalesce(new.area,'');

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
-- Done. Next steps (see instructions given alongside this file):
-- 1. Create 2 login users in Authentication -> Users (owner + manager).
-- 2. Copy each user's UID and run the INSERT INTO admin_users
--    statements you were given, to grant them the Owner / Manager role.
-- 3. (Optional) Fill in ntfy_topic / wa_phone / wa_apikey above and
--    re-run this section to turn on lead notifications.
-- ================================================================
