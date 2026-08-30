/* Wasl Admin Panel — vanilla SPA talking to the NestJS backend. */

// Set only by trusted deployment configuration, never by a URL parameter.
const API_BASE =
  document.querySelector('meta[name="wasl-api-base"]')?.content.trim() ||
  window.location.origin;

// A refresh deliberately requires a new administrator login.
let token = '';

/* ---------- helpers ---------- */
const $ = (id) => document.getElementById(id);
const escapeHtml = (value) =>
  String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/* ---------- protected documents ----------
   `uploads/` is no longer a public static folder: national IDs, selfies and
   payment proofs need a Bearer token now. An <img src> cannot send headers, so
   we fetch the bytes ourselves and hand the tag a blob: URL instead. */
const docCache = new Map();

async function docBlobUrl(path) {
  const key = String(path).replace(/^\/+/, '');
  if (docCache.has(key)) return docCache.get(key);

  const res = await fetch(`${API_BASE}/${key}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) throw new Error(`تعذّر تحميل المستند (${res.status})`);

  const url = URL.createObjectURL(await res.blob());
  docCache.set(key, url);
  return url;
}

/** Placeholder tag; `hydrateDocs` fills in the real image after render. */
const docThumb = (p) =>
  `<img class="doc-thumb" data-doc="${String(p).replace(/"/g, '&quot;')}" alt="مستند" data-act="lightbox" />`;

async function hydrateDocs(root) {
  for (const img of (root || document).querySelectorAll('img[data-doc]')) {
    const path = img.dataset.doc;
    img.removeAttribute('data-doc');
    try {
      img.src = await docBlobUrl(path);
    } catch {
      const note = document.createElement('span');
      note.className = 'muted';
      note.textContent = 'تعذّر عرض المستند';
      img.replaceWith(note);
    }
  }
}

async function api(path, { method = 'GET', body } = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try { data = await res.json(); } catch { /* no body */ }
  if (!res.ok) throw new Error(data?.message || `خطأ ${res.status}`);
  return data;
}

function toast(msg, kind = 'ok') {
  const t = document.createElement('div');
  t.className = `toast ${kind}`;
  t.textContent = msg;
  document.body.appendChild(t);
  requestAnimationFrame(() => t.classList.add('show'));
  setTimeout(() => { t.classList.remove('show'); setTimeout(() => t.remove(), 250); }, 2600);
}

function showImage(url) {
  $('lightboxImg').src = url;
  $('lightbox').classList.remove('hidden');
}

function statusBadge(status) {
  const map = { active: 'نشط', pending: 'قيد المراجعة', rejected: 'مرفوض', suspended: 'موقوف',
    approved: 'مقبول' };
  return `<span class="badge ${status}">${map[status] || status}</span>`;
}

/* ---------- auth ---------- */
$('loginForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  $('loginError').textContent = '';
  try {
    const data = await api('/auth/login', {
      method: 'POST',
      body: { phone: $('loginPhone').value.trim(), password: $('loginPassword').value },
    });
    if (data.user?.role !== 'admin') throw new Error('هذا الحساب ليس حساب مسؤول');
    token = data.token;
    localStorage.setItem('wasl_admin_name', data.user.name || 'المسؤول');
    enterApp();
  } catch (err) {
    $('loginError').textContent = err.message;
  }
});

$('logoutBtn').addEventListener('click', () => {
  token = '';
  // Drop the cached document blobs with the session, not just the token.
  docCache.forEach((url) => URL.revokeObjectURL(url));
  docCache.clear();
  $('appView').classList.add('hidden');
  $('loginView').classList.remove('hidden');
});

function enterApp() {
  $('loginView').classList.add('hidden');
  $('appView').classList.remove('hidden');
  $('whoami').textContent = localStorage.getItem('wasl_admin_name') || '';
  route('dashboard');
}

/* ---------- routing ---------- */
document.querySelectorAll('.nav-item').forEach((el) =>
  el.addEventListener('click', () => route(el.dataset.route)),
);

const TITLES = { dashboard: 'لوحة المعلومات', registrations: 'طلبات التسجيل',
  merchants: 'المتاجر', catalog: 'الكتالوج', orders: 'الطلبات',
  cancellations: 'مراجعة الإلغاءات', zones: 'المناطق والأسعار',
  topups: 'طلبات شحن المحفظة', settings: 'إعدادات النظام' };

function route(name) {
  document.querySelectorAll('.nav-item').forEach((el) =>
    el.classList.toggle('active', el.dataset.route === name));
  $('pageTitle').textContent = TITLES[name];
  $('pageBody').innerHTML = '<div class="empty">جاري التحميل...</div>';
  ({ dashboard: renderDashboard, registrations: renderRegistrations,
     merchants: renderMerchants, catalog: renderCatalog, orders: renderOrders,
     cancellations: renderCancellations, zones: renderZones,
     topups: renderTopups, settings: renderSettings }[name])();
}

