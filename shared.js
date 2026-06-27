/* ============================================================
   SAMBHI MOBILES — SHARED DATA & UTILITIES
   Include this in every page: <script src="shared.js"></script>
   ============================================================ */

// ── BRAND LOGOS (SVG inline) ─────────────────────────────────────
window.BRAND_LOGOS = {
  iphone:      `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#000"/><path d="M20 8c1.8 0 3.2.4 4.3 1.1-1 1-1.6 2.4-1.6 4 0 1.8.9 3.3 2.2 4.2-1 2.8-2.4 5.4-4.3 7.5C19 26.3 17.7 28 16 28c-.8 0-1.5-.2-2.2-.5-.7-.3-1.4-.5-2.2-.5s-1.5.2-2.1.5c-.7.3-1.3.5-2 .5C6 28 4 24.5 4 20.5 4 14.5 7.5 11 12 11c.9 0 1.7.2 2.5.5.7.3 1.3.5 1.8.5.4 0 1-.2 1.8-.5.9-.4 1.9-.5 2-.5zM20.3 6.5c-.8 1-2 1.7-3.3 1.6-.2-1.3.4-2.6 1.2-3.5.8-1 2.1-1.7 3.3-1.6.1 1.3-.4 2.6-1.2 3.5z" fill="#fff"/>`,
  samsung:     `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#1428A0"/><text x="20" y="26" text-anchor="middle" font-size="9" font-weight="700" fill="white" font-family="Arial">SAMSUNG</text></svg>`,
  oneplus:     `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#F5010C"/><text x="20" y="24" text-anchor="middle" font-size="18" font-weight="900" fill="white" font-family="Arial">1+</text></svg>`,
  realme:      `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#FFCE00"/><text x="20" y="25" text-anchor="middle" font-size="9" font-weight="800" fill="#000" font-family="Arial">realme</text></svg>`,
  oppo:        `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#1D8348"/><text x="20" y="25" text-anchor="middle" font-size="11" font-weight="700" fill="white" font-family="Arial">OPPO</text></svg>`,
  vivo:        `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#415FFF"/><text x="20" y="25" text-anchor="middle" font-size="11" font-weight="700" fill="white" font-family="Arial">vivo</text></svg>`,
  xiaomi:      `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#FF6900"/><text x="20" y="25" text-anchor="middle" font-size="9" font-weight="700" fill="white" font-family="Arial">Xiaomi</text></svg>`,
  pixel:       `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#4285F4"/><text x="20" y="26" text-anchor="middle" font-size="10" font-weight="700" fill="white" font-family="Arial">Pixel</text></svg>`,
  nothing:     `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#fff" stroke="#000" stroke-width="2"/><text x="20" y="25" text-anchor="middle" font-size="8" font-weight="700" fill="#000" font-family="Arial">Nothing</text></svg>`,
  airpods:     `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#F5F5F7"/><path d="M15 14c0-2.8 2.2-5 5-5s5 2.2 5 5v8c0 .6-.4 1-1 1h-1v3c0 1.1-.9 2-2 2h-2c-1.1 0-2-.9-2-2v-3h-1c-.6 0-1-.4-1-1v-8z" fill="#1d1d1f"/></svg>`,
  applewatch:  `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#1d1d1f"/><rect x="13" y="10" width="14" height="20" rx="4" fill="#fff"/><rect x="16" y="4" width="8" height="8" rx="2" fill="#555"/><rect x="16" y="28" width="8" height="8" rx="2" fill="#555"/></svg>`,
  playstation: `<svg viewBox="0 0 40 40" fill="none"><rect width="40" height="40" rx="10" fill="#003087"/><path d="M14 26V14l4 1.5V24l2-7 4 1.5-3 8H14z" fill="white"/><circle cx="28" cy="18" r="2" fill="#00439C" stroke="white" stroke-width="1"/></svg>`,
};

