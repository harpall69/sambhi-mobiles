// ================================================================
// SAMBHI MOBILES — SHARED.JS v3
// Central data layer, auth, and utilities
// All pages load this file first
// ================================================================
'use strict';

var SMB = (function() {

  // ── STORAGE KEYS ───────────────────────────────────────────────
  var K = {
    customers:    'smb_customers',
    cust_sess:    'smb_cust_sess',
    sell_reqs:    'smb_sell_reqs',
    inv:          'smb_inv',
    leads:        'smb_leads',
    bills:        'smb_bills',
    riders:       'smb_riders',
    camps:        'smb_camps',
    active_camp:  'smb_active_camp',
    team:         'smb_team',
    mult:         'smb_mult',
    admin_sess:   'smb_sess',
    notifs:       'smb_notifs',
    invn:         'smb_invn',
    videos:       'smb_videos'
  };

  // ── SAFE STORAGE ───────────────────────────────────────────────
  function get(key) {
    try { var v = localStorage.getItem(key); return v ? JSON.parse(v) : null; }
    catch(e) { return null; }
  }
  function set(key, val) {
    try { localStorage.setItem(key, JSON.stringify(val)); return true; }
    catch(e) { return false; }
  }
  function arr(key) {
    var v = get(key); return Array.isArray(v) ? v : [];
  }

  // ── HASH (djb2 — no plain text passwords stored) ──────────────
  function hash(str) {
    var h = 5381;
    for (var i = 0; i < str.length; i++) {
      h = ((h << 5) + h) + str.charCodeAt(i);
      h = h & h;
    }
    return 'smb_' + Math.abs(h).toString(16) + '_' + str.length;
  }

  // ── UTILITIES ──────────────────────────────────────────────────
  function uid() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 7); }
  function now() { return new Date().toISOString(); }
  function Rs(n) { return n ? '₹' + parseInt(n).toLocaleString('en-IN') : '—'; }
  function fmtDate(d) {
    return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  // ── CUSTOMER AUTH ──────────────────────────────────────────────
  var SESSION_TTL = 12 * 60 * 60 * 1000; // 12 hours

  var customer = {
    all: function() { return arr(K.customers); },
    save: function(list) { set(K.customers, list); },

    byPhone: function(phone) {
      var clean = (phone + '').replace(/\D/g, '').slice(-10);
      return customer.all().find(function(c) {
        return c.phone === clean || (c.altPhone && c.altPhone === clean);
      }) || null;
    },

    register: function(name, phone, altPhone, password) {
      phone = (phone + '').replace(/\D/g, '').slice(-10);
      altPhone = altPhone ? (altPhone + '').replace(/\D/g, '').slice(-10) : '';
      if (customer.byPhone(phone)) return { ok: false, err: 'Phone number already registered. Please login.' };
      if (password.length < 6) return { ok: false, err: 'Password must be at least 6 characters.' };
      var c = {
        id: uid(), name: name.trim(), phone: phone, altPhone: altPhone,
        pwHash: hash(password), createdAt: now(),
        sellCount: 0, buyCount: 0, totalEarned: 0,
        homeAddress: '', pickupAddress: '', pincode: '',
        lat: null, lng: null,
        aadhaarSame: false,
        visitCount: 1, lastSeen: now()
      };
      var list = customer.all(); list.push(c); customer.save(list);
      customer.startSession(c);
      notify.log(phone, 'registration', { name: name });
      return { ok: true, customer: c };
    },

    login: function(phone, password) {
      var c = customer.byPhone(phone);
      if (!c) return { ok: false, err: 'No account found. Please register first.' };
      if (c.pwHash !== hash(password)) return { ok: false, err: 'Incorrect password.' };
      customer.startSession(c);
      return { ok: true, customer: c };
    },

    startSession: function(c) {
      set(K.cust_sess, { id: c.id, ts: Date.now() });
      // Bump visit count
      var list = customer.all();
      var i = list.findIndex(function(x){ return x.id === c.id; });
      if (i > -1) { list[i].visitCount = (list[i].visitCount||0) + 1; list[i].lastSeen = now(); customer.save(list); }
    },
    logout: function() { localStorage.removeItem(K.cust_sess); },

    current: function() {
      var sess = get(K.cust_sess);
      if (!sess || !sess.id) return null;
      if (Date.now() - sess.ts > SESSION_TTL) { localStorage.removeItem(K.cust_sess); return null; }
      return customer.all().find(function(c) { return c.id === sess.id; }) || null;
    },

    update: function(id, changes) {
      var list = customer.all();
      var i = list.findIndex(function(c) { return c.id === id; });
      if (i < 0) return false;
      list[i] = Object.assign(list[i], changes);
      customer.save(list); return true;
    }
  };

  // ── SELL REQUESTS ──────────────────────────────────────────────
  var sells = {
    all: function() { return arr(K.sell_reqs); },
    save: function(list) { set(K.sell_reqs, list); },

    submit: function(data, custId) {
      var req = Object.assign({}, data, {
        id: uid(), customerId: custId || null,
        status: 'pending', createdAt: now(), adminNote: ''
      });
      var list = sells.all(); list.push(req); sells.save(list);

      // Mirror to admin leads
      var leads = arr(K.leads);
      leads.push({
        id: req.id, name: data.name || '', phone: data.phone || '',
        device: [data.brand, data.model, data.storage].filter(Boolean).join(' '),
        devType: (data.brand || '').toLowerCase(),
        model: data.model || '', storage: data.storage || '',
        color: data.color || '', condition: data.condition || '',
        battery: data.batteryHealth || '', imei: data.imei || '',
        ram: data.ram || '',
        accessories: data.accessories || [],
        photos: data.photos || [],
        askPrice: data.askingPrice || 0,
        notes: [{ t: 'Website submission', at: now() }],
        status: 'new', slot: data.slot || 'morning',
        source: 'website', createdAt: now(), customerId: custId || null
      });
      set(K.leads, leads);

      notify.log(data.phone || '', 'sell_received', { name: data.name, device: data.model });
      return req;
    },

    forCustomer: function(custId) {
      return sells.all().filter(function(r) { return r.customerId === custId; });
    }
  };

  // ── INVENTORY ──────────────────────────────────────────────────
  var inventory = {
    all: function() { return arr(K.inv); },
    visible: function() { return inventory.all().filter(function(i) { return i.visible; }); }
  };

  // ── NOTIFICATION STUB ──────────────────────────────────────────
  // Structured for easy drop-in of paid API later
  var notify = {
    log: function(phone, template, data) {
      console.log('[NOTIFY] phone=' + phone + ' tpl=' + template, data);
      // Future: if (window.SMB_NOTIFY === 'twilio') { ... }
      // Future: if (window.SMB_NOTIFY === 'interakt') { ... }
    },
    templates: {
      registration:  'Welcome {name}! You are registered with Sambhi Mobiles. +91 7827505579',
      sell_received: 'Hi {name}! We received your sell request for {device}. We will call within 2 hours.',
      pickup_booked: 'Pickup confirmed for {device}. Rider on the way. +91 7827505579'
    }
  };

  // Public API
  // Track page views for logged-in customer
  (function trackPage(){
    try {
      var sess = get(K.cust_sess);
      if (!sess || !sess.id) return;
      var key = 'smb_pv_' + new Date().toDateString().replace(/ /g,'_');
      var pv = get(key) || {};
      pv[sess.id] = (pv[sess.id]||0) + 1;
      set(key, pv);
    } catch(e){}
  })();
  return { K: K, get: get, set: set, arr: arr, hash: hash, uid: uid, now: now, Rs: Rs, fmtDate: fmtDate, customer: customer, sells: sells, inventory: inventory, notify: notify };
})();

// ── NAV STATE ──────────────────────────────────────────────────────
function smbUpdateNav() {
  var c = SMB.customer.current();
  document.querySelectorAll('[data-guest]').forEach(function(el) {
    el.style.display = c ? 'none' : '';
  });
  document.querySelectorAll('[data-auth]').forEach(function(el) {
    el.style.display = c ? '' : 'none';
  });
  document.querySelectorAll('[data-cname]').forEach(function(el) {
    el.textContent = c ? c.name.split(' ')[0] : '';
  });
}
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', smbUpdateNav);
} else { smbUpdateNav(); }