/* ---------- dashboard ---------- */
async function renderDashboard() {
  try {
    const s = await api('/admin/dashboard');
    $('pageBody').innerHTML = `
      <div class="stat-grid">
        <div class="stat-card"><div class="num">${s.pendingDrivers}</div><div class="lbl">مناديب بانتظار الموافقة</div></div>
        <div class="stat-card"><div class="num">${s.pendingMerchants}</div><div class="lbl">متاجر بانتظار الموافقة</div></div>
        <div class="stat-card"><div class="num">${s.activeDrivers}</div><div class="lbl">مناديب نشطون</div></div>
        <div class="stat-card"><div class="num">${s.totalCustomers}</div><div class="lbl">إجمالي العملاء</div></div>
      </div>`;
  } catch (e) { $('pageBody').innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`; }
}

/* ---------- registrations ---------- */
async function renderRegistrations() {
  $('pageBody').innerHTML = `
    <div class="filters">
      <select id="fRole"><option value="">كل الأنواع</option><option value="delivery">مناديب</option><option value="merchant">متاجر</option></select>
      <select id="fStatus"><option value="">كل الحالات</option><option value="pending">قيد المراجعة</option><option value="active">مقبول</option><option value="rejected">مرفوض</option></select>
    </div>
    <div id="regList"></div>`;
  $('fRole').onchange = loadRegs;
  $('fStatus').onchange = loadRegs;
  loadRegs();
}

async function loadRegs() {
  const role = $('fRole').value, status = $('fStatus').value;
  const q = new URLSearchParams();
  if (role) q.set('role', role);
  if (status) q.set('status', status);
  try {
    const list = await api(`/admin/registrations?${q}`);
    if (!list.length) { $('regList').innerHTML = '<div class="empty">لا توجد طلبات</div>'; return; }
    $('regList').innerHTML = list.map(regRow).join('');
    hydrateDocs($('regList'));
  } catch (e) { $('regList').innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`; }
}

function regRow(u) {
  const d = u.details || {};
  const safe = (v) => escapeHtml(v == null ? '' : String(v));
  const docs = [d.nationalIdFront, d.nationalIdBack, d.selfie, d.vehicleImage, d.logo]
    .filter((x) => x && !String(x).startsWith('pending_'))
    .map(docThumb)
    .join('') || '<span class="muted">لا توجد مستندات مرفوعة</span>';
  const roleLbl = u.role === 'delivery' ? 'مندوب' : 'متجر';
  return `
    <div class="row">
      <div class="grow">
        <div class="name">${safe(u.name)} <span class="muted">(${safe(roleLbl)})</span></div>
        <div class="sub">📞 ${safe(u.phone)} ${u.details?.vehicleType ? '• 🏍️ ' + safe(u.details.vehicleType) : ''} ${u.details?.storeName ? '• 🏪 ' + safe(u.details.storeName) : ''}</div>
        <div class="sub">${statusBadge(u.status)} ${u.adminNotes ? '• ملاحظة: ' + safe(u.adminNotes) : ''}</div>
        <div class="docs" style="margin-top:10px">${docs}</div>
      </div>
      <div class="actions">
        <button class="btn btn-sm btn-green" data-act="review-reg" data-id="${Number(u.id)}" data-status="active">قبول</button>
        <button class="btn btn-sm btn-amber" data-act="review-reg" data-id="${Number(u.id)}" data-status="pending" data-ask="1">طلب تعديل</button>
        <button class="btn btn-sm btn-red" data-act="review-reg" data-id="${Number(u.id)}" data-status="rejected" data-ask="1">رفض</button>
      </div>
    </div>`;
}

async function reviewReg(userId, status, askNote) {
  let adminNotes;
  if (askNote) {
    adminNotes = prompt(status === 'rejected' ? 'سبب الرفض:' : 'التعديلات المطلوبة من المتقدم:');
    if (adminNotes === null) return;
  }
  try {
    await api(`/admin/approvals/review/${userId}`, { method: 'PATCH', body: { status, adminNotes } });
    toast('تم تحديث حالة الطلب');
    loadRegs();
  } catch (e) { toast(e.message, 'bad'); }
}

/* ---------- merchants: open / closed (CP-D) ----------
   The daily "the kitchen is closed" switch, deliberately separate from the
   approval workflow above: closing a shop is not a judgement on whether it
   belongs on the platform, and the backend keeps the two apart too. */

/* Merchant ids with an availability change in flight.
   Two fast clicks would send two PATCHes, and the shop ends up in whichever
   state the *last response* carried — not necessarily the one the admin
   clicked last. The check is synchronous, so the second click never becomes a
   request at all rather than racing the first. */
const availabilityInFlight = new Set();

function renderMerchants() {
  $('pageBody').innerHTML = '<div id="merchantList"></div>';
  loadMerchants();
}