// ── MODELS & BASE PRICES ─────────────────────────────────────────
window.MODELS = {
  iphone:{
    'iPhone 16 Pro Max':115000,'iPhone 16 Pro':100000,'iPhone 16':80000,
    'iPhone 15 Pro Max':90000,'iPhone 15 Pro':78000,'iPhone 15':62000,
    'iPhone 14 Pro Max':70000,'iPhone 14 Pro':60000,'iPhone 14':50000,
    'iPhone 13 Pro Max':56000,'iPhone 13 Pro':48000,'iPhone 13':40000,
    'iPhone 12 Pro Max':35000,'iPhone 12':28000,'iPhone 11':20000,
    'iPhone SE (2022)':24000,'iPhone SE (2020)':14000,'iPhone XR':12000
  },
  samsung:{
    'Galaxy S24 Ultra':95000,'Galaxy S24+':80000,'Galaxy S24':65000,
    'Galaxy S23 Ultra':70000,'Galaxy S23':50000,'Galaxy S22':38000,
    'Galaxy A55':28000,'Galaxy A35':20000,'Galaxy A15':10000,
    'Galaxy M55':18000,'Galaxy M35':13000,'Galaxy F55':16000
  },
  oneplus:{
    'OnePlus 12':55000,'OnePlus 12R':35000,'OnePlus 11':45000,
    'Nord 4':28000,'Nord CE4':20000,'Nord 3':22000,
    'OnePlus 10 Pro':35000,'OnePlus 9 Pro':22000
  },
  realme:{
    'Realme GT 6':32000,'Realme GT 5':28000,'Realme 13 Pro+':25000,
    'Realme 13 Pro':20000,'Realme 12 Pro+':22000,'Realme 11 Pro+':18000,
    'Narzo 70 Pro':16000
  },
  oppo:{
    'Find X7 Pro':55000,'Reno 12 Pro':30000,'Reno 12':22000,
    'Reno 11 Pro':25000,'F27 Pro':20000,'F25 Pro':18000,'A60':10000
  },
  vivo:{
    'X100 Pro':65000,'X100':50000,'V40 Pro':35000,'V40':27000,
    'V30 Pro':30000,'V30':22000,'Y200 Pro':18000,'Y200':14000
  },
  xiaomi:{
    'Xiaomi 14 Ultra':75000,'Xiaomi 14':55000,'Redmi Note 13 Pro+':25000,
    'Redmi Note 13 Pro':20000,'Redmi Note 13':14000,
    'POCO X6 Pro':22000,'POCO F6':28000,'Redmi 13C':8000
  },
  pixel:{
    'Pixel 9 Pro XL':90000,'Pixel 9 Pro':75000,'Pixel 9':60000,
    'Pixel 8 Pro':55000,'Pixel 8':45000,'Pixel 7a':28000,'Pixel 7':32000
  },
  nothing:{
    'Phone (2a) Plus':25000,'Phone (2a)':22000,'Phone (2)':35000,'Phone (1)':18000
  },
  airpods:{
    'AirPods Pro 2nd Gen':18000,'AirPods Pro 1st Gen':11000,
    'AirPods Max':30000,'AirPods 3rd Gen':10000,'AirPods 2nd Gen':6000
  },
  applewatch:{
    'Apple Watch Ultra 2':58000,'Apple Watch Ultra':44000,
    'Apple Watch Series 9':32000,'Apple Watch Series 8':26000,
    'Apple Watch Series 7':20000,'Apple Watch SE 2nd Gen':16000
  },
  playstation:{
    'PS5 Disc Edition':44000,'PS5 Digital Edition':38000,
    'PS4 Pro':20000,'PS4 Slim':14000,'PS4':10000
  }
};

// ── DEPRECIATION RULES ───────────────────────────────────────────
window.DEP_DEFS = [
  {id:'charger', label:'No charger',       pct:0.05},
  {id:'screen',  label:'Screen cracked',   pct:0.18},
  {id:'body',    label:'Body damage',      pct:0.10},
  {id:'battlow', label:'Battery below 80%',pct:0.12},
  {id:'nobox',   label:'No original box',  pct:0.03},
  {id:'faceid',  label:'Face ID broken',   pct:0.10},
];

// ── PRICE MULTIPLIER (controlled from CRM) ───────────────────────
window.getPriceMultiplier = function() {
  return parseFloat(localStorage.getItem('smb_price_multiplier') || '1.0');
};
window.getAdjustedPrice = function(base) {
  return Math.round(base * window.getPriceMultiplier());
};

// ── ESTIMATE CALCULATOR ──────────────────────────────────────────
window.calcEstimate = function(basePrice, year, battery, deps) {
  if (!basePrice) return 0;
  const adjusted = window.getAdjustedPrice(basePrice);
  const yr = parseInt(year) || 0;
  const ageD = yr ? Math.round(adjusted * Math.min((2025 - yr) * 0.07, 0.42)) : 0;
  const b = parseInt(battery) || 100;
  const battD = b < 80 ? Math.round(adjusted * Math.min((80 - b) * 0.007, 0.20)) : 0;
  const condD = window.DEP_DEFS.reduce((s, d) => s + ((deps || {})[d.id] ? Math.round(adjusted * d.pct) : 0), 0);
  return Math.max(adjusted - ageD - battD - condD, Math.round(adjusted * 0.15));
};

