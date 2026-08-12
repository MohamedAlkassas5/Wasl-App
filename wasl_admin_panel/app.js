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
  `<img class="doc-thumb" data-doc="${String(p).replace(/"/g, '&quot;')}" alt="مستند" onclick="showImage(this.src)" />`;

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
  topups: 'طلبات شحن المحفظة', settings: 'إعدادات النظام' };

function route(name) {
  document.querySelectorAll('.nav-item').forEach((el) =>
    el.classList.toggle('active', el.dataset.route === name));
  $('pageTitle').textContent = TITLES[name];
  $('pageBody').innerHTML = '<div class="empty">جاري التحميل...</div>';
  ({ dashboard: renderDashboard, registrations: renderRegistrations,
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
        <button class="btn btn-sm btn-green" onclick="reviewReg(${u.id},'active')">قبول</button>
        <button class="btn btn-sm btn-amber" onclick="reviewReg(${u.id},'pending',true)">طلب تعديل</button>
        <button class="btn btn-sm btn-red" onclick="reviewReg(${u.id},'rejected',true)">رفض</button>
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
        <button class="btn btn-primary btn-sm" style="justify-self:start" onclick="manualCredit()">إضافة رصيد</button>
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
    ? `<button class="btn btn-sm btn-green" onclick="reviewTopup(${r.id},'approve')">توثيق وإضافة الرصيد</button>
       <button class="btn btn-sm btn-red" onclick="reviewTopup(${r.id},'reject')">رفض</button>`
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
        <button class="btn btn-sm btn-primary" onclick="saveSetting('${safe(s.key)}')">حفظ</button>
      </span>
    </div>`;
}

async function saveSetting(key) {
  try {
    await api(`/admin/settings/${key}`, { method: 'PATCH', body: { value: $(`set_${key}`).value } });
    toast('تم الحفظ');
  } catch (e) { toast(e.message, 'bad'); }
}

/* ---------- boot ---------- */