async function loadMerchants() {
  try {
    // Approved merchants only — the endpoint filters by status, and an
    // unapproved store has nothing to open or close yet.
    const list = await api('/merchants');
    if (!list.length) {
      $('merchantList').innerHTML = '<div class="empty">لا توجد متاجر مقبولة</div>';
      return;
    }
    $('merchantList').innerHTML = list.map(merchantRow).join('');
  } catch (e) {
    $('merchantList').innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`;
  }
}

function merchantRow(m) {
  const safe = (v) => escapeHtml(v == null ? '' : String(v));
  // Numeric, because this value is interpolated into an onclick attribute.
  const id = Number(m.id);
  // `!== false` so a store from a response without the field reads as open,
  // matching the app: the server is what actually refuses a closed store.
  const open = m.isAcceptingOrders !== false;

  const badge = open
    ? '<span class="badge open">مفتوح — بيستقبل طلبات</span>'
    : '<span class="badge closed">مقفول — مش بيستقبل طلبات</span>';

  // The button says what pressing it will do; the badge says what is true now.
  // A button labelled with the current state is the classic way to get an
  // admin to close a shop they meant to open.
  const action = open
    ? `<button class="btn btn-sm btn-red" id="avail_${id}" data-act="merchant-availability" data-id="${id}" data-open="0">اقفل المتجر</button>`
    : `<button class="btn btn-sm btn-green" id="avail_${id}" data-act="merchant-availability" data-id="${id}" data-open="1">افتح المتجر</button>`;

  return `
    <div class="row">
      <div class="grow">
        <div class="name">${safe(m.storeName)} ${m.storeType ? '<span class="muted">(' + safe(m.storeType) + ')</span>' : ''}</div>
        <div class="sub">#${safe(id)}${m.addressDetails ? ' • ' + safe(m.addressDetails) : ''}</div>
        <div class="sub" style="margin-top:6px">${badge}</div>
      </div>
      <div class="actions">${action}</div>
    </div>`;
}

async function setMerchantAvailability(id, isAcceptingOrders) {
  if (availabilityInFlight.has(id)) return;
  availabilityInFlight.add(id);

  const btn = $(`avail_${id}`);
  if (btn) btn.disabled = true;

  try {
    const r = await api(`/admin/catalog/merchants/${id}/availability`, {
      method: 'PATCH',
      body: { isAcceptingOrders },
    });
    // Report what the server stored, not what we asked for.
    toast(r?.isAcceptingOrders ? 'تم فتح المتجر' : 'تم قفل المتجر');
    // Re-reading replaces the whole list, button included — so nothing
    // re-enables the old node, and the badge reflects the stored state.
    await loadMerchants();
  } catch (e) {
    toast(e.message, 'bad');
    // Only on failure: the row is still on screen and the admin should be
    // able to try again.
    if (btn) btn.disabled = false;
  } finally {
    availabilityInFlight.delete(id);
  }
}

/* ---------- top-up requests ---------- */
async function renderTopups() {
  $('pageBody').innerHTML = `
    <div class="filters">
      <select id="tStatus"><option value="pending">قيد المراجعة</option><option value="approved">مقبول</option><option value="rejected">مرفوض</option><option value="">الكل</option></select>
    </div>
    <div class="card">
      <h3>شحن يدوي لرصيد مندوب</h3>
      <div class="settings-grid" style="margin-top:12px">
        <div class="field"><input id="creditDriver" type="number" placeholder="رقم المندوب (ID)" /><input id="creditAmount" type="number" placeholder="المبلغ" /></div>
        <button class="btn btn-primary btn-sm" style="justify-self:start" data-act="manual-credit">إضافة رصيد</button>
      </div>
    </div>
    <div id="topupList"></div>`;
  $('tStatus').onchange = loadTopups;
  loadTopups();
}

async function loadTopups() {
  const status = $('tStatus').value;
  try {
    const list = await api(`/admin/payments/topup-requests${status ? '?status=' + status : ''}`);
    if (!list.length) { $('topupList').innerHTML = '<div class="empty">لا توجد طلبات شحن</div>'; return; }
    $('topupList').innerHTML = list.map(topupRow).join('');
    hydrateDocs($('topupList'));
  } catch (e) { $('topupList').innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`; }
}

function topupRow(r) {
  const safe = (v) => escapeHtml(v == null ? '' : String(v));
  const method = r.method === 'vodafone_cash' ? 'فودافون كاش' : 'إنستاباي';
  const proof = r.proofImageUrl
    ? docThumb(r.proofImageUrl)
    : '<span class="muted">بدون إثبات</span>';
  const actions = r.status === 'pending'
    ? `<button class="btn btn-sm btn-green" data-act="review-topup" data-id="${Number(r.id)}" data-action="approve">توثيق وإضافة الرصيد</button>
       <button class="btn btn-sm btn-red" data-act="review-topup" data-id="${Number(r.id)}" data-action="reject">رفض</button>`
    : '';
  return `
    <div class="row">
      <div class="grow">
        <div class="name">${safe(r.amount)} ج.م • ${safe(method)}</div>
        <div class="sub">مندوب #${safe(r.driverId)} ${r.senderReference ? '• من: ' + safe(r.senderReference) : ''}</div>
        <div class="sub">${statusBadge(r.status)} • ${new Date(r.createdAt).toLocaleString('ar-EG')}</div>
        <div class="docs" style="margin-top:10px">${proof}</div>
      </div>
      <div class="actions">${actions}</div>
    </div>`;
}