// ── SHARED STORAGE ───────────────────────────────────────────────
window.getLeads  = () => JSON.parse(localStorage.getItem('smb_leads')  || '[]');
window.saveLeads = (l) => localStorage.setItem('smb_leads', JSON.stringify(l));
window.getBills  = () => JSON.parse(localStorage.getItem('smb_bills')  || '[]');
window.saveBills = (b) => localStorage.setItem('smb_bills', JSON.stringify(b));
window.getRiders = () => JSON.parse(localStorage.getItem('smb_riders') || '[]');
window.saveRiders= (r) => localStorage.setItem('smb_riders', JSON.stringify(r));
window.getCampaigns = () => JSON.parse(localStorage.getItem('smb_camps') || '{}');
window.getVideos = () => JSON.parse(localStorage.getItem('smb_videos') || '[]');

// ── UTILITIES ────────────────────────────────────────────────────
window.uid    = () => Date.now().toString(36) + Math.random().toString(36).slice(2);
window.Rs     = (n) => n ? '₹' + parseInt(n).toLocaleString('en-IN') : '—';
window.fmtD   = (d) => new Date(d).toLocaleDateString('en-IN', {day:'2-digit',month:'short',year:'numeric'});
window.fmtT   = (d) => new Date(d).toLocaleTimeString('en-IN', {hour:'2-digit',minute:'2-digit'});
window.fmtInv = (n) => 'SMB-2025-' + ('000' + n).slice(-4);
window.numWords = function(n) {
  const o=['','One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'];
  const t=['','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'];
  function b(n){if(n<20)return o[n];if(n<100)return t[~~(n/10)]+(n%10?' '+o[n%10]:'');return o[~~(n/100)]+' Hundred'+(n%100?' and '+b(n%100):'');}
  n=~~n;if(!n)return'Zero';if(n<1000)return b(n);
  if(n<100000)return b(~~(n/1000))+' Thousand'+(n%1000?' '+b(n%1000):'');
  if(n<10000000)return b(~~(n/100000))+' Lakh'+(n%100000?' '+window.numWords(n%100000):'');
  return b(~~(n/10000000))+' Crore'+(n%10000000?' '+window.numWords(n%10000000):'');
};

// ── SHARED NAV HTML ──────────────────────────────────────────────
window.NAV_HTML = `
<nav>
  <div class="nav-inner">
    <a href="index.html" class="nav-logo">
      <div class="nav-logo-icon">📱</div>
      <div class="nav-logo-text">Sambhi <span>Mobiles</span></div>
    </a>
    <div class="nav-links">
      <a href="index.html" class="nav-link">Home</a>
      <a href="sell.html" class="nav-link">Sell</a>
      <a href="buy.html" class="nav-link">Buy</a>
      <a href="about.html" class="nav-link">About</a>
      <a href="sell.html" class="nav-cta-btn">Sell Now →</a>
    </div>
    <button class="nav-hamburger" onclick="toggleMobileNav()">☰</button>
  </div>
  <div class="nav-mobile" id="navMobile">
    <a href="index.html">Home</a>
    <a href="sell.html">Sell My Phone</a>
    <a href="buy.html">Buy Devices</a>
    <a href="about.html">About Us</a>
  </div>
</nav>`;

window.NAV_CSS = `
nav{background:#fff;border-bottom:1px solid #E2E8F0;position:sticky;top:0;z-index:100;box-shadow:0 1px 4px rgba(0,0,0,0.06)}
.nav-inner{max-width:1200px;margin:0 auto;padding:0 24px;height:68px;display:flex;align-items:center;justify-content:space-between}
.nav-logo{display:flex;align-items:center;gap:10px;text-decoration:none}
.nav-logo-icon{width:38px;height:38px;background:linear-gradient(135deg,#2563EB,#F97316);border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:18px}
.nav-logo-text{font-family:'Plus Jakarta Sans',sans-serif;font-size:20px;font-weight:800;color:#0F172A}
.nav-logo-text span{color:#2563EB}
.nav-links{display:flex;gap:6px;align-items:center}
.nav-link{color:#64748B;text-decoration:none;font-size:14px;font-weight:500;padding:8px 14px;border-radius:8px;transition:all .2s}
.nav-link:hover{background:#F1F5F9;color:#0F172A}
.nav-cta-btn{background:#2563EB;color:#fff;padding:9px 20px;border-radius:10px;font-size:14px;font-weight:600;text-decoration:none;transition:all .2s}
.nav-cta-btn:hover{background:#1d4ed8}
.nav-hamburger{display:none;background:none;border:none;font-size:22px;cursor:pointer;padding:8px}
.nav-mobile{display:none;flex-direction:column;background:#fff;border-top:1px solid #E2E8F0;padding:12px 24px}
.nav-mobile a{padding:12px 0;color:#334155;text-decoration:none;font-size:15px;font-weight:500;border-bottom:1px solid #F1F5F9}
.nav-mobile.open{display:flex}
@media(max-width:768px){.nav-links{display:none}.nav-hamburger{display:block}}`;

