-- ================================================================
-- SAMBHI MOBILES — COMPLETE DATABASE + ANALYTICS SCHEMA
-- Run this in: supabase.com → Your Project → SQL Editor → New Query
-- ================================================================

-- ── ENABLE UUID EXTENSION ───────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- TABLE 1: LEADS (all sell requests from website + CRM)
-- ================================================================
CREATE TABLE IF NOT EXISTS leads (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name          TEXT NOT NULL,
  phone         TEXT NOT NULL,
  area          TEXT,
  address       TEXT,
  dev_type      TEXT,          -- iphone, samsung, oneplus etc
  device        TEXT,          -- full device string
  model         TEXT,
  storage       TEXT,
  color         TEXT,
  year          TEXT,
  battery       TEXT,
  imei          TEXT,
  base_price    INTEGER DEFAULT 0,
  est_price     INTEGER DEFAULT 0,
  final_price   INTEGER DEFAULT 0,
  deps          JSONB DEFAULT '{}',   -- condition deductions
  is_loyalty    BOOLEAN DEFAULT false,
  slot          TEXT DEFAULT 'morning', -- morning or evening
  source        TEXT DEFAULT 'website', -- website, whatsapp, meta, walkin, call
  status        TEXT DEFAULT 'new',     -- new, contacted, scheduled, completed, cancelled
  rider_id      UUID,
  assigned_by   TEXT,
  notes         JSONB DEFAULT '[]',
  is_billed     BOOLEAN DEFAULT false,
  inv_no        TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 2: BILLS (GST invoices generated)
-- ================================================================
CREATE TABLE IF NOT EXISTS bills (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  inv_no        TEXT UNIQUE NOT NULL,  -- SMB-2025-0001
  lead_id       UUID REFERENCES leads(id) ON DELETE SET NULL,
  customer_name TEXT NOT NULL,
  customer_phone TEXT,
  device        TEXT,
  imei          TEXT,
  tx_type       TEXT DEFAULT 'PURCHASE', -- PURCHASE or SALE
  taxable_value NUMERIC(10,2),
  cgst          NUMERIC(10,2),
  sgst          NUMERIC(10,2),
  grand_total   NUMERIC(10,2) NOT NULL,
  hsn_code      TEXT DEFAULT '8517',
  created_by    TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 3: RIDERS (pickup executives)
-- ================================================================
CREATE TABLE IF NOT EXISTS riders (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name          TEXT NOT NULL,
  phone         TEXT NOT NULL,
  email         TEXT,
  id_proof      TEXT,           -- Aadhaar / DL number
  username      TEXT UNIQUE,
  password_hash TEXT,           -- store hashed in production
  zone          TEXT,           -- area they cover
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 4: TEAM USERS (CRM login accounts)
-- ================================================================
CREATE TABLE IF NOT EXISTS team_users (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  username      TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  name          TEXT NOT NULL,
  role          TEXT DEFAULT 'Executive', -- Owner, Manager, Executive
  phone         TEXT,
  email         TEXT,
  color         TEXT DEFAULT '#2563EB',
  initials      TEXT,
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 5: CAMPAIGNS (limited-time offers)
-- ================================================================
CREATE TABLE IF NOT EXISTS campaigns (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title         TEXT NOT NULL,
  description   TEXT,
  wa_message    TEXT,
  is_active     BOOLEAN DEFAULT false,
  created_by    TEXT,
  activated_at  TIMESTAMPTZ,
  deactivated_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 6: CUSTOMER VIDEOS (testimonials shown on website)
-- ================================================================
CREATE TABLE IF NOT EXISTS customer_videos (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  yt_id         TEXT,           -- YouTube video ID
  customer_name TEXT NOT NULL,
  area          TEXT,
  rating        INTEGER DEFAULT 5 CHECK (rating BETWEEN 1 AND 5),
  comment       TEXT,
  is_visible    BOOLEAN DEFAULT true,
  added_by      TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 7: WEBSITE ANALYTICS — PAGE VIEWS
-- ================================================================
CREATE TABLE IF NOT EXISTS analytics_pageviews (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  page          TEXT NOT NULL,        -- /, /sell, /buy, /about
  page_label    TEXT,                 -- Home, Sell, Buy, About
  session_id    TEXT,                 -- anonymous session ID
  referrer      TEXT,                 -- where they came from
  device_type   TEXT,                 -- mobile, desktop, tablet
  user_agent    TEXT,
  city          TEXT,                 -- from IP (if available)
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 8: WEBSITE ANALYTICS — BRAND CLICKS
-- ================================================================
CREATE TABLE IF NOT EXISTS analytics_brand_clicks (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  brand         TEXT NOT NULL,        -- iphone, samsung, oneplus etc
  page          TEXT DEFAULT '/sell', -- which page the click happened
  session_id    TEXT,
  device_type   TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 9: WEBSITE ANALYTICS — SELL FORM EVENTS
-- ================================================================
CREATE TABLE IF NOT EXISTS analytics_form_events (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  event_type    TEXT NOT NULL,  -- form_start, brand_select, model_select, price_shown, slot_select, submitted
  brand         TEXT,
  model         TEXT,
  slot          TEXT,
  est_price     INTEGER,
  is_loyalty    BOOLEAN DEFAULT false,
  session_id    TEXT,
  device_type   TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 10: WEBSITE ANALYTICS — BUY PAGE CLICKS
-- ================================================================
CREATE TABLE IF NOT EXISTS analytics_buy_clicks (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  product_id    TEXT NOT NULL,   -- ps5d, ip14pm etc
  product_name  TEXT,
  product_cat   TEXT,            -- iphone, playstation, airpods, applewatch
  action        TEXT DEFAULT 'enquire', -- enquire, whatsapp
  session_id    TEXT,
  device_type   TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 11: IMEI CHECKS (track how many people check IMEI)
-- ================================================================
CREATE TABLE IF NOT EXISTS analytics_imei_checks (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  result        TEXT,            -- clean, stolen, unknown
  session_id    TEXT,
  page          TEXT DEFAULT '/sell',
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 12: PRICE MULTIPLIER LOG
-- ================================================================
CREATE TABLE IF NOT EXISTS price_changes (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  old_multiplier NUMERIC(4,2),
  new_multiplier NUMERIC(4,2),
  changed_by    TEXT,
  note          TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- SEED DATA: Default team users
-- ================================================================
INSERT INTO team_users (username, password_hash, name, role, color, initials) VALUES
  ('amrik',    'amrik1234',    'Amrik Singh', 'Owner',     '#F97316', 'AS'),
  ('manager1', 'manager1234',  'Manager 1',   'Manager',   '#2563EB', 'M1'),
  ('exec1',    'exec1234',     'Executive 1', 'Executive', '#16A34A', 'E1')
ON CONFLICT (username) DO NOTHING;

-- ================================================================
-- SEED DATA: Default campaigns
-- ================================================================
INSERT INTO campaigns (title, description, wa_message, is_active) VALUES
  ('No deduction — charger missing', 'Waive the 5% charger deduction', '🔥 Special offer: Missing charger? No problem! Zero deduction on charger. Limited time! Call +91 7827505579', false),
  ('No deduction — low battery health', 'Waive battery deduction for devices below 80%', '🔥 Battery below 80%? No deduction this week! Sell at full price. Call +91 7827505579', false),
  ('Double loyalty — 20% bonus', 'Returning customers get 20% instead of 10%', '🏆 DOUBLE LOYALTY this week! Returning customers get 20% extra. Call +91 7827505579', false),
  ('Express pickup — within 30 min', 'Promise 30-minute pickup', '⚡ 30-MINUTE PICKUP today! Submit now and we arrive in 30 minutes. Call +91 7827505579', false),
  ('Zero deductions — all accessories', 'No deductions for missing accessories', '🎁 ZERO deductions! Sell at BASE price regardless of condition. Today only! Call +91 7827505579', false),
  ('No screen deduction', 'Waive screen crack deduction', '🔥 Cracked screen? No problem! Zero deduction today. Call +91 7827505579', false)
ON CONFLICT DO NOTHING;

-- ================================================================
-- VIEWS: ANALYTICS DASHBOARD QUERIES
-- (Run these in SQL Editor to see your analytics)
-- ================================================================

-- View 1: Daily page views for last 30 days
CREATE OR REPLACE VIEW v_daily_pageviews AS
SELECT
  DATE(created_at) as date,
  page_label,
  COUNT(*) as views,
  COUNT(DISTINCT session_id) as unique_visitors
FROM analytics_pageviews
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at), page_label
ORDER BY date DESC, views DESC;

-- View 2: Brand interest (which brands people click most)
CREATE OR REPLACE VIEW v_brand_interest AS
SELECT
  brand,
  COUNT(*) as total_clicks,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage,
  COUNT(CASE WHEN device_type='mobile' THEN 1 END) as mobile_clicks,
  COUNT(CASE WHEN device_type='desktop' THEN 1 END) as desktop_clicks
FROM analytics_brand_clicks
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY brand
ORDER BY total_clicks DESC;

-- View 3: Sell funnel (how many start vs complete form)
CREATE OR REPLACE VIEW v_sell_funnel AS
SELECT
  event_type,
  COUNT(*) as count,
  COUNT(DISTINCT session_id) as unique_users
FROM analytics_form_events
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY event_type
ORDER BY count DESC;

-- View 4: Lead conversion rate by source
CREATE OR REPLACE VIEW v_lead_conversion AS
SELECT
  source,
  COUNT(*) as total_leads,
  COUNT(CASE WHEN status='completed' THEN 1 END) as completed,
  COUNT(CASE WHEN status='cancelled' THEN 1 END) as cancelled,
  ROUND(COUNT(CASE WHEN status='completed' THEN 1 END) * 100.0 / NULLIF(COUNT(*),0), 1) as conversion_rate_pct,
  SUM(final_price) as total_revenue
FROM leads
GROUP BY source
ORDER BY total_leads DESC;

-- View 5: Revenue by month
CREATE OR REPLACE VIEW v_monthly_revenue AS
SELECT
  TO_CHAR(created_at, 'YYYY-MM') as month,
  COUNT(*) as total_bills,
  SUM(grand_total) as total_revenue,
  AVG(grand_total) as avg_bill_value,
  MAX(grand_total) as highest_bill
FROM bills
GROUP BY TO_CHAR(created_at, 'YYYY-MM')
ORDER BY month DESC;

-- View 6: Device category breakdown
CREATE OR REPLACE VIEW v_device_breakdown AS
SELECT
  dev_type,
  COUNT(*) as total_leads,
  COUNT(CASE WHEN status='completed' THEN 1 END) as completed,
  ROUND(AVG(est_price)) as avg_est_price,
  ROUND(AVG(final_price)) as avg_final_price
FROM leads
WHERE dev_type IS NOT NULL
GROUP BY dev_type
ORDER BY total_leads DESC;

-- View 7: Rider performance
CREATE OR REPLACE VIEW v_rider_performance AS
SELECT
  r.name as rider_name,
  r.phone,
  r.zone,
  COUNT(l.id) as total_assigned,
  COUNT(CASE WHEN l.status='completed' THEN 1 END) as completed,
  COUNT(CASE WHEN l.status='cancelled' THEN 1 END) as cancelled,
  ROUND(COUNT(CASE WHEN l.status='completed' THEN 1 END) * 100.0 / NULLIF(COUNT(l.id),0), 1) as success_rate_pct
FROM riders r
LEFT JOIN leads l ON l.rider_id = r.id
GROUP BY r.id, r.name, r.phone, r.zone
ORDER BY completed DESC;

-- View 8: Peak hours analysis
CREATE OR REPLACE VIEW v_peak_hours AS
SELECT
  EXTRACT(HOUR FROM created_at) as hour_of_day,
  COUNT(*) as page_views,
  COUNT(DISTINCT session_id) as unique_visitors
FROM analytics_pageviews
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY EXTRACT(HOUR FROM created_at)
ORDER BY page_views DESC;

-- View 9: Mobile vs Desktop split
CREATE OR REPLACE VIEW v_device_split AS
SELECT
  device_type,
  COUNT(*) as visits,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
FROM analytics_pageviews
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY device_type
ORDER BY visits DESC;

-- View 10: Today's dashboard summary
CREATE OR REPLACE VIEW v_today_summary AS
SELECT
  (SELECT COUNT(*) FROM leads WHERE DATE(created_at) = CURRENT_DATE) as leads_today,
  (SELECT COUNT(*) FROM leads WHERE status='new') as leads_new,
  (SELECT COUNT(*) FROM leads WHERE status='scheduled') as leads_scheduled,
  (SELECT COUNT(*) FROM leads WHERE status='completed' AND DATE(created_at) >= DATE_TRUNC('month', CURRENT_DATE)) as completed_this_month,
  (SELECT COALESCE(SUM(grand_total),0) FROM bills WHERE DATE(created_at) >= DATE_TRUNC('month', CURRENT_DATE)) as revenue_this_month,
  (SELECT COUNT(DISTINCT session_id) FROM analytics_pageviews WHERE DATE(created_at) = CURRENT_DATE) as visitors_today,
  (SELECT COUNT(*) FROM analytics_pageviews WHERE DATE(created_at) = CURRENT_DATE) as pageviews_today;

-- ================================================================
-- ROW LEVEL SECURITY (RLS) — protects data
-- ================================================================
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_pageviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_brand_clicks ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_form_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_buy_clicks ENABLE ROW LEVEL SECURITY;

-- Allow public inserts (website can log analytics + leads)
CREATE POLICY "public_insert_leads" ON leads FOR INSERT WITH CHECK (true);
CREATE POLICY "public_insert_pageviews" ON analytics_pageviews FOR INSERT WITH CHECK (true);
CREATE POLICY "public_insert_brand_clicks" ON analytics_brand_clicks FOR INSERT WITH CHECK (true);
CREATE POLICY "public_insert_form_events" ON analytics_form_events FOR INSERT WITH CHECK (true);
CREATE POLICY "public_insert_buy_clicks" ON analytics_buy_clicks FOR INSERT WITH CHECK (true);
CREATE POLICY "public_insert_imei_checks" ON analytics_imei_checks FOR INSERT WITH CHECK (true);

-- Authenticated users (your CRM team) can read everything
CREATE POLICY "auth_read_leads" ON leads FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "auth_update_leads" ON leads FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "auth_read_bills" ON bills FOR SELECT USING (auth.role() = 'authenticated');

-- ================================================================
-- USEFUL ANALYTICS QUERIES TO RUN ANY TIME
-- ================================================================
-- Copy any of these and paste into SQL Editor → Run

-- 1. See today's summary:
-- SELECT * FROM v_today_summary;

-- 2. Which phone brands are most popular on your website:
-- SELECT * FROM v_brand_interest;

-- 3. How many people start vs finish the sell form:
-- SELECT * FROM v_sell_funnel;

-- 4. Revenue by month:
-- SELECT * FROM v_monthly_revenue;

-- 5. Best performing lead source (website vs WhatsApp vs Meta):
-- SELECT * FROM v_lead_conversion;

-- 6. Which devices you buy most:
-- SELECT * FROM v_device_breakdown;

-- 7. Website visitors today vs yesterday:
-- SELECT DATE(created_at) as date, COUNT(DISTINCT session_id) as visitors, COUNT(*) as pageviews
-- FROM analytics_pageviews WHERE created_at >= NOW() - INTERVAL '7 days'
-- GROUP BY DATE(created_at) ORDER BY date DESC;

-- 8. Peak traffic hours:
-- SELECT * FROM v_peak_hours LIMIT 5;

-- 9. Mobile vs Desktop visitors:
-- SELECT * FROM v_device_split;

-- 10. All leads this week:
-- SELECT name, phone, device, status, est_price, slot, source, created_at
-- FROM leads WHERE created_at >= NOW() - INTERVAL '7 days' ORDER BY created_at DESC;