async function reviewTopup(id, action) {
  let adminNote;
  if (action === 'reject') { adminNote = prompt('سبب الرفض:') || undefined; }
  try {
    const r = await api(`/admin/payments/topup-requests/${id}/${action}`, { method: 'PATCH', body: { adminNote } });
    toast(action === 'approve' ? `تم توثيق الشحن. الرصيد الجديد: ${r.newBalance} ج.م` : 'تم رفض الطلب');
    loadTopups();
  } catch (e) { toast(e.message, 'bad'); }
}

async function manualCredit() {
  const driverId = Number($('creditDriver').value), amount = Number($('creditAmount').value);
  if (!driverId || !amount) { toast('أدخل رقم المندوب والمبلغ', 'bad'); return; }
  try {
    const r = await api(`/admin/payments/drivers/${driverId}/credit`, { method: 'PATCH', body: { amount, note: 'شحن يدوي من لوحة الإدارة' } });
    toast(`تم. الرصيد الجديد: ${r.newBalance} ج.م`);
    $('creditDriver').value = ''; $('creditAmount').value = '';
  } catch (e) { toast(e.message, 'bad'); }
}

/* ---------- settings ---------- */
async function renderSettings() {
  try {
    const list = await api('/admin/settings');
    $('pageBody').innerHTML = `
      <div class="card"><h3>إعدادات التسعير والدفع</h3>
        <p class="muted">عدّل أي قيمة ثم اضغط حفظ. تُطبَّق فوراً على التطبيق.</p>
        <div class="settings-grid" style="margin-top:16px">
          ${list.map(settingField).join('')}
        </div>
      </div>`;
  } catch (e) { $('pageBody').innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`; }
}

function settingField(s) {
  const safe = (v) => escapeHtml(v == null ? '' : String(v));
  return `
    <div class="field">
      <label title="${safe(s.key)}">${safe(s.description || s.key)}</label>
      <span style="display:flex; gap:8px">
        <input id="set_${safe(s.key)}" value="${safe(s.value)}" style="max-width:160px" />
        <button class="btn btn-sm btn-primary" data-act="save-setting" data-key="${safe(s.key)}">حفظ</button>
      </span>
    </div>`;
}

async function saveSetting(key) {
  try {
    await api(`/admin/settings/${key}`, { method: 'PATCH', body: { value: $(`set_${key}`).value } });
    toast('تم الحفظ');
  } catch (e) { toast(e.message, 'bad'); }
}

/* ---------- order inspection ----------
   Part 3 lists this as an admin MUST-HAVE, and the job is answering a
   complaint: what was this order, who took it, what moved, and was any of it
   cancelled. Read-only — every way an order can change has its own route with
   its own rules, and a write button here would skip all of them. */
const ORDER_PAGE = 50;
let ordersOffset = 0;

function renderOrders() {
  ordersOffset = 0;
  $('pageBody').innerHTML = `
    <div id="orderList"></div>
    <div class="filters" style="margin-top:12px">
      <button class="btn btn-sm" data-act="orders-page" data-dir="-1">السابق</button>
      <span id="ordersRange" class="muted"></span>
      <button class="btn btn-sm" data-act="orders-page" data-dir="1">التالي</button>
    </div>`;
  loadOrders();
}

async function loadOrders() {
  try {
    const data = await api(`/admin/orders?limit=${ORDER_PAGE}&offset=${ordersOffset}`);
    const rows = data.orders || [];
    $('ordersRange').textContent =
      `${data.offset + 1}–${data.offset + rows.length} من ${data.total}`;
    $('orderList').innerHTML = rows.length
      ? rows.map(orderRow).join('')
      : '<div class="empty">لا توجد طلبات</div>';
  } catch (e) {
    $('orderList').innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`;
  }
}

function pageOrders(dir) {
  const next = ordersOffset + dir * ORDER_PAGE;
  if (next < 0) return;
  ordersOffset = next;
  loadOrders();
}

const money = (v) => `${Number(v ?? 0).toFixed(2)} ج.م`;

