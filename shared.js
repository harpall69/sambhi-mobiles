// ================================================================
// SAMBHI MOBILES — SHARED.JS v4
// Canonical data layer (Supabase client + SMB customer/session/leads
// store), auth/OTP/Google-signin helpers, and shared UI chrome (nav
// scroll effects, mobile nav, auth modal, toast).
//
// Include this ONCE per page via <script src="shared.js"></script>,
// placed right after the footer/auth-modal/toast markup and BEFORE
// any page-specific <script> block — the UI-chrome section below
// touches nav/footer/modal DOM nodes on load, so they must already
// exist when this file runs.
//
// This is the canonical source: sell.html previously carried a more
// advanced fork of SB/SMB (two-phase lead creation, Supabase Storage
// uploads, RPC calls) than every other page's copy — that fork is
// merged in here as the one true version all pages now share.
// ================================================================
'use strict';

// ── SUPABASE CLIENT ─────────────────────────────────────────────
var SB = (function() {
  var URL = (typeof window !== 'undefined' && window.SUPABASE_URL) ? window.SUPABASE_URL : '';
  var KEY = (typeof window !== 'undefined' && window.SUPABASE_KEY) ? window.SUPABASE_KEY : '';
  function configured(){ return !!(URL && KEY && URL !== 'YOUR_PROJECT_URL_HERE' && KEY !== 'YOUR_ANON_KEY_HERE'); }
  function headers(){ return {'Content-Type':'application/json','apikey':KEY,'Authorization':'Bearer '+KEY,'Prefer':'return=representation'}; }
  async function query(table, opts) {
    if (!configured()) return null;
    opts = opts || {};
    var url = URL + '/rest/v1/' + table;
    var params = [];
    if (opts.select) params.push('select='+opts.select);
    if (opts.filter) params.push(opts.filter);
    if (opts.order)  params.push('order='+opts.order);
    if (opts.limit)  params.push('limit='+opts.limit);
    if (params.length) url += '?' + params.join('&');
    try {
      var r = await fetch(url, {method:'GET', headers:headers()});
      if (!r.ok) return null;
      if (r.status === 204) return [];
      return await r.json();
    } catch(e) { return null; }
  }
  async function insert(table, data) {
    if (!configured()) return null;
    try {
      var r = await fetch(URL+'/rest/v1/'+table, {method:'POST', headers:headers(), body:JSON.stringify(data)});
      if (!r.ok) return null;
      return await r.json();
    } catch(e) { return null; }
  }
  async function update(table, filter, data) {
    if (!configured()) return null;
    try {
      var r = await fetch(URL+'/rest/v1/'+table+'?'+filter, {method:'PATCH', headers:headers(), body:JSON.stringify(data)});
      if (!r.ok) return null;
      return await r.json();
    } catch(e) { return null; }
  }
  async function remove(table, filter) {
    if (!configured()) return null;
    try {
      var r = await fetch(URL+'/rest/v1/'+table+'?'+filter, {method:'DELETE', headers:headers()});
      return r.ok;
    } catch(e) { return false; }
  }
  async function rpc(fn, args) {
    if (!configured()) return null;
    try {
      var r = await fetch(URL+'/rest/v1/rpc/'+fn, {method:'POST', headers:headers(), body:JSON.stringify(args||{})});
      if (!r.ok) return null;
      return await r.json();
    } catch(e) { return null; }
  }
  async function uploadDataUrl(bucket, path, dataUrl) {
    if (!configured() || !dataUrl) return null;
    try {
      var res = await fetch(dataUrl);
      var blob = await res.blob();
      var r = await fetch(URL+'/storage/v1/object/'+bucket+'/'+encodeURIComponent(path), {
        method:'POST',
        headers:{'apikey':KEY,'Authorization':'Bearer '+KEY,'Content-Type':blob.type||'image/jpeg','x-upsert':'true'},
        body: blob
      });
      return r.ok ? path : null;
    } catch(e) { return null; }
  }
  return {configured:configured, query:query, insert:insert, update:update, remove:remove, rpc:rpc, uploadDataUrl:uploadDataUrl};
})();