window.toggleMobileNav = function() {
  document.getElementById('navMobile').classList.toggle('open');
};

// ── SHARED FOOTER HTML ───────────────────────────────────────────
window.FOOTER_HTML = `
<footer>
  <div class="footer-inner">
    <div class="footer-top">
      <div>
        <a href="index.html" class="footer-logo-wrap">
          <div class="footer-logo-icon">📱</div>
          <div class="footer-logo-text">Sambhi Mobiles</div>
        </a>
        <p class="footer-desc">Delhi's most trusted platform to sell any smartphone and buy certified premium gadgets. Free doorstep pickup, instant cash, GST bill provided.</p>
        <div class="footer-contact">
          <a href="tel:+917827505579">📞 +91 7827505579</a>
          <a href="#">📍 1498, Bhagat Niwas, 13, Govind Puri, New Delhi – 110019</a>
        </div>
      </div>
      <div class="footer-col">
        <h4>Sell</h4>
        <a href="sell.html">Sell iPhone</a>
        <a href="sell.html">Sell Samsung</a>
        <a href="sell.html">Sell OnePlus</a>
        <a href="sell.html">Any phone</a>
      </div>
      <div class="footer-col">
        <h4>Buy</h4>
        <a href="buy.html">iPhones</a>
        <a href="buy.html">AirPods</a>
        <a href="buy.html">Apple Watch</a>
        <a href="buy.html">PlayStation</a>
      </div>
      <div class="footer-col">
        <h4>Company</h4>
        <a href="about.html">About Us</a>
        <a href="about.html#contact">Contact</a>
        <a href="admin.html">Team Login</a>
      </div>
    </div>
    <div class="footer-bottom">
      <p>© 2025 Sambhi Mobiles · GSTIN: 07BWPPS6835M1ZI · PAN: BWPPS6835M · Prop: Amrik Singh · Delhi NCR only</p>
      <div class="footer-bank">🏦 IDFC First Bank · Acc: 10084177443 · IFSC: IDFB0020107 · Okhla Branch</div>
    </div>
  </div>
</footer>`;

window.FOOTER_CSS = `
footer{background:#0F172A;padding:56px 24px 28px}
.footer-inner{max-width:1200px;margin:0 auto}
.footer-top{display:grid;grid-template-columns:2fr 1fr 1fr 1fr;gap:48px;margin-bottom:40px}
.footer-logo-wrap{display:flex;align-items:center;gap:10px;margin-bottom:14px;text-decoration:none}
.footer-logo-icon{width:36px;height:36px;background:linear-gradient(135deg,#2563EB,#F97316);border-radius:9px;display:flex;align-items:center;justify-content:center;font-size:16px}
.footer-logo-text{font-family:'Plus Jakarta Sans',sans-serif;font-size:18px;font-weight:800;color:#fff}
.footer-desc{font-size:13px;color:rgba(255,255,255,.4);line-height:1.75;margin-bottom:16px}
.footer-contact{display:flex;flex-direction:column;gap:8px}
.footer-contact a{font-size:13px;color:rgba(255,255,255,.45);text-decoration:none}
.footer-contact a:hover{color:#fff}
.footer-col h4{font-size:12px;font-weight:700;color:#fff;margin-bottom:14px;text-transform:uppercase;letter-spacing:.5px}
.footer-col a{display:block;font-size:13px;color:rgba(255,255,255,.4);text-decoration:none;margin-bottom:9px;transition:color .2s}
.footer-col a:hover{color:#fff}
.footer-bottom{border-top:1px solid rgba(255,255,255,.08);padding-top:22px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px}
.footer-bottom p{font-size:12px;color:rgba(255,255,255,.25)}
.footer-bank{font-size:11px;color:rgba(255,255,255,.25)}
@media(max-width:768px){.footer-top{grid-template-columns:1fr 1fr}}
@media(max-width:480px){.footer-top{grid-template-columns:1fr}}`;

console.log('Sambhi Mobiles shared.js loaded');