function orderRow(o) {
  const safe = (v) => escapeHtml(v == null ? '' : String(v));
  return `
    <div class="row">
      <div class="grow">
        <div class="name">FL-${Number(o.id)} ${statusBadge(o.status)}</div>
        <div class="sub">👤 ${safe(o.customerName)} • 📞 ${safe(o.customerPhone)}</div>
        <div class="sub">🚚 ${o.acceptedDriverId ? 'كابتن #' + Number(o.acceptedDriverId) : 'لم يُسند بعد'}
          • توصيل ${money(o.finalDeliveryFee)} • مشتريات ${money(o.itemsPrice)}</div>
      </div>
      <div class="actions">
        <button class="btn btn-sm" data-act="order-detail" data-id="${Number(o.id)}">تفاصيل</button>
      </div>
    </div>
    <div id="orderDetail_${Number(o.id)}"></div>`;
}

async function showOrderDetail(id) {
  const host = $(`orderDetail_${id}`);
  if (!host) return;
  if (host.innerHTML) { host.innerHTML = ''; return; } // second click closes

  host.innerHTML = '<div class="empty">جاري التحميل...</div>';
  try {
    const d = await api(`/admin/orders/${id}`);
    const safe = (v) => escapeHtml(v == null ? '' : String(v));

    const items = (d.items || []).length
      ? d.items.map((i) =>
          `<div class="sub">• ${safe(i.name)} ×${Number(i.quantity ?? 1)} — ${money(i.price)}</div>`).join('')
      : '<div class="sub muted">لا توجد أصناف مسجّلة</div>';

    // The ledger is shown as written, not recalculated: what the driver was
    // charged is whatever wallet_transactions says.
    const ledger = (d.transactions || []).length
      ? d.transactions.map((t) =>
          `<div class="sub">• ${safe(t.type)} ${money(t.amount)} — <span class="muted">${safe(t.reference)}</span></div>`).join('')
      : '<div class="sub muted">لا توجد حركات محفظة على هذا الطلب</div>';

    const cancels = (d.cancellations || []).length
      ? d.cancellations.map((c) =>
          `<div class="sub">• ${safe(c.requestedByRole)} — ${safe(c.status)} — غرامة ${money(c.penaltyAmount)}
             ${c.penaltyReference ? '' : '<span class="muted">(بدون خصم)</span>'}</div>`).join('')
      : '<div class="sub muted">لا يوجد إلغاء على هذا الطلب</div>';

    host.innerHTML = `
      <div class="row" style="background:#f8fafc">
        <div class="grow">
          <div class="sub"><strong>العنوان:</strong> ${safe(d.order.deliveryAddressText)}</div>
          <div class="sub"><strong>الوصف:</strong> ${safe(d.order.itemsDescription)}</div>
          <div class="sub" style="margin-top:8px"><strong>الأصناف</strong></div>${items}
          <div class="sub" style="margin-top:8px"><strong>حركات المحفظة</strong></div>${ledger}
          <div class="sub" style="margin-top:8px"><strong>الإلغاء</strong></div>${cancels}
        </div>
      </div>`;
  } catch (e) {
    host.innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`;
  }
}

/* ---------- cancellation review ----------
   The queue an admin actually works is appeals waiting on a decision. The
   evidence is the order chat, which is why nothing is duplicated onto the
   cancellation row — see order-cancellation.service.ts. */
function renderCancellations() {
  $('pageBody').innerHTML = `
    <div class="filters">
      <select id="fAppeal">
        <option value="pending">اعتراضات بانتظار المراجعة</option>
        <option value="">كل السجلات</option>
        <option value="upheld">تم تأييد الغرامة</option>
        <option value="refunded">تم رد الغرامة</option>
      </select>
    </div>
    <div id="cancelList"></div>`;
  $('fAppeal').onchange = loadCancellations;
  loadCancellations();
}

async function loadCancellations() {
  const appealStatus = $('fAppeal').value;
  const q = appealStatus ? `?appealStatus=${encodeURIComponent(appealStatus)}` : '';
  try {
    const data = await api(`/admin/cancellations${q}`);
    const rows = data.requests || [];
    $('cancelList').innerHTML = rows.length
      ? rows.map(cancelRow).join('')
      : '<div class="empty">لا توجد سجلات</div>';
  } catch (e) {
    $('cancelList').innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`;
  }
}

function cancelRow(c) {
  const safe = (v) => escapeHtml(v == null ? '' : String(v));
  const who = c.requestedByRole === 'customer' ? 'العميل' : 'الكابتن';
  // Only a cancellation that actually charged can be refunded; approving a
  // customer's request charges nothing (Q-B3), so there is nothing to give back.
  const refundable = c.appealStatus === 'pending' && c.penaltyReference;
  return `
    <div class="row">
      <div class="grow">
        <div class="name">طلب FL-${Number(c.orderId)} <span class="muted">(بدأه ${safe(who)})</span></div>
        <div class="sub">السبب: ${safe(c.reason)}</div>
        <div class="sub">الغرامة: ${money(c.penaltyAmount)}
          ${c.penaltyReference ? `<span class="muted">${safe(c.penaltyReference)}</span>` : '<span class="muted">(لم تُخصم)</span>'}</div>
        ${c.appealReason ? `<div class="sub">اعتراض الكابتن: ${safe(c.appealReason)}</div>` : ''}
        <div class="sub">حالة الاعتراض: ${safe(c.appealStatus)}</div>
      </div>
      <div class="actions">
        ${refundable ? `
          <button class="btn btn-sm btn-green" data-act="cancel-review" data-id="${Number(c.id)}" data-decision="refund">رد الغرامة</button>
          <button class="btn btn-sm btn-red" data-act="cancel-review" data-id="${Number(c.id)}" data-decision="uphold">تأييد الغرامة</button>
        ` : '<span class="muted">لا إجراء مطلوب</span>'}
      </div>
    </div>`;
}

