/* Rawand Aldeeb Studio — live data for the public site:
   saves form requests, logs visits/clicks, and loads reviews + projects
   managed from /admin. Does nothing until assets/rw-config.js is filled in. */
(function () {
  var C = window.RW_SB || {};
  if (!C.url || !C.key) return;
  var U = C.url.replace(/\/+$/, ''), K = C.key, root = document.documentElement;

  function hdr(extra) {
    var h = { apikey: K, 'Content-Type': 'application/json' };
    if (K.indexOf('eyJ') === 0) h.Authorization = 'Bearer ' + K;
    for (var k in extra) h[k] = extra[k];
    return h;
  }
  function post(table, row) {
    return fetch(U + '/rest/v1/' + table, {
      method: 'POST', keepalive: true,
      headers: hdr({ Prefer: 'return=minimal' }), body: JSON.stringify(row)
    }).catch(function () {});
  }
  function get(q) {
    return fetch(U + '/rest/v1/' + q, { headers: hdr({}) })
      .then(function (r) { return r.ok ? r.json() : []; })
      .catch(function () { return []; });
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function cut(s, n) { s = String(s == null ? '' : s).trim(); return s.length > n ? s.slice(0, n) : s; }

  /* ---------------- analytics ---------------- */
  var isAdmin = false;
  try { isAdmin = localStorage.getItem('rw-admin') === '1'; } catch (e) {}
  var sid = '';
  try {
    sid = sessionStorage.getItem('rw-sid') || '';
    if (!sid) { sid = Math.random().toString(36).slice(2, 12) + Date.now().toString(36); sessionStorage.setItem('rw-sid', sid); }
  } catch (e) { sid = 'x' + Math.random().toString(36).slice(2, 10); }
  var w = Math.min(screen.width || innerWidth, innerWidth);
  var device = /iPad|Tablet/i.test(navigator.userAgent) || (w >= 640 && w < 1024 && 'ontouchstart' in window) ? 'tablet'
    : (w < 640 ? 'mobile' : 'desktop');
  var ref = '';
  try { if (document.referrer) { var rh = new URL(document.referrer).hostname.replace(/^www\./, ''); if (rh && rh !== location.hostname.replace(/^www\./, '')) ref = rh; } } catch (e) {}
  if (!ref) { var m = location.search.match(/[?&]utm_source=([^&]+)/); if (m) ref = decodeURIComponent(m[1]); }
  // Links opened inside Instagram / Facebook / TikTok... usually arrive with no referrer: read it from the in-app browser.
  if (!ref) {
    var ua = navigator.userAgent || '';
    if (/Instagram/i.test(ua)) ref = 'instagram.com';
    else if (/FBAN|FBAV|FB_IAB/i.test(ua)) ref = 'facebook.com';
    else if (/musical_ly|BytedanceWebview|TikTok/i.test(ua)) ref = 'tiktok.com';
    else if (/Snapchat/i.test(ua)) ref = 'snapchat.com';
    else if (/LinkedInApp/i.test(ua)) ref = 'linkedin.com';
    else if (/Pinterest/i.test(ua)) ref = 'pinterest.com';
  }

  function track(type, label) {
    if (isAdmin) return;
    post('events', {
      type: type, label: label ? cut(label, 160) : null,
      path: cut(location.pathname + (location.hash || ''), 160) || '/',
      ref: ref ? cut(ref, 160) : null, device: device,
      lang: root.lang === 'en' ? 'en' : 'ar', sid: sid
    });
  }
  window.RW_track = track;

  track('view', document.title);
  var lastHash = location.hash;
  window.addEventListener('hashchange', function () {
    var h = location.hash;
    if (h === '#gallery' || (h.indexOf('#g-') === 0 && lastHash.indexOf('#g') !== 0)) track('gallery', h.slice(1));
    lastHash = h;
  });

  function lbl(el) {
    var t = el.querySelector && el.querySelector('[data-l="' + (root.lang === 'en' ? 'en' : 'ar') + '"]');
    return (t ? t.textContent : el.textContent || '').trim();
  }
  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a, button');
    if (!a) return;
    if (a.matches('a.wa-link, #fSend')) return track('whatsapp', a.id === 'fSend' ? 'form' : (a.classList.contains('fab') ? 'floating' : lbl(a)));
    if (a.matches('.mail-ic')) return track('email', 'gmail');
    if (a.matches('.svc-cta')) return track('service', a.dataset.svc || lbl(a));
    if (a.matches('.tab')) return track('filter', a.dataset.f);
    if (a.matches('.shot')) return track('image', a.dataset.capAr || a.dataset.full);
    if (a.id === 'langBtn') return track('lang', root.lang === 'ar' ? 'en' : 'ar');
    if (a.id === 'modeBtn') return track('mode', root.getAttribute('data-mode') === 'light' ? 'dark' : 'light');
    var href = a.getAttribute('href') || '';
    if (href === '#contact') return track('cta', lbl(a));
    if (href === '#gallery' || href.indexOf('#g-') === 0) return;
    if (/^https?:/.test(href) && a.host !== location.host) return track('outbound', a.host);
  }, true);

  /* ---------------- request form ---------------- */
  var form = document.getElementById('reqForm'), lastSig = '';
  if (form) form.addEventListener('submit', function () {
    var fs = document.getElementById('fSvc');
    var svc = fs && fs.value ? fs.selectedOptions[0] : null;
    if (!svc) return;
    var bud = form.querySelector('input[name="budget"]:checked');
    var v = function (id) { var el = document.getElementById(id); return el ? el.value.trim() : ''; };
    var row = {
      service: cut(svc.dataset.ar || svc.value, 80),
      budget: bud ? cut((bud.dataset.ar || bud.value) + (bud.value === 'set' && v('fBudget') ? ' — ' + v('fBudget') : ''), 80) : null,
      name: cut(v('fName'), 120) || null,
      contact: cut(v('fContact'), 120) || null,
      message: cut(v('fMsg'), 3000) || null,
      lang: root.lang === 'en' ? 'en' : 'ar'
    };
    var sig = JSON.stringify(row);
    if (sig === lastSig) return;
    lastSig = sig;
    post('requests', row);
    track('request', svc.dataset.ar || svc.value);
  });

  /* ---------------- reviews ---------------- */
  var AV = {
    woman: '<svg viewBox="0 0 48 48" aria-hidden="true"><path d="M24 7c-7.6 0-12.5 6-12.5 13.2 0 4.8 1.6 8.4 3.6 10.8C11.3 33 8.6 37 8 42h32c-.6-5-3.3-9-7.1-11 2-2.4 3.6-6 3.6-10.8C36.5 13 31.6 7 24 7z" fill="currentColor"/><ellipse cx="24" cy="20.5" rx="6" ry="7.2" fill="var(--av-face)"/></svg>',
    man: '<svg viewBox="0 0 48 48" aria-hidden="true"><circle cx="24" cy="18" r="8" fill="currentColor"/><path d="M9 42c1.5-8.5 7.8-13 15-13s13.5 4.5 15 13z" fill="currentColor"/></svg>'
  };
  function reviewCard(r) {
    var n = Math.max(1, Math.min(5, r.rating || 5));
    var ar = esc(r.text_ar), en = esc(r.text_en || r.text_ar);
    return '<figure class="tcard">' +
      '<div class="t-top"><span class="stars" aria-label="' + n + ' / 5">' + '★★★★★'.slice(0, n) + '<b>' + n + '.0</b></span></div>' +
      '<blockquote><p data-l="ar">«' + ar + '»</p><p data-l="en" dir="' + (r.text_en ? 'ltr' : 'auto') + '">“' + en + '”</p></blockquote>' +
      '<figcaption><span class="t-av t-' + (r.avatar === 'man' ? 'man' : 'woman') + '">' + AV[r.avatar === 'man' ? 'man' : 'woman'] + '</span>' +
      '<span class="t-who"><b class="t-name"><span data-l="ar">' + esc(r.name_ar) + '</span><span data-l="en">' + esc(r.name_en || r.name_ar) + '</span></b>' +
      (r.project_ar ? '<span class="t-proj"><span class="sq"></span><span data-l="ar">' + esc(r.project_ar) + '</span><span data-l="en">' + esc(r.project_en || r.project_ar) + '</span></span>' : '') +
      '</span></figcaption></figure>';
  }
  var track_ = document.getElementById('tTrack');
  if (track_) get('reviews?select=*&published=eq.true&order=sort.asc,created_at.desc').then(function (rows) {
    if (!rows || !rows.length) return;
    track_.innerHTML = rows.map(reviewCard).join('');
    track_.scrollLeft = 0;
    track_.dispatchEvent(new Event('scroll'));
  });

  /* ---------------- projects ---------------- */
  var css = document.createElement('style');
  css.textContent = '.dbp-grid{columns:3 240px;column-gap:14px;margin-top:14px}' +
    '.dbp-grid .shot{display:block;width:100%;margin:0 0 14px;break-inside:avoid}' +
    '.dbp-grid .shot img{display:block;width:100%;height:auto}';
  document.head.appendChild(css);
  var CAT_EN = { social: 'Social Media', logo: 'Logo Design', identity: 'Visual Identity', motion: 'Motion Graphics' };
  var work = document.getElementById('work');
  if (work) get('projects?select=*&published=eq.true&order=sort.asc,created_at.desc').then(function (rows) {
    if (!rows || !rows.length) return;
    rows.slice().reverse().forEach(function (p) {
      var imgs = Array.isArray(p.images) ? p.images : [];
      if (!imgs.length) return;
      var tAr = esc(p.title_ar), tEn = esc(p.title_en || p.title_ar);
      var d = document.createElement('div');
      d.className = 'cat dbp'; d.dataset.cat = p.category; d.id = 'g-p' + p.id;
      d.innerHTML =
        '<div class="cat-h"><h3><span class="sq"></span><span data-l="ar">' + tAr + '</span><span data-l="en">' + tEn + '</span></h3><span>' + (p.title_en ? tEn : CAT_EN[p.category] || '') + '</span></div>' +
        (p.desc_ar || p.desc_en ? '<p class="cat-note"><span data-l="ar">' + esc(p.desc_ar || p.desc_en) + '</span><span data-l="en">' + esc(p.desc_en || p.desc_ar) + '</span></p>' : '') +
        '<div class="dbp-grid">' + imgs.map(function (u, i) {
          return '<button class="shot" type="button" data-full="' + esc(u) + '" data-cap-ar="' + tAr + '" data-cap-en="' + tEn + '"><img src="' + esc(u) + '" alt="' + tEn + ' ' + (i + 1) + '" loading="lazy"></button>';
        }).join('') + '</div>';
      var first = work.querySelector('.cat[data-cat="' + p.category + '"]:not(.dbp)') || work.querySelector('.cat');
      if (first) first.parentNode.insertBefore(d, first); else work.appendChild(d);
      var active = document.querySelector('.tab[aria-pressed="true"]');
      if (active && active.dataset.f !== 'all' && active.dataset.f !== p.category) d.hidden = true;
      d.querySelectorAll('.shot').forEach(function (s) {
        s.addEventListener('click', function () { if (window.RW_open) window.RW_open(s); });
      });
    });
    var h = location.hash;
    if (h.indexOf('#g-p') === 0) { var el = document.getElementById(h.slice(1)); if (el) el.scrollIntoView({ block: 'start' }); }
  });
})();
