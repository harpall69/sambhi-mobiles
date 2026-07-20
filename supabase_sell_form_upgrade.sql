-- ================================================================
-- SAMBHI MOBILES — SELL FORM UPGRADE (run after supabase_security_upgrade.sql)
-- Run this ENTIRE script once in Supabase Dashboard -> SQL Editor -> New Query
-- Safe to run even if some parts already exist
-- ================================================================

-- ── New lead detail fields ────────────────────────────────────────
alter table leads add column if not exists screen_condition text;
alter table leads add column if not exists body_condition text;
alter table leads add column if not exists water_damage boolean default false;
alter table leads add column if not exists repaired_parts text[] default '{}';
alter table leads add column if not exists frp_cleared boolean default false;
alter table leads add column if not exists bill_photo text;
-- "photos" (device photos, text[] of storage paths) already exists in the original schema.

-- ── Storage for lead/device photos + bill photos ─────────────────
-- Public can upload (customers submitting a sell request) but NOT read —
-- only logged-in Owner/Manager accounts can view these photos.
insert into storage.buckets (id, name, public)
values ('lead-photos', 'lead-photos', false)
on conflict (id) do nothing;

drop policy if exists "public_upload_lead_photos" on storage.objects;
create policy "public_upload_lead_photos" on storage.objects
  for insert
  with check (bucket_id = 'lead-photos');

drop policy if exists "admin_read_lead_photos" on storage.objects;
create policy "admin_read_lead_photos" on storage.objects
  for select
  using (bucket_id = 'lead-photos' and exists (select 1 from admin_users where id = auth.uid()));

-- ================================================================
-- Done. No further manual steps needed for this part.
-- ================================================================