/* Ids with a review in flight — a refund is money, and a double click must
   never become two requests. The server's unique reference would reject the
   second anyway; this stops it being sent. */
const reviewInFlight = new Set();

async function reviewCancellation(id, decision) {
  if (reviewInFlight.has(id)) return;
  const note = prompt(decision === 'refund' ? 'سبب رد الغرامة:' : 'سبب تأييد الغرامة:');
  if (note === null) return;

  reviewInFlight.add(id);
  try {
    await api(`/admin/cancellations/${id}/${decision}`, { method: 'POST', body: { note } });
    toast(decision === 'refund' ? 'تم رد الغرامة للكابتن' : 'تم تأييد الغرامة');
    loadCancellations();
  } catch (e) {
    toast(e.message, 'bad');
  } finally {
    reviewInFlight.delete(id);
  }
}

/* ---------- catalog ----------
   Admin-managed by design: merchants register but do not get a dashboard in
   V1, so this is the only way a menu gets built. */
function renderCatalog() {
  $('pageBody').innerHTML = `
    <div class="filters">
      <select id="catMerchant"><option value="">اختر متجراً…</option></select>
    </div>
    <div id="catalogBody"><div class="empty">اختر متجراً لعرض الكتالوج</div></div>`;
  loadCatalogMerchants();
}

async function loadCatalogMerchants() {
  try {
    const list = await api('/merchants');
    $('catMerchant').innerHTML = '<option value="">اختر متجراً…</option>' +
      list.map((m) =>
        `<option value="${Number(m.id)}">${escapeHtml(m.storeName)}</option>`).join('');
    $('catMerchant').onchange = () => loadCatalog(Number($('catMerchant').value));
  } catch (e) {
    $('catalogBody').innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`;
  }
}

async function loadCatalog(merchantId) {
  if (!merchantId) {
    $('catalogBody').innerHTML = '<div class="empty">اختر متجراً لعرض الكتالوج</div>';
    return;
  }
  $('catalogBody').innerHTML = '<div class="empty">جاري التحميل...</div>';
  try {
    const menu = await api(`/admin/catalog/merchants/${merchantId}/menu`);
    const safe = (v) => escapeHtml(v == null ? '' : String(v));
    const categories = menu.categories || [];
    const products = menu.products || [];

    const catOptions = categories
      .map((c) => `<option value="${Number(c.id)}">${safe(c.name)}</option>`).join('');

    const productRows = products.length
      ? products.map((p) => `
          <div class="row">
            <div class="grow">
              <div class="name">${safe(p.name)}</div>
              <div class="sub">${money(p.price)} • ${p.isAvailable === false ? 'غير متاح' : 'متاح'}</div>
            </div>
            <div class="actions">
              <button class="btn btn-sm" data-act="product-price" data-id="${Number(p.id)}" data-merchant="${Number(merchantId)}">تعديل السعر</button>
              <button class="btn btn-sm ${p.isAvailable === false ? 'btn-green' : 'btn-amber'}"
                      data-act="product-availability" data-id="${Number(p.id)}"
                      data-merchant="${Number(merchantId)}"
                      data-available="${p.isAvailable === false ? '1' : '0'}">
                ${p.isAvailable === false ? 'إتاحة' : 'إيقاف'}
              </button>
            </div>
          </div>`).join('')
      : '<div class="empty">لا توجد أصناف بعد</div>';

    $('catalogBody').innerHTML = `
      <div class="row">
        <div class="grow">
          <div class="name">إضافة قسم</div>
          <input id="newCatName" placeholder="اسم القسم" style="max-width:220px" />
        </div>
        <div class="actions">
          <button class="btn btn-sm btn-primary" data-act="add-category" data-merchant="${Number(merchantId)}">إضافة</button>
        </div>
      </div>
      <div class="row">
        <div class="grow">
          <div class="name">إضافة صنف</div>
          <span style="display:flex; gap:8px; flex-wrap:wrap; margin-top:6px">
            <input id="newProdName" placeholder="اسم الصنف" style="max-width:200px" />
            <input id="newProdPrice" type="number" step="0.01" min="0" placeholder="السعر" style="max-width:110px" />
            <select id="newProdCat"><option value="">بدون قسم</option>${catOptions}</select>
          </span>
        </div>
        <div class="actions">
          <button class="btn btn-sm btn-primary" data-act="add-product" data-merchant="${Number(merchantId)}">إضافة</button>
        </div>
      </div>
      <h3 style="margin:16px 0 8px">الأصناف</h3>
      ${productRows}`;
  } catch (e) {
    $('catalogBody').innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`;
  }
}