// ── SMB DATA LAYER ──────────────────────────────────────────────
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
      phone = (phone + '').replace(/\D/g, '').slice(-10);
      return customer.all().find(function(c) {
        return c.phone === phone || (c.altPhone && c.altPhone === phone);
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

    // Phase 1 — called right after name/phone/email are known (before the
    // price is revealed and before pickup logistics exist). Returns a
    // Promise<{localId, dbId}>; dbId is used later by attachPickup to update
    // the same row instead of creating a second one.
    createLead: function(data, custId) {
      var req = Object.assign({}, data, {
        id: uid(), customerId: custId || null,
        status: 'pending', createdAt: now(), adminNote: ''
      });
      var reqToSave = Object.assign({}, req, {photos: []}); // strip base64 to prevent localStorage overflow
      var list = sells.all(); list.push(reqToSave); sells.save(list);

      var leads = arr(K.leads);
      var localLead = {
        id: req.id, name: data.name || '', phone: data.phone || '',
        device: [data.brand, data.model, data.storage].filter(Boolean).join(' '),
        devType: (data.brand || '').toLowerCase(),
        model: data.model || '', storage: data.storage || '',
        color: data.color || '', condition: data.condition || '',
        battery: data.batteryHealth || '', imei: data.imei || '',
        ram: data.ram || '',
        accessories: data.accessories || [],
        photos: [], // not stored in leads (too large)
        askPrice: data.askingPrice || 0,
        notes: [{ t: 'Website submission (pre-pickup)', at: now() }],
        status: 'new', slot: '',
        source: 'website', createdAt: now(), customerId: custId || null
      };
      leads.push(localLead);
      set(K.leads, leads);

      return new Promise(function(resolve) {
        if (!(typeof SB !== 'undefined' && SB.configured && SB.configured())) {
          resolve({ localId: req.id, dbId: null });
          return;
        }
        (async function() {
          var leadUid = uid();
          var photoPaths = [];
          try {
            var photos = data.photos || [];
            for (var i = 0; i < photos.length; i++) {
              var p = await SB.uploadDataUrl('lead-photos', leadUid+'/photo-'+i+'.jpg', photos[i]);
              if (p) photoPaths.push(p);
            }
          } catch(e) {}
          var billPath = null;
          try {
            if (data.billPhoto) billPath = await SB.uploadDataUrl('lead-photos', leadUid+'/bill.jpg', data.billPhoto);
          } catch(e) {}

          // NOTE: the live 'leads' table has no 'email' or 'diagnostics' column (confirmed via a
          // PGRST204 schema-cache error during testing) — folding both into the existing 'notes'
          // field instead of altering the table schema without sign-off. Add an `email text` and/or
          // `diagnostics jsonb` column to 'leads' later if you want them queryable directly.
          var extraNote = (data.email ? ('Email: ' + data.email + '. ') : '') + (data.diagnostics ? ('Diagnostics — power/charging: ' + (data.diagnostics.power ? 'OK' : 'issue reported')
            + ', biometrics/camera: ' + (data.diagnostics.bio ? 'OK' : 'issue reported')
            + ', speaker/mic/buttons: ' + (data.diagnostics.av ? 'OK' : 'issue reported')) : '');

          var rows = await SB.insert('leads', {
            name: data.name || '', phone: data.phone || '',
            dev_type: (data.brand || '').toLowerCase(),
            device: [data.brand, data.model, data.storage].filter(Boolean).join(' '),
            model: data.model || '', storage: data.storage || '',
            color: data.color || '', year: data.year || '',
            battery: data.batteryHealth || '', imei: data.imei || '',
            ram: data.ram || '', condition: data.condition || '',
            screen_condition: data.screenCondition || '', body_condition: data.bodyCondition || '',
            water_damage: data.waterDamage === true, repaired_parts: data.repairedParts || [],
            frp_cleared: false, bill_photo: billPath,
            accessories: data.accessories || [], photos: photoPaths,
            est_price: data.askingPrice || 0, base_price: data.askingPrice || 0,
            is_loyalty: !!data.isLoyalty, slot: '',
            source: 'website', status: 'new',
            notes: [{ t: 'Website submission (pre-pickup)' + (extraNote ? ' — ' + extraNote : ''), at: now() }]
          }).catch(function(){ return null; });

          var dbId = (rows && rows[0] && rows[0].id) || null;
          notify.log(data.phone || '', 'sell_received', { name: data.name, device: data.model });
          resolve({ localId: req.id, dbId: dbId });
        })();
      });
    },

    // Phase 2 — called after pickup address/slot/FRP-confirmation are known.
    // Updates the same lead row rather than creating a new one.
    attachPickup: function(ids, pickup) {
      var list = sells.all();
      var i = list.findIndex(function(r){ return r.id === ids.localId; });
      if (i > -1) { list[i] = Object.assign(list[i], pickup, {status:'confirmed'}); sells.save(list); }
      var leads = arr(K.leads);
      var j = leads.findIndex(function(l){ return l.id === ids.localId; });
      if (j > -1) { leads[j] = Object.assign(leads[j], {
        address: pickup.address||'', pincode: pickup.pincode||'', slot: pickup.slot||'morning'
      }); set(K.leads, leads); }

      notify.log(pickup.phone || '', 'pickup_booked', { device: pickup.device });

      if (!(typeof SB !== 'undefined' && SB.configured && SB.configured() && ids.dbId)) {
        return Promise.resolve(null);
      }
      return (async function() {
        var riderId = null;
        try {
          if (pickup.pincode) { var rid = await SB.rpc('match_rider_for_pincode', { p: pickup.pincode }); if (rid) riderId = rid; }
        } catch(e) {}
        return SB.update('leads', 'id=eq.' + ids.dbId, {
          address: pickup.address || '', pincode: pickup.pincode || '',
          area: pickup.area || '', zone: pickup.zone || '',
          slot: pickup.slot || 'morning', frp_cleared: true, rider_id: riderId,
          notes: [{ t: 'Pickup scheduled' + (pickup.notes ? (' — ' + pickup.notes) : ''), at: now() }]
        }).catch(function(){ return null; });
      })();
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

// ── OTP AUTH ──────────────────────────────────────────────────────────
var otpStore = {};  // {phone: {code, expires, name}}

SMB.otp = {
  generate: function(phone, name) {
    phone = (phone + '').replace(/\D/g, '').slice(-10);
    var code = String(Math.floor(100000 + Math.random() * 900000));
    otpStore[phone] = { code: code, expires: Date.now() + 10 * 60 * 1000, name: name || '' };
    return { phone: phone, code: code };
  },
  verify: function(phone, inputCode) {
    phone = (phone + '').replace(/\D/g, '').slice(-10);
    var entry = otpStore[phone];
    if (!entry) return { ok: false, err: 'No OTP sent for this number. Please request again.' };
    if (Date.now() > entry.expires) { delete otpStore[phone]; return { ok: false, err: 'OTP expired. Please request a new one.' }; }
    if (entry.code !== inputCode.trim()) return { ok: false, err: 'Incorrect OTP. Please check and try again.' };
    delete otpStore[phone];
    var c = SMB.customer.byPhone(phone);
    if (!c) {
      c = { id: SMB.uid(), name: entry.name || 'Customer', phone: phone, altPhone: '',
            pwHash: SMB.hash(SMB.uid()), // random pw hash
            createdAt: SMB.now(), sellCount: 0, buyCount: 0,
            visitCount: 1, lastSeen: SMB.now(), homeAddress: '', pickupAddress: '',
            aadhaarSame: false, lat: null, lng: null };
      var list = SMB.arr(SMB.K.customers); list.push(c); SMB.set(SMB.K.customers, list);
    }
    SMB.customer.startSession(c);
    return { ok: true, customer: c };
  }
};

// ── GOOGLE AUTH HELPER ────────────────────────────────────────────────
SMB.googleAuth = {
  handleUser: function(googleUser) {
    var email = googleUser.email || '';
    var name  = googleUser.displayName || email.split('@')[0] || 'User';
    var uid   = googleUser.uid || googleUser.providerData?.[0]?.uid || email;
    var phone = ''; // Google doesn't give phone
    var list = SMB.arr(SMB.K.customers);
    var c = list.find(function(x) { return x.email === email || x.googleUid === uid; });
    if (!c) {
      c = { id: SMB.uid(), name: name, phone: phone, altPhone: '',
            pwHash: SMB.hash(uid), email: email, googleUid: uid,
            createdAt: SMB.now(), sellCount: 0, buyCount: 0,
            visitCount: 1, lastSeen: SMB.now(), homeAddress: '', pickupAddress: '',
            aadhaarSame: false, lat: null, lng: null };
      list.push(c); SMB.set(SMB.K.customers, list);
    } else {
      c.name = name; c.email = email; c.googleUid = uid;
      var i = list.findIndex(function(x){return x.id===c.id;}); if(i>-1) list[i]=c;
      SMB.set(SMB.K.customers, list);
    }
    SMB.customer.startSession(c);
    return { ok: true, customer: c };
  }
};

// ================================================================
// UI CHROME — nav scroll/reveal, mobile nav, auth modal, toast.
// Runs immediately (this script is placed after the nav/footer/
// modal markup), so DOM nodes below already exist.
// ================================================================

// ── SCROLL: NAV + PROGRESS + REVEAL ────────────────────────────────
(function(){
  function tick(){
    var scrolled=window.scrollY,total=document.body.scrollHeight-window.innerHeight;
    var p=document.getElementById('progress');if(p)p.style.width=(scrolled/total*100)+'%';
    var nav=document.querySelector('nav');if(nav)nav.classList.toggle('scrolled',scrolled>50);
    document.querySelectorAll('.reveal,.reveal-left').forEach(function(el){
      if(el.getBoundingClientRect().top<window.innerHeight*.88)el.classList.add('in');
    });
  }
  window.addEventListener('scroll',tick,{passive:true});
  setTimeout(tick,80);
})();

// ── MOBILE NAV ──────────────────────────────────────────────────────
function openMobNav(){var m=document.getElementById('mobNav');if(m){m.classList.add('open');document.body.style.overflow='hidden';}}
function closeMobNav(){var m=document.getElementById('mobNav');if(m){m.classList.remove('open');document.body.style.overflow='';}}

// ── AUTH ────────────────────────────────────────────────────────────
function openAuth(){var m=document.getElementById('authModal');if(m){m.classList.add('open');document.body.style.overflow='hidden';}}
function closeAuth(){var m=document.getElementById('authModal');if(m){m.classList.remove('open');document.body.style.overflow='';}}
function showAuthErr(msg){var e=document.getElementById('authErr');if(e){e.textContent=msg;e.style.display='block';}}
function authSwitch(tab){
  var tabs={login:'tabL',otp:'tabOTP',reg:'tabR'};
  var forms={login:'loginForm',otp:'otpForm',reg:'regForm'};
  Object.keys(tabs).forEach(function(t){
    var te=document.getElementById(tabs[t]);var fe=document.getElementById(forms[t]);
    if(te)te.classList.toggle('on',t===tab);
    if(fe)fe.style.display=t===tab?'':'none';
  });
  var err=document.getElementById('authErr');if(err)err.style.display='none';
  if(tab==='otp')resetOTP();
}
function doLogin(){
  var ph=(document.getElementById('lPhone').value||'').trim();
  var pw=(document.getElementById('lPw').value||'').trim();
  if(!ph||!pw){showAuthErr('Enter your phone number and password.');return;}
  var r=SMB.customer.login(ph,pw);
  if(!r.ok){showAuthErr(r.err);return;}
  closeAuth();smbUpdateNav();showToast('Welcome back, '+r.customer.name.split(' ')[0]+'!');
}
function doRegister(){
  var name=(document.getElementById('rName').value||'').trim();
  var ph=(document.getElementById('rPhone').value||'').trim();
  var alt=(document.getElementById('rAlt').value||'').trim();
  var pw=(document.getElementById('rPw').value||'').trim();
  if(!name){showAuthErr('Enter your full name.');return;}
  if(ph.length<10){showAuthErr('Enter a valid 10-digit mobile number.');return;}
  if(pw.length<6){showAuthErr('Password must be at least 6 characters.');return;}
  var rr=SMB.customer.register(name,ph,alt,pw);
  if(!rr.ok){showAuthErr(rr.err);return;}
  closeAuth();smbUpdateNav();showToast('Welcome, '+name.split(' ')[0]+'! Account created.');
}
function doLogout(){SMB.customer.logout();smbUpdateNav();showToast('Logged out.');}

// ── OTP FLOW ──────────────────────────────────────────────────────────
var _otpPhone='',_otpName='';
function sendOTP(){
  var name=(document.getElementById('otpName').value||'').trim();
  var phone=(document.getElementById('otpPhone').value||'').trim();
  if(phone.length<10){showAuthErr('Enter a valid 10-digit number.');return;}
  _otpPhone=phone;_otpName=name;
  var result=SMB.otp.generate(phone,name);
  var msg='🔐 Your Sambhi Mobiles OTP is: *'+result.code+'*\n\nValid 10 mins. Do not share.\n📱 sambhi-mobiles.vercel.app';
  window.open('https://wa.me/91'+phone+'?text='+encodeURIComponent(msg),'_blank');
  document.getElementById('otpStep1').style.display='none';
  document.getElementById('otpStep2').style.display='block';
}
function verifyOTP(){
  var code=(document.getElementById('otpCode').value||'').trim();
  if(code.length!==6){showAuthErr('Enter the 6-digit OTP from WhatsApp.');return;}
  var r=SMB.otp.verify(_otpPhone,code);
  if(!r.ok){showAuthErr(r.err);return;}
  closeAuth();smbUpdateNav();showToast('Welcome, '+r.customer.name.split(' ')[0]+'! 👋');
}
function resetOTP(){
  var s1=document.getElementById('otpStep1'),s2=document.getElementById('otpStep2'),oc=document.getElementById('otpCode'),err=document.getElementById('authErr');
  if(s1)s1.style.display='block';
  if(s2)s2.style.display='none';
  if(oc)oc.value='';
  if(err)err.style.display='none';
  _otpPhone='';_otpName='';
}
function signInWithGoogle(){
  if(typeof firebase==='undefined'||!window.firebaseAuth){
    alert('Google login not configured yet.\nSetup: console.firebase.google.com → Enable Google Auth → Add config to this page.');return;
  }
  var provider=new firebase.auth.GoogleAuthProvider();
  window.firebaseAuth.signInWithPopup(provider).then(function(result){
    var r=SMB.googleAuth.handleUser({uid:result.user.uid,email:result.user.email,displayName:result.user.displayName});
    if(r.ok){closeAuth();smbUpdateNav();showToast('Welcome, '+r.customer.name.split(' ')[0]+'! 🎉');}
  }).catch(function(e){showAuthErr(e.message);});
}

// ── TOAST ────────────────────────────────────────────────────────────
function showToast(msg,type){
  var wrap=document.querySelector('.toast-wrap');if(!wrap)return;
  var t=document.createElement('div');t.className='toast'+(type?' '+type:'');t.textContent=msg;
  wrap.appendChild(t);
  requestAnimationFrame(function(){requestAnimationFrame(function(){t.classList.add('show');});});
  setTimeout(function(){t.classList.remove('show');setTimeout(function(){t.remove();},320);},3800);
}

// ── BACKDROP CLOSE ────────────────────────────────────────────────────
document.addEventListener('click',function(e){
  if(e.target.id==='authModal')closeAuth();
});

smbUpdateNav();