async function addCategory(merchantId) {
  const name = $('newCatName').value.trim();
  if (!name) { toast('اكتب اسم القسم', 'bad'); return; }
  try {
    await api('/admin/catalog/categories', { method: 'POST', body: { merchantId, name } });
    toast('تمت إضافة القسم');
    loadCatalog(merchantId);
  } catch (e) { toast(e.message, 'bad'); }
}

async function addProduct(merchantId) {
  const name = $('newProdName').value.trim();
  const price = Number($('newProdPrice').value);
  const categoryId = $('newProdCat').value ? Number($('newProdCat').value) : undefined;
  if (!name) { toast('اكتب اسم الصنف', 'bad'); return; }
  if (!Number.isFinite(price) || price < 0) { toast('السعر غير صحيح', 'bad'); return; }
  try {
    await api('/admin/catalog/products', {
      method: 'POST',
      body: { merchantId, name, price, ...(categoryId ? { categoryId } : {}) },
    });
    toast('تمت إضافة الصنف');
    loadCatalog(merchantId);
  } catch (e) { toast(e.message, 'bad'); }
}

async function editProductPrice(id, merchantId) {
  const raw = prompt('السعر الجديد:');
  if (raw === null) return;
  const price = Number(raw);
  if (!Number.isFinite(price) || price < 0) { toast('السعر غير صحيح', 'bad'); return; }
  try {
    await api(`/admin/catalog/products/${id}`, { method: 'PATCH', body: { price } });
    toast('تم تحديث السعر');
    loadCatalog(merchantId);
  } catch (e) { toast(e.message, 'bad'); }
}

async function setProductAvailability(id, merchantId, isAvailable) {
  try {
    await api(`/admin/catalog/products/${id}`, { method: 'PATCH', body: { isAvailable } });
    toast(isAvailable ? 'تمت إتاحة الصنف' : 'تم إيقاف الصنف');
    loadCatalog(merchantId);
  } catch (e) { toast(e.message, 'bad'); }
}

/* ---------- zones and rates ----------
   The delivery fee comes from this table and nowhere else — bidding was
   removed precisely so there is one pricing authority. Editing here changes
   what every future order is quoted. */
function renderZones() {
  $('pageBody').innerHTML = '<div id="zonesBody"><div class="empty">جاري التحميل...</div></div>';
  loadZones();
}

async function loadZones() {
  try {
    const [zones, rates] = await Promise.all([
      api('/zones?all=true'),
      api('/zones/rates'),
    ]);
    const safe = (v) => escapeHtml(v == null ? '' : String(v));
    const byId = Object.fromEntries(zones.map((z) => [z.id, z.name]));

    const zoneRows = zones.length
      ? zones.map((z) => `
          <div class="row">
            <div class="grow">
              <div class="name">${safe(z.name)} <span class="muted">${safe(z.city)}</span></div>
              <div class="sub">${z.isActive === false ? 'غير مفعّلة' : 'مفعّلة'}</div>
            </div>
            <div class="actions">
              <button class="btn btn-sm ${z.isActive === false ? 'btn-green' : 'btn-amber'}"
                      data-act="zone-active" data-id="${Number(z.id)}"
                      data-active="${z.isActive === false ? '1' : '0'}">
                ${z.isActive === false ? 'تفعيل' : 'إيقاف'}
              </button>
            </div>
          </div>`).join('')
      : '<div class="empty">لا توجد مناطق</div>';

    const rateRows = rates.length
      ? rates.map((r) => `
          <div class="row">
            <div class="grow">
              <div class="name">${safe(byId[r.pickupZoneId] || r.pickupZoneId)} ← ${safe(byId[r.dropoffZoneId] || r.dropoffZoneId)}</div>
              <div class="sub">${money(r.deliveryFee)}${r.estimatedMinutes ? ` • ~${Number(r.estimatedMinutes)} دقيقة` : ''}</div>
            </div>
          </div>`).join('')
      : '<div class="empty">لا توجد أسعار بين المناطق</div>';

    const zoneOptions = zones
      .map((z) => `<option value="${Number(z.id)}">${safe(z.name)}</option>`).join('');

    $('zonesBody').innerHTML = `
      <div class="row">
        <div class="grow">
          <div class="name">إضافة منطقة</div>
          <span style="display:flex; gap:8px; flex-wrap:wrap; margin-top:6px">
            <input id="newZoneName" placeholder="اسم المنطقة" style="max-width:200px" />
            <input id="newZoneCity" placeholder="المدينة" style="max-width:160px" />
          </span>
        </div>
        <div class="actions"><button class="btn btn-sm btn-primary" data-act="add-zone">إضافة</button></div>
      </div>
      <h3 style="margin:16px 0 8px">المناطق</h3>
      ${zoneRows}
      <div class="row" style="margin-top:16px">
        <div class="grow">
          <div class="name">إضافة سعر بين منطقتين</div>
          <span style="display:flex; gap:8px; flex-wrap:wrap; margin-top:6px">
            <select id="rateFrom">${zoneOptions}</select>
            <select id="rateTo">${zoneOptions}</select>
            <input id="rateFee" type="number" step="0.01" min="0" placeholder="الرسوم" style="max-width:110px" />
            <input id="rateMins" type="number" min="0" placeholder="دقائق (اختياري)" style="max-width:140px" />
          </span>
        </div>
        <div class="actions"><button class="btn btn-sm btn-primary" data-act="add-rate">إضافة</button></div>
      </div>
      <h3 style="margin:16px 0 8px">الأسعار</h3>
      ${rateRows}`;
  } catch (e) {
    $('zonesBody').innerHTML = `<div class="empty">${escapeHtml(e.message)}</div>`;
  }
}

async function addZone() {
  const name = $('newZoneName').value.trim();
  const city = $('newZoneCity').value.trim();
  if (!name || !city) { toast('اكتب اسم المنطقة والمدينة', 'bad'); return; }
  try {
    await api('/zones', { method: 'POST', body: { name, city } });
    toast('تمت إضافة المنطقة');
    loadZones();
  } catch (e) { toast(e.message, 'bad'); }
}

async function setZoneActive(id, isActive) {
  try {
    await api(`/zones/${id}`, { method: 'PATCH', body: { isActive } });
    toast(isActive ? 'تم تفعيل المنطقة' : 'تم إيقاف المنطقة');
    loadZones();
  } catch (e) { toast(e.message, 'bad'); }
}

async function addRate() {
  const pickupZoneId = Number($('rateFrom').value);
  const dropoffZoneId = Number($('rateTo').value);
  const deliveryFee = Number($('rateFee').value);
  const minutes = $('rateMins').value;
  if (!Number.isFinite(deliveryFee) || deliveryFee < 0) {
    toast('الرسوم غير صحيحة', 'bad');
    return;
  }
  try {
    await api('/zones/rates', {
      method: 'POST',
      body: {
        pickupZoneId, dropoffZoneId, deliveryFee,
        ...(minutes ? { estimatedMinutes: Number(minutes) } : {}),
      },
    });
    toast('تمت إضافة السعر');
    loadZones();
  } catch (e) { toast(e.message, 'bad'); }
}

/* ---------- delegated actions (CP-E / S8) ----------
   Every button used to carry its own `onclick="fn(...)"`. That needs
   script-src 'unsafe-inline', which would have made the CSP decorative: the
   panel renders admin-supplied text (store names, admin notes, rejection
   reasons) into HTML, and permitting inline script means a single missed
   escapeHtml is executable. One listener, and the attributes become data.

   It also removes a latent hazard of its own — those handlers interpolated
   values straight into a JavaScript context, where HTML escaping is the wrong
   escaping. Nothing exploited it because every interpolated value was a
   number, but that was a property of the callers, not a guarantee. */
document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-act]');
  if (!el) return;
  const d = el.dataset;

  switch (d.act) {
    case 'lightbox':
      showImage(el.src);
      break;
    case 'review-reg':
      reviewReg(Number(d.id), d.status, d.ask === '1');
      break;
    case 'review-topup':
      reviewTopup(Number(d.id), d.action);
      break;
    case 'manual-credit':
      manualCredit();
      break;
    case 'save-setting':
      saveSetting(d.key);
      break;
    case 'merchant-availability':
      setMerchantAvailability(Number(d.id), d.open === '1');
      break;
    case 'orders-page':
      pageOrders(Number(d.dir));
      break;
    case 'order-detail':
      showOrderDetail(Number(d.id));
      break;
    case 'cancel-review':
      reviewCancellation(Number(d.id), d.decision);
      break;
    case 'add-category':
      addCategory(Number(d.merchant));
      break;
    case 'add-product':
      addProduct(Number(d.merchant));
      break;
    case 'product-price':
      editProductPrice(Number(d.id), Number(d.merchant));
      break;
    case 'product-availability':
      setProductAvailability(Number(d.id), Number(d.merchant), d.available === '1');
      break;
    case 'add-zone':
      addZone();
      break;
    case 'zone-active':
      setZoneActive(Number(d.id), d.active === '1');
      break;
    case 'add-rate':
      addRate();
      break;
  }
});

// The lightbox closes on a click anywhere on its backdrop. It is in the static
// HTML rather than rendered, so it gets its own listener instead of data-act.
$('lightbox').addEventListener('click', () =>
  $('lightbox').classList.add('hidden'),
);

/* ---------- boot ---------- */
