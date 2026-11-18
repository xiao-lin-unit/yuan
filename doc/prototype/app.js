// ============ Tab 切换（5个模块） ============
function switchTab(tab) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));

  const map = {
    'transaction': 'page-transaction',
    'asset-liability': 'page-asset-liability',
    'account': 'page-account',
    'analyze': 'page-analyze',
    'mine': 'page-mine',
    'sandbox': 'page-sandbox',
    'knowledge': 'page-knowledge',
    'result': 'page-result',
    // 账户明细
    'acc-detail-bank': 'page-acc-detail-bank',
    'acc-detail-credit': 'page-acc-detail-credit',
    'acc-detail-gjj': 'page-acc-detail-gjj',
    // 资产明细
    'asset-detail-stock': 'page-asset-detail-stock',
    'asset-detail-fund': 'page-asset-detail-fund',
    'asset-detail-normal': 'page-asset-detail-normal',
    // 负债明细
    'liability-detail-car': 'page-liability-detail-car',
    'liability-detail-credit': 'page-liability-detail-credit',
    'liability-detail-friend': 'page-liability-detail-friend',
    // 分类管理
    'category-management': 'page-category-management'
  };
  const pageId = map[tab];
  if (pageId) document.getElementById(pageId).classList.add('active');

  const tabEl = document.querySelector('.tab[data-tab="' + tab + '"]');
  if (tabEl) tabEl.classList.add('active');

  closeSheet();
}

// ============ 收支：支出/收入切换 ============
function switchType(type) {
  document.querySelectorAll('.type-tab').forEach(t => t.classList.remove('active'));
  document.querySelector('.type-tab[data-type="' + type + '"]').classList.add('active');

  const accLabel = document.getElementById('field-account-label');
  const catLabel = document.getElementById('field-type-label');
  const catTitle = document.getElementById('sheet-cat-title');
  const accTitle = document.getElementById('account-sheet-title');
  const accHint = document.getElementById('account-sheet-hint');
  const display = document.getElementById('amount-display');

  if (type === 'income') {
    accLabel.textContent = '收款账户';
    catLabel.textContent = '收入分类';
    catTitle.textContent = '选择收入分类';
    accTitle.textContent = '选择收款账户';
    accHint.textContent = '收入入账后会增加该账户余额。';
    display.style.color = 'var(--green)';
  } else {
    accLabel.textContent = '支出账户';
    catLabel.textContent = '支出分类';
    catTitle.textContent = '选择支出分类';
    accTitle.textContent = '选择支出账户';
    accHint.textContent = '受限账户仅可用于被允许的支出分类。';
    display.style.color = 'var(--red)';
  }
}

// ============ 资债：资产/负债切换 ============
let azCurrentView = 'asset';
function switchAZ(view) {
  azCurrentView = view;
  document.querySelectorAll('.az-tab').forEach(t => t.classList.remove('active'));
  document.querySelector('.az-tab[onclick*="' + view + '"]').classList.add('active');

  // 切类型时把搜索收起来，否则两个视图会同时露出来
  const sb = document.getElementById('az-searchbox');
  const si = document.getElementById('az-search-input');
  if (sb) sb.style.display = 'none';
  if (si) si.value = '';

  document.getElementById('view-asset').style.display = view === 'asset' ? 'block' : 'none';
  document.getElementById('view-liability').style.display = view === 'liability' ? 'block' : 'none';
  document.getElementById('view-az-search').style.display = 'none';
  renderAZ();
}

// ============ 从资产/负债明细返回时，保持原来的 Tab ============
function switchAZret(view) {
  switchTab('asset-liability');
  switchAZ(view);
}

// ============ 数字键盘 ============
let currentAmount = '0';
function inputNum(num) {
  if (num === '.' && currentAmount.includes('.')) return;
  if (currentAmount === '0' && num !== '.') {
    currentAmount = num;
  } else {
    if (currentAmount.replace('.', '').length >= 10) return;
    currentAmount += num;
  }
  renderAmount();
}
function delNum() {
  if (currentAmount.length <= 1) {
    currentAmount = '0';
  } else {
    currentAmount = currentAmount.slice(0, -1);
  }
  renderAmount();
}
function clearNum() {
  currentAmount = '0';
  renderAmount();
}
function renderAmount() {
  document.getElementById('amount-display').textContent = currentAmount;
}

// ============ 保存收支 ============
function saveRecord() {
  const val = parseFloat(currentAmount);
  if (!val || val <= 0) return;
  const type = document.querySelector('.type-tab.active').dataset.type;
  const account = document.getElementById('field-account').textContent.replace(' ›', '');
  const category = document.getElementById('field-category').textContent.replace(' ›', '');
  const typeName = type === 'income' ? '收入' : '支出';

  const record = document.createElement('div');
  record.className = 'record-item slide-in';
  record.innerHTML =
    '<span class="rc-icon">' + (type === 'income' ? '💰' : '🍚') + '</span>' +
    '<span class="rc-info">新增' + typeName + '：' + category + '<small>' + account + '</small></span>' +
    '<span class="rc-amount ' + (type === 'income' ? 'green' : 'red') + '">' +
    (type === 'income' ? '+' : '-') + '¥' + formatNum(val) + '</span>';
  document.querySelector('.numpad').before(record);

  currentAmount = '0';
  renderAmount();
  flashBtn();
}

function formatNum(n) {
  return n.toLocaleString('zh-CN', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}

function flashBtn() {
  const btn = document.querySelector('.btn-primary');
  if (!btn) return;
  const old = btn.textContent;
  btn.textContent = '✓ 已保存';
  btn.style.background = 'var(--green)';
  setTimeout(() => {
    btn.textContent = old;
    btn.style.background = '';
  }, 1200);
}

// ============ 弹层 ============
function openSheet(id) {
  closeSheet();
  const sheet = document.getElementById(id);
  if (!sheet) return;
  document.getElementById('sheet-mask').classList.add('show');
  sheet.classList.add('show');
  // 资债页的几个弹层每次打开都重算，避免显示旧数
  if (id === 'leverage-sheet') renderLeverageSheet();
  if (id === 'gap-sheet') renderGapSheet();
  if (id === 'payoff-sheet') renderPayoffSheet();
  if (id === 'prepay-sheet') renderPrepaySheet();
}
function closeSheet() {
  document.getElementById('sheet-mask').classList.remove('show');
  document.querySelectorAll('.sheet').forEach(sh => sh.classList.remove('show'));
}

// ============ 选分类 ============
function selectCategory(name) {
  document.getElementById('field-category').textContent = name.replace(/^.+? /, '') + ' ›';
  closeSheet();
}

// ============ 选账户（受限账户提示） ============
function selectAccount(name) {
  const field = document.getElementById('field-account');
  field.textContent = name + ' ›';
  if (name === '医保账户' || name === '公积金') {
    field.classList.add('warn-text');
  } else {
    field.classList.remove('warn-text');
  }
  closeSheet();
}

// ============ 推演 ============
function runSimulation() {
  closeSheet();
  switchTab('result');
}

function saveSimulation() {
  const btn = event.target;
  const old = btn.textContent;
  btn.textContent = '✓ 已保存';
  setTimeout(() => { btn.textContent = old; switchTab('sandbox'); }, 1000);
}

// ============ 修改用户信息 ============
const AVATAR_MAX_SIZE = 2 * 1024 * 1024;              // 2MB
const AVATAR_MAX_EDGE = 1080;                          // 最长边压缩上限
const AVATAR_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

let userProfile = { name: '未设置名字', intro: '', avatar: '' };
let pendingAvatar = null;   // 本次弹层中待保存的头像（dataURL）

function userInfoBlock(id) {
  return document.getElementById(id).closest('.form-block');
}

// 打开弹层时回填当前信息
function openUserInfoSheet() {
  pendingAvatar = userProfile.avatar;
  document.getElementById('uname-input').value = userProfile.name === '未设置名字' ? '' : userProfile.name;
  document.getElementById('uintro-input').value = userProfile.intro;
  document.querySelectorAll('#userinfo-sheet .form-block').forEach(b => b.classList.remove('invalid'));
  renderAvatarPreview();
  countUserInfo();
  openSheet('userinfo-sheet');
}

function pickAvatar() {
  document.getElementById('avatar-input').click();
}

function onAvatarPicked(e) {
  const file = e.target.files && e.target.files[0];
  e.target.value = '';                                 // 允许重复选同一张
  if (!file) return;

  const tip = document.getElementById('avatar-tip');
  if (AVATAR_TYPES.indexOf(file.type) === -1) {
    tip.textContent = '格式不支持，请选 JPG / PNG / WEBP';
    return;
  }
  if (file.size > AVATAR_MAX_SIZE) {
    tip.textContent = '图片超过 2MB，换一张小一点的';
    return;
  }
  const reader = new FileReader();
  reader.onload = () => compressImage(reader.result, dataUrl => {
    pendingAvatar = dataUrl;
    renderAvatarPreview();
  });
  reader.readAsDataURL(file);
}

// 正方裁切 + 压缩，避免原图过大占用本地存储
function compressImage(dataUrl, done) {
  const img = new Image();
  img.onload = () => {
    const side = Math.min(img.width, img.height);
    const scale = Math.min(1, AVATAR_MAX_EDGE / side);
    const size = Math.round(side * scale);
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, (img.width - side) / 2, (img.height - side) / 2, side, side, 0, 0, size, size);
    done(canvas.toDataURL('image/jpeg', 0.85));
  };
  img.src = dataUrl;
}

function renderAvatarPreview() {
  const box = document.getElementById('avatar-preview');
  const tip = document.getElementById('avatar-tip');
  box.innerHTML = pendingAvatar ? '<img src="' + pendingAvatar + '" alt="头像">' : '👤';
  tip.textContent = pendingAvatar ? '点击重新上传' : '点击上传头像';
  tip.classList.toggle('done', !!pendingAvatar);
}

function countUserInfo() {
  document.getElementById('uname-count').textContent = document.getElementById('uname-input').value.length;
  document.getElementById('uintro-count').textContent = document.getElementById('uintro-input').value.length;
}

document.getElementById('uname-input').addEventListener('input', () => {
  userInfoBlock('uname-input').classList.remove('invalid');
  countUserInfo();
});
document.getElementById('uintro-input').addEventListener('input', () => {
  userInfoBlock('uintro-input').classList.remove('invalid');
  countUserInfo();
});

function saveUserInfo() {
  const nameInput = document.getElementById('uname-input');
  const introInput = document.getElementById('uintro-input');
  const name = nameInput.value.trim();
  const intro = introInput.value.trim();
  let ok = true;

  if (name.length < 1 || name.length > 12) { userInfoBlock('uname-input').classList.add('invalid'); ok = false; }
  if (intro.length > 60) { userInfoBlock('uintro-input').classList.add('invalid'); ok = false; }
  if (!ok) return;

  userProfile = { name: name, intro: intro, avatar: pendingAvatar || '' };

  const nameEl = document.getElementById('user-name');
  const avaEl = document.getElementById('user-avatar');
  nameEl.textContent = userProfile.name;
  if (userProfile.avatar) {
    avaEl.classList.add('photo');
    avaEl.innerHTML = '<img src="' + userProfile.avatar + '" alt="头像">';
  } else {
    avaEl.classList.remove('photo');
    avaEl.textContent = '👤';
  }
  closeSheet();
  flashBtn();
}

// 首次引导
window.addEventListener('DOMContentLoaded', () => {
  initCategories();                 // 先把预设分类铺好，记账弹层要用
  renderCategoryList();            // 分类管理页初始化
  renderAccountHero();             // 账户页合计
  renderAccountList();             // 账户页列表
  initAccHeroDots();
  renderAZ();                      // 资债页：所有数字由明细算出来
  setTimeout(() => openSheet('onboard-sheet'), 400);
});

// ==================== 账户页：搜索 / 筛选 / 排序 / 折叠 ====================
// 账户一多就滑不动，所以这一页不给"一列到底"：
// 合计横滑 + 类型快筛 + 搜索 + 分段折叠 + 多种排序，任一手段都能少滑一半以上
const ACCOUNTS = [
  { id:'wx',    name:'微信零钱',   sub:'日常消费',              icon:'💬', group:'liquid', balance:2150,  top:false, order:0 },
  { id:'alipay',name:'支付宝',     sub:'日常消费',              icon:'💙', group:'liquid', balance:1000,  top:false, order:1 },
  { id:'cash',  name:'现金',       sub:'日常消费',              icon:'💵', group:'liquid', balance:300,   top:false, order:2 },
  { id:'icbc',  name:'工商储蓄卡', sub:'工资卡 / 还款账户',     icon:'🏦', group:'liquid', balance:5800,  top:true,  order:3 },
  { id:'cmb',   name:'招商信用卡', sub:'总额度 ¥10,000 · 已用 ¥6,800', icon:'💳', group:'credit',
    balance:6800, top:true, order:4, badge:'还款日25号', limit:10000, used:6800 },
  { id:'yibao', name:'医保账户',   sub:'🔒 仅限医疗相关用途',   icon:'🏥', group:'locked', balance:1200,  top:false, order:5 },
  { id:'gjj',   name:'公积金',     sub:'🔒 仅限租房 / 装修 / 买房', icon:'🏠', group:'locked', balance:28000, top:false, order:6 }
];

const GROUP_META = {
  top:    { label:'📌 常用账户', hint:'置顶的账户，打开就先看到' },
  liquid: { label:'💳 流动资金账户', hint:'钱能自由花' },
  credit: { label:'💰 信用卡账户', hint:'是花银行的钱，要还' },
  locked: { label:'🔒 其他资金账户（受限）', hint:'有特定用途，不能随便花' }
};

let accFilter = 'all';
let accSort = 'balance';
let accCollapsed = {};          // 记录哪几段被折叠了
let accDragId = null;

function formatMoney(n) {
  return '¥' + n.toLocaleString('zh-CN', { maximumFractionDigits: 0 });
}

// 合计按"当前显示的账户"实时算，切筛选时数字跟着变，不会出现上下对不上
function computeHero(filter) {
  const src = filter === 'all' ? ACCOUNTS : ACCOUNTS.filter(a => a.group === filter);
  const sum = g => src.filter(a => a.group === g).reduce((s, a) => s + a.balance, 0);
  const cnt = g => src.filter(a => a.group === g).length;
  return {
    liquid: { v: sum('liquid'), c: cnt('liquid') },
    credit: { v: sum('credit'), c: cnt('credit') },
    locked: { v: sum('locked'), c: cnt('locked') }
  };
}

function renderAccountHero() {
  const h = computeHero(accFilter);
  const card = document.querySelector('#acc-hero .ah-card.liquid');
  const nodes = document.querySelectorAll('#acc-hero .ah-card');
  const set = (i, cls, val, sub) => {
    const n = nodes[i];
    if (!n) return;
    n.querySelector('.ah-value').textContent = val;
    n.querySelector('.ah-sub').textContent = sub;
    n.style.display = (accFilter === 'all' || accFilter === cls) ? '' : 'none';
  };
  set(0, 'liquid', formatMoney(h.liquid.v), h.liquid.c + ' 个账户 · 随时可用');
  set(1, 'credit', formatMoney(h.credit.v),
      h.credit.c ? h.credit.c + ' 张卡 · 可用 ¥3,200 · 25 号还款' : '没有信用卡');
  set(2, 'locked', formatMoney(h.locked.v),
      h.locked.c + ' 个账户 · 需符合用途');
  if (card) card.style.display = '';
}

function setAccountFilter(f, el) {
  accFilter = f;
  document.querySelectorAll('#acc-chips .acc-chip').forEach(c => c.classList.remove('active'));
  if (el) el.classList.add('active');
  renderAccountHero();
  renderAccountList();
}

function clearAccountSearch() {
  const i = document.getElementById('acc-search-input');
  if (!i) return;
  i.value = '';
  renderAccountList();
}

function toggleAccountSort() {
  document.getElementById('acc-sort-menu').classList.toggle('show');
}

function setAccountSort(mode) {
  accSort = mode;
  document.getElementById('acc-sort-menu').classList.remove('show');
  const btn = document.getElementById('acc-sort-btn');
  btn.textContent = { balance:'余额 ▾', name:'名称 ▾', custom:'自定义 ▾' }[mode];
  document.querySelectorAll('#acc-sort-menu .sm-item').forEach(i => {
    i.classList.toggle('active', i.dataset.sort === mode);
  });
  renderAccountList();
}

function toggleAccGroup(g) {
  accCollapsed[g] = !accCollapsed[g];
  renderAccountList();
}

// 自定义顺序：拖到目标卡片上就交换 order
function onAccDrop(targetId) {
  if (!accDragId || accDragId === targetId) return;
  const a = ACCOUNTS.find(x => x.id === accDragId);
  const b = ACCOUNTS.find(x => x.id === targetId);
  if (a && b) { const t = a.order; a.order = b.order; b.order = t; }
  accDragId = null;
  renderAccountList();
}

function accountCardHtml(a) {
  const badge = a.badge ? '<span class="ac-badge warn">' + a.badge + '</span>' : '';
  const creditExtra = a.group === 'credit' && a.limit
    ? '<div class="ac-bar"><div class="ac-bar-fill" style="width:' +
      Math.round(a.used / a.limit * 100) + '%"></div></div>' : '';
  const drag = accSort === 'custom'
    ? ' draggable="true" ondragstart="accDragId=\'' + a.id + '\'" ondragend="accDragId=null" ondragover="event.preventDefault()" ondrop="onAccDrop(\'' + a.id + '\')"' : '';
  const jump = a.group === 'credit'
    ? 'onclick="switchTab(\'acc-detail-credit\')"'
    : (a.group === 'liquid' ? 'onclick="switchTab(\'acc-detail-bank\')"' : 'onclick="switchTab(\'acc-detail-gjj\')"');
  return '<div class="account-card ' + a.group + '"' + jump + drag + '>' +
    '<div class="ac-icon">' + a.icon + '</div>' +
    '<div class="ac-info"><span class="ac-name">' + a.name + '</span>' +
    '<span class="ac-sub">' + a.sub + '</span>' + creditExtra + '</div>' +
    '<div class="ac-right"><span class="ac-balance">' + formatMoney(a.balance) + '</span>' + badge + '</div>' +
    '</div>';
}

function renderAccountList() {
  const box = document.getElementById('acc-groups');
  const empty = document.getElementById('acc-empty');
  if (!box) return;

  const kw = (document.getElementById('acc-search-input').value || '').trim().toLowerCase();
  const clear = document.getElementById('acc-search-clear');
  if (clear) clear.style.display = kw ? '' : 'none';

  let list = ACCOUNTS.slice();
  if (accFilter === 'top')      list = list.filter(a => a.top);
  else if (accFilter !== 'all') list = list.filter(a => a.group === accFilter);
  if (kw) list = list.filter(a => (a.name + a.sub + a.icon).toLowerCase().indexOf(kw) > -1);

  if (accSort === 'balance')      list.sort((x, y) => y.balance - x.balance);
  else if (accSort === 'name')    list.sort((x, y) => x.name.localeCompare(y.name, 'zh-CN'));
  else                            list.sort((x, y) => x.order - y.order);

  const groups = accFilter === 'top' ? [['top', list]]
    : accFilter === 'all' && !kw
      ? [['liquid', list.filter(a => a.group === 'liquid')],
         ['credit', list.filter(a => a.group === 'credit')],
         ['locked', list.filter(a => a.group === 'locked')]]
      : [[accFilter === 'all' ? 'result' : accFilter, list]];

  const html = [];
  groups.forEach(([g, items]) => {
    if (!items.length) return;
    const isResult = g === 'result' || (kw && accFilter === 'all');
    const meta = GROUP_META[g] || { label: kw ? '🔍 搜索结果' : '账户', hint: items.length + ' 个账户' };
    const collapsed = !!accCollapsed[g] && !kw;      // 搜索时强制展开，不然会漏看
    const total = items.reduce((s, a) => s + a.balance, 0);
    html.push(
      '<div class="acc-group">' +
        '<div class="ag-head" onclick="toggleAccGroup(\'' + g + '\')">' +
          '<span class="ag-caret ' + (collapsed ? '' : 'open') + '">›</span>' +
          '<span class="ag-label">' + meta.label + '</span>' +
          '<span class="ag-count">' + items.length + '</span>' +
          '<span class="ag-sum">' + formatMoney(total) + '</span>' +
        '</div>' +
        (collapsed ? '' : '<div class="card-list">' + items.map(accountCardHtml).join('') + '</div>') +
      '</div>'
    );
  });

  box.innerHTML = html.join('');
  if (empty) empty.style.display = list.length ? 'none' : '';
}

// 合计卡横滑时同步下面的小圆点
function initAccHeroDots() {
  const hero = document.getElementById('acc-hero');
  const dots = document.querySelectorAll('#ah-dots .dot');
  if (!hero || !dots.length) return;
  hero.addEventListener('scroll', () => {
    const i = Math.round(hero.scrollLeft / (hero.clientWidth * 0.86));
    dots.forEach((d, k) => d.classList.toggle('active', k === Math.min(i, dots.length - 1)));
  });
}

// 点排序菜单外面就收起
document.addEventListener('click', e => {
  const menu = document.getElementById('acc-sort-menu');
  if (!menu) return;
  if (!e.target.closest('.acc-sort')) menu.classList.remove('show');
});

// ==================== 资债页：渲染（所有数字由 az.js 算出来） ====================
// 页面上一分钱都不写死。任何一处总数都能点开看到它是哪几笔加起来的。
let azFilter = 'all';
let azCalcOpen = false;
let azGroups = { give:true, take:true, flat:false };

function toggleAZSearch() {
  const sb = document.getElementById('az-searchbox');
  const si = document.getElementById('az-search-input');
  const show = sb.style.display === 'none';
  sb.style.display = show ? 'flex' : 'none';
  if (!show && si) { si.value = ''; renderAZ(); }
  else if (si) si.focus();
}
function clearAZSearch() {
  const si = document.getElementById('az-search-input');
  if (si) si.value = '';
  document.getElementById('view-az-search').style.display = 'none';
  if (azCurrentView === 'asset') document.getElementById('view-asset').style.display = 'block';
  else document.getElementById('view-liability').style.display = 'block';
  renderAZ();
}
function toggleAZCalc() {
  azCalcOpen = !azCalcOpen;
  document.getElementById('az-calc').style.display = azCalcOpen ? 'block' : 'none';
  document.getElementById('az-calc-caret').classList.toggle('open', azCalcOpen);
}
function toggleAZGroup(g) {
  azGroups[g] = !azGroups[g];
  document.getElementById('caret-' + g).classList.toggle('open', azGroups[g]);
  document.getElementById('list-' + g).style.display = azGroups[g] ? 'flex' : 'none';
}
function toggleValuationMode() {
  azValuationMode = azValuationMode === 'cost' ? 'latest' : 'cost';
  document.getElementById('az-valuation-btn').textContent =
    '估值口径：' + (azValuationMode === 'cost' ? '按买入价 ▾' : '按我填的最新价 ▾');
  renderAZ();
}
function setAZFilter(f, el) {
  azFilter = f;
  document.querySelectorAll('#az-chips .acc-chip').forEach(c => c.classList.remove('active'));
  if (el) el.classList.add('active');
  renderAZ();
}

// ---------- 资产卡片 ----------
function flowTagOf(a) {
  const steady = a.stability === 'fixed' ? (a.monthlyIn || 0) : 0;
  const out = (a.monthlyOut || 0) + ((a.linkDebt ? linkCostOf(a) : 0));
  const net = steady - out;
  if (net > 0) return { cls:'good', text:'每月给你 +' + money0(net) };
  if (net < 0) return { cls:'bad', text:'每月拿走 -' + money0(-net) };
  return { cls:'flat', text:'不进也不出' };
}
function linkCostOf(a) {
  const d = DEBTS.find(x => x.id === a.linkDebt);
  if (!d) return 0;
  return (d.monthlyInterest || 0) + (d.monthlyFee || 0);
}
function staleTag(a) {
  const s = staleDays(a.valuedAt);
  if (s === null) return '<span class="az-tag">按买入时算</span>';
  if (s > azStaleDays) return '<span class="az-tag warn">' + s + ' 天前填的</span>';
  return '<span class="az-tag">上次 ' + s + ' 天前填的</span>';
}
function assetCardHtml(a) {
  const t = flowTagOf(a);
  const v = assetValueOf(a);
  const diff = a.counted ? v - a.cost : 0;
  const diffTxt = (azValuationMode === 'latest' && a.value && a.value !== a.cost)
    ? '<small class="' + (diff >= 0 ? 'up' : 'down') + '">' + (diff >= 0 ? '+' : '-') + money0(Math.abs(diff)) + '</small>'
    : '';
  const sub = [a.toBe, a.stability === 'fixed' ? '每月都有' : ''].filter(Boolean).join(' · ');
  return '<div class="asset-card az-card" onclick="switchTab(\'' + (a.detail || 'asset-detail-normal') + '\')">' +
    '<span class="as-name">' + a.icon + ' ' + a.name +
      (a.code ? ' <small>' + a.code + '</small>' : '') +
      staleTag(a) + '</span>' +
    '<span class="as-value">' + (a.counted ? money0(v) : '不算进总账') + diffTxt + '</span>' +
    '<span class="az-flow ' + t.cls + '">' + t.text + '</span>' +
    (sub ? '<span class="az-subline">' + sub + '</span>' : '') +
    '</div>';
}

// ---------- 负债卡片 ----------
function debtCardHtml(d) {
  const rate = d.rateType === 'float' ? d.rate : realAnnualRate(d);
  const cost = (d.monthlyInterest || 0) + (d.monthlyFee || 0);
  const lev = leverageOf(d);
  const leftTerm = Math.max(0, d.totalTerms - d.paidTerms);
  const sub = [];
  if (d.purposeLabel) sub.push(d.purposeLabel);
  if (d.repayMethod) sub.push(d.repayMethod);
  if (leftTerm) sub.push('还剩 ' + leftTerm + ' 期');
  if (d.payDay) sub.push('每月 ' + d.payDay + ' 号还');
  if (d.status && d.status !== '正常') sub.push(d.status);

  let levLine = '';
  if (lev) {
    levLine = '<span class="az-flow ' + (lev.net >= 0 ? 'good' : 'bad') + '">' +
      (lev.net >= 0 ? '它替你付了利息，还多留 ' + money0(lev.net) : '它每月从你口袋拿走 ' + money0(-lev.net)) +
      '</span>';
  } else if (d.purpose === 'T4') {
    levLine = '<span class="az-flow warn">借来先花了再还，成本最高</span>';
  } else if (d.purpose === 'T5') {
    levLine = '<span class="az-flow flat">这是应急借的，不是乱花</span>';
  }

  return '<div class="liability-card az-card ' + (d.status === '逾期' ? 'overdue' : '') + '" onclick="openDebtDetail(\'' + d.id + '\')">' +
    '<span class="lb-name">' + d.icon + ' ' + d.name + '</span>' +
    '<span class="lb-value red">' + money0(d.principal) + '</span>' +
    '<span class="az-rate">实际一年 ' + (rate * 100).toFixed(1) + '%' +
      (d.rateType === 'float' ? '（会变）' : '') + '</span>' +
    (cost ? '<span class="az-cost">每月白给 ' + money0(cost) + '</span>' : '<span class="az-cost ok">这个月不产生利息</span>') +
    levLine +
    (sub.length ? '<span class="az-subline">' + sub.join(' · ') + '</span>' : '') +
    '</div>';
}
// 负债明细页：复用现有详情页，只有 car / credit / friend 三张现成的
function openDebtDetail(id) {
  const map = { d_car:'liability-detail-car', d_cmb:'liability-detail-credit', d_friend:'liability-detail-friend' };
  if (map[id]) { switchTab(map[id]); return; }
  _azToast('这类的明细页还没做，原型里先到「负债汇总」看它的数');
}

// ---------- 主渲染 ----------
function renderAZ() {
  const kw = (document.getElementById('az-search-input') || {}).value || '';
  const kws = kw.trim().toLowerCase();
  const searching = !!kws;

  // 顶部家底账
  const nw = netWorth();
  document.getElementById('az-networth').textContent = money(nw);
  const el = document.getElementById('az-networth-sub');
  el.textContent = nw >= 0
    ? '欠的都还完，还剩这么多'
    : '已经资不抵债了：欠的比有的多 ' + money0(-nw);
  el.className = 'tmc-sub' + (nw < 0 ? ' danger' : '');

  const layers = cashLayers();
  document.getElementById('az-cash-now').textContent = money0(layers[0].amount + layers[1].amount);
  const mi = monthlyIn(), mo = monthlyOut();
  document.getElementById('az-in').textContent = money0(mi.total);
  document.getElementById('az-out').textContent = money0(mo.total);
  const pn = passiveLeft();
  const fnet = document.getElementById('flow-net');
  fnet.textContent = (pn >= 0 ? '+' : '') + money0(pn);
  fnet.className = pn >= 0 ? 'green' : 'red';
  document.getElementById('flow-in').textContent = money0(mi.fixed);
  document.getElementById('flow-in-sub').textContent =
    '稳稳每月都有的那部分' + (mi.occ ? '（另有 ' + money0(mi.occ) + ' 偶尔才有，没算进来）' : '');
  document.getElementById('flow-out').textContent = money0(mo.total);
  document.getElementById('flow-out-sub').textContent =
    '东西的开销 ' + money0(mo.holdCost) + ' + 借款利息费用 ' + money0(mo.interest + mo.fee);

  // 展开的算法
  const a = sumAssets(), dSum = sumDebts();
  document.getElementById('calc-a1').textContent = money0(AZ_ACCOUNT_MIRROR.filter(m => m.kind === 'A1').reduce((s, m) => s + m.amount, 0));
  document.getElementById('calc-a2').textContent = money0(AZ_ACCOUNT_MIRROR.filter(m => m.kind === 'A2').reduce((s, m) => s + m.amount, 0));
  document.getElementById('calc-self').textContent = money0(a.self);
  document.getElementById('calc-self-note').textContent =
    '按' + (azValuationMode === 'cost' ? '买入价算（保守口径），没算涨跌' : '你自己填的最新价算，软件不联网，不会自动变') + '。';
  document.getElementById('calc-assets').textContent = money0(a.total);
  document.getElementById('calc-debts').textContent = money0(dSum.total);
  document.getElementById('calc-contingent').textContent = '不计入（' + CONTINGENT.length + ' 笔）';
  document.getElementById('calc-networth').textContent = money(nw);
  const stale = staleAssets();
  const cs = document.getElementById('calc-stale');
  if (stale.length) {
    cs.style.display = 'block';
    cs.textContent = '有 ' + stale.length + ' 样的价是很久以前填的（' + stale.map(x => x.name).join('、') + '），总数可能不准。';
  } else cs.style.display = 'none';

  // 账户镜像
  document.getElementById('az-mirror').innerHTML = AZ_ACCOUNT_MIRROR.map(m =>
    '<div class="mirror-item" onclick="switchTab(\'account\')">' +
      '<span class="mi-icon">' + (m.kind === 'A1' ? '💳' : '🔒') + '</span>' +
      '<span class="mi-main"><span class="mi-name">' + m.name + '</span>' +
      '<span class="mi-sub">' + (m.kind === 'A1' ? '能自由花 · ' : '有特定用途，不能随便花 · ') + m.accountCount + ' 个账户</span></span>' +
      '<span class="mi-amt">' + money0(m.amount) + '</span>' +
      '<span class="mi-arrow">›</span>' +
    '</div>').join('');

  // 资产分组
  const matched = ASSETS.filter(x => !kws || (x.name + x.cls + x.toBe + (x.code || '')).toLowerCase().indexOf(kws) > -1);
  const pick = f => matched.filter(x => {
    if (f === 'all') return true;
    if (f === 'give') return flowTagOf(x).cls === 'good';
    if (f === 'take') return flowTagOf(x).cls === 'bad';
    if (f === 'flat') return flowTagOf(x).cls === 'flat';
    if (f === 'stale') return staleDays(x.valuedAt) !== null && staleDays(x.valuedAt) > azStaleDays;
    return x.cls === f;
  });
  const sumOf = l => l.reduce((s, x) => s + (x.counted ? assetValueOf(x) : 0), 0);
  const setGroup = (g, list) => {
    document.getElementById('list-' + g).innerHTML = list.length ? list.map(assetCardHtml).join('')
      : '<div class="empty-hint"><span class="eh-text">这里是空的<small>' +
        (kws ? '没搜到' : '没有') + '这一类的东西</small></span></div>';
    document.getElementById('cnt-' + g).textContent = list.length;
    document.getElementById('sum-' + g).textContent = money0(sumOf(list));
  };
  setGroup('give', pick('give'));
  setGroup('take', pick('take'));
  setGroup('flat', pick('flat'));

  // 快筛 chips
  const chips = [['all','全部',matched.length],['give','✅ 给你钱',pick('give').length],
    ['take','💸 拿你钱',pick('take').length],['A7','🏠 房子',pick('A7').length],
    ['A4','📈 股票基金',pick('A4').length + pick('A5').length],['stale','⏰ 很久没更新价',pick('stale').length]];
  document.getElementById('az-chips').innerHTML = chips.map(c =>
    '<button class="acc-chip' + (azFilter === c[0] ? ' active' : '') + '" onclick="setAZFilter(\'' + c[0] + '\',this)">' +
    c[1] + '<b>' + c[2] + '</b></button>').join('');

  // 资产汇总：按大类，和上面的卡片对得上
  const byClass = {};
  matched.forEach(x => {
    if (!x.counted) return;
    byClass[x.cls] = byClass[x.cls] || { label: ASSET_CLASS[x.cls] || x.cls, sum:0, n:0 };
    byClass[x.cls].sum += assetValueOf(x);
    byClass[x.cls].n++;
  });
  const rows = Object.keys(byClass).sort().map(k =>
    '<div class="sg-item"><span>' + byClass[k].label + '（' + byClass[k].n + '）</span><b>' + money0(byClass[k].sum) + '</b></div>');
  const uncounted = matched.filter(x => !x.counted);
  if (uncounted.length) {
    rows.push('<div class="sg-item"><span>没算进总账的（你自己关掉的）</span><b class="gray">' +
      money0(uncounted.reduce((s, x) => s + assetValueOf(x), 0)) + '</b></div>');
  }
  rows.push('<div class="sg-item total"><span>除了钱以外的东西一共</span><b>' + money0(a.self) + '</b></div>');
  rows.push('<div class="sg-item"><span>加上卡里的和动不了的</span><b>' + money0(a.total) + '</b></div>');
  document.getElementById('az-asset-summary').innerHTML = rows.join('');

  // 能拿出多少
  document.getElementById('az-cash-layers').innerHTML = layers.map((l, i) =>
    '<div class="cl-row' + (i === 3 ? ' stuck' : '') + '">' +
      '<span class="cl-label">' + l.label + '</span>' +
      '<span class="cl-track"><i style="width:' + (a.total ? Math.max(2, l.amount / a.total * 100) : 0) + '%"></i></span>' +
      '<span class="cl-amt">' + money0(l.amount) + '</span>' +
    '</div>' +
    '<div class="cl-note">' + l.note + '</div>').join('');
  document.getElementById('az-exit-cost').textContent = money0(totalExitCost());

  // ---------- 负债 ----------
  const dmatched = DEBTS.filter(x => !kws ||
    (x.name + x.typ + x.purposeLabel + x.repayMethod).toLowerCase().indexOf(kws) > -1);
  document.getElementById('az-debt-list').innerHTML = dmatched.length
    ? dmatched.slice().sort((x, y) => {
        const rx = x.rateType === 'float' ? x.rate : realAnnualRate(x);
        const ry = y.rateType === 'float' ? y.rate : realAnnualRate(y);
        return ry - rx;
      }).map(debtCardHtml).join('')
    : '<div class="empty-hint"><span class="eh-text">没有欠款<small>这是好事</small></span></div>';

  const st = debtStats();
  document.getElementById('debt-total').textContent = money0(st.total);
  document.getElementById('debt-count').textContent = st.count + ' 笔 · 其中 ' +
    DEBTS.filter(x => (x.monthlyFee || 0) > 0).length + ' 笔在收手续费';
  document.getElementById('debt-monthpay').textContent = money0(st.monthPay);
  document.getElementById('debt-ratio').textContent =
    '占每月到手 ' + (st.payIncomeRatio * 100).toFixed(0) + '%';
  const lv = RATIO_LEVEL[azDebtRatioLevel];
  const bar = document.getElementById('debt-ratio-bar');
  bar.style.width = Math.min(100, st.payIncomeRatio / lv.limit * 100) + '%';
  bar.className = 'dh-bar-fill' + (st.payIncomeRatio > lv.limit ? ' over' : '');
  document.getElementById('debt-safe').innerHTML =
    (st.payIncomeRatio > lv.limit
      ? '<b>已经超过' + lv.label + '口径的 ' + (lv.limit * 100) + '%</b> —— 每挣 100 块有 ' +
        (st.payIncomeRatio * 100).toFixed(0) + ' 块要拿去还债，手上一有闪失就转不动。'
      : '<b>还在' + lv.label + '口径的安全线内</b>（' + (lv.limit * 100) + '%）。' + lv.tip) +
    ' <span class="link-btn" onclick="switchAZ(\'liability\')"></span>';

  // 白给银行多少钱
  document.getElementById('bc-cost').textContent = money0(st.monthCost);
  document.getElementById('bc-ratio').textContent =
    '占这个月还款 ' + (st.interestRatio * 100).toFixed(0) + '% · 占月收入 ' +
    (st.income ? (st.monthCost / st.income * 100).toFixed(0) : 0) + '%';
  const mo2 = monthlyOut();
  const segTotal = (mo2.interest + mo2.fee + st.monthPay) || 1;
  document.getElementById('bc-seg-i').style.width = (mo2.interest / segTotal * 100) + '%';
  document.getElementById('bc-seg-f').style.width = (mo2.fee / segTotal * 100) + '%';
  document.getElementById('bc-seg-p').style.width =
    (Math.max(0, st.monthPay - mo2.interest - mo2.fee) / segTotal * 100) + '%';

  // 三格
  const levList = DEBTS.map(leverageOf).filter(Boolean);
  const worstLev = levList.slice().sort((x, y) => x.net - y.net)[0];
  document.getElementById('mg-leverage').textContent = worstLev
    ? (worstLev.net >= 0 ? '划得来' : '不划算')
    : '没有借钱买东西';
  document.getElementById('mg-leverage').className = 'mg-value ' +
    (worstLev ? (worstLev.net >= 0 ? 'green' : 'red') : '');
  document.getElementById('mg-worst').textContent = st.worst ? st.worst.iso : '—';
  document.getElementById('mg-float').textContent = money0(st.floatDelta);

  // 快到期的
  const due = dueSoon(90);
  document.getElementById('az-due').innerHTML = due.length ? due.map(x =>
    '<div class="due-item' + (x.left <= 30 ? ' urgent' : '') + '">' +
      '<span class="di-icon">' + x.d.icon + '</span>' +
      '<span class="di-main"><span class="di-name">' + x.d.name + '</span>' +
      '<span class="di-sub">' + x.d.to + ' 到期 · 每月 ' + x.d.payDay + ' 号还 ' + money0(x.d.monthlyPay) + '</span></span>' +
      '<span class="di-left">' + (x.left <= 0 ? '已到期' : '还有 ' + x.left + ' 天') + '</span>' +
    '</div>').join('')
    : '<div class="empty-hint"><span class="eh-text">未来 3 个月没有到期的<small>该还的日子都还上了</small></span></div>';

  // 两张清单
  document.getElementById('az-contingent').innerHTML = CONTINGENT.map(c =>
    '<div class="cg-item"><span class="cg-main"><span class="cg-name">' + c.who + '</span>' +
    '<span class="cg-sub">' + c.when + ' · 大概 ' + c.eta + '</span></span>' +
    '<span class="cg-max">最多 ' + money0(c.max) + '</span></div>').join('') +
    '<div class="cg-total">合计最多可能要还 <b>' + money0(CONTINGENT.reduce((s, c) => s + c.max, 0)) +
    '</b>，不算进「一共欠多少」。</div>';
  document.getElementById('az-insured').innerHTML = INSURED.map(c =>
    '<div class="cg-item"><span class="cg-main"><span class="cg-name">' + c.what + '</span>' +
    '<span class="cg-sub">' + c.notCover + ' · 保到 ' + c.until + '</span></span>' +
    '<span class="cg-max green">最多替你付 ' + money0(c.max) + '</span></div>').join('') +
    '<div class="cg-total">这些都不算资产、也不抵扣欠款，只是让你知道出事时有人兜底。</div>';

  // 负债汇总
  const byType = {};
  DEBTS.forEach(x => {
    byType[x.typ] = byType[x.typ] || { sum:0, n:0 };
    byType[x.typ].sum += x.principal; byType[x.typ].n++;
  });
  const drows = Object.keys(byType).sort((x, y) => byType[y].sum - byType[x].sum).map(k =>
    '<div class="sg-item"><span>' + k + '（' + byType[k].n + ' 笔）</span><b>' + money0(byType[k].sum) + '</b></div>');
  drows.push('<div class="sg-item total"><span>一共欠多少</span><b class="red">' + money0(st.total) + '</b></div>');
  drows.push('<div class="sg-item"><span>其中这个月要还</span><b>' + money0(st.monthPay) + '</b></div>');
  drows.push('<div class="sg-item"><span>这个月白给银行的</span><b class="red">' + money0(st.monthCost) + '</b></div>');
  drows.push('<div class="sg-item"><span>还完债还剩（月收入−必须花的）÷月还款</span><b class="' +
    (st.afterDebt < 1.5 ? 'red' : 'green') + '">' + st.afterDebt.toFixed(1) + ' 倍</b></div>');
  document.getElementById('az-debt-summary').innerHTML = drows.join('');

  // 搜索结果
  if (searching) {
    const res = matched.map(assetCardHtml).concat(dmatched.map(debtCardHtml));
    document.getElementById('az-search-result').innerHTML = res.length ? res.join('')
      : '<div class="empty-hint"><span class="eh-ico">🔍</span><span class="eh-text">没搜到「' +
        escapeHtml(kw.trim()) + '」<small>换个名字或类型试试</small></span></div>';
    document.getElementById('view-az-search').style.display = 'block';
    document.getElementById('view-asset').style.display = 'none';
    document.getElementById('view-liability').style.display = 'none';
  }
}

// ---------- 轻量 toast（复用分类管理的样式） ----------
function _azToast(msg) {
  if (typeof _cmToast === 'function') { _cmToast(msg); return; }
  let t = document.getElementById('az-toast');
  if (!t) {
    t = document.createElement('div');
    t.id = 'az-toast';
    t.className = 'az-toast';
    document.querySelector('.phone').appendChild(t);
  }
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(t._t);
  t._t = setTimeout(() => t.classList.remove('show'), 2200);
}

// 点搜索框外面不收起（跟账户页一致，靠 ✕ 关）
document.addEventListener('click', () => {});

// ==================== 资债页：四个弹层 ====================

// ① 借钱买的东西划不划算（13.5）
function renderLeverageSheet() {
  const box = document.getElementById('leverage-list');
  const list = DEBTS.map(leverageOf).filter(Boolean);
  if (!list.length) {
    box.innerHTML = '<div class="empty-hint"><span class="eh-text">没有一笔债是连着东西的<small>' +
      '记负债时填上「这笔钱买来的东西」，这里就会自动帮你算</small></span></div>';
    document.getElementById('leverage-hint').textContent =
      '判断的是钱往哪边流，不是给你的消费打分。';
    return;
  }
  box.innerHTML = list.map(x => {
    const ok = x.net >= 0;
    return '<div class="lev-item' + (ok ? ' ok' : ' bad') + '">' +
      '<span class="lv-head">' + (ok ? '✅' : '⚠️') + ' ' + x.asset.icon + ' ' + x.asset.name +
        ' ← ' + x.asset.linkDebt.replace('d_', '') + '</span>' +
      '<div class="lv-row"><span>它稳稳每月给你</span><b class="green">+' + money0(x.steadyIn) + '</b></div>' +
      '<div class="lv-row"><span>这笔债每月利息和费用</span><b class="red">-' + money0(x.cost) + '</b></div>' +
      '<div class="lv-row total"><span>' + (ok ? '它替你付了利息，还多留' : '它每月从你口袋拿走') + '</span>' +
        '<b class="' + (ok ? 'green' : 'red') + '">' + money0(Math.abs(x.net)) + '</b></div>' +
      '<div class="lv-note">' + (ok
        ? '这钱借得值：东西自己在还债。'
        : '借来买了会拿你钱的东西，等于双重往外掏。') + '</div>' +
    '</div>';
  }).join('');
  document.getElementById('leverage-hint').textContent =
    '只算标了「每月都有」的进账；分红、说不准的租金不参与判断。这里看的是钱往哪边流，不是给你的消费打分。';
}

// ② 逐月缺口表（7.9）
function renderGapSheet() {
  const rows = monthlyGapTable();
  const worst = rows.slice().sort((a, b) => b.gap - a.gap)[0];
  const html = ['<div class="gap-head"><span>月份</span><span>要还</span><span>拿得出</span><span>差多少</span></div>'];
  rows.forEach(r => {
    const short = r.gap > 0;
    html.push('<div class="gap-row' + (short ? ' short' : '') + '">' +
      '<span>' + r.iso + '</span>' +
      '<span>' + money0(r.pay) + '</span>' +
      '<span>' + money0(Math.max(0, r.available)) + '</span>' +
      '<span class="' + (short ? 'red' : 'green') + '">' +
        (short ? '差 ' + money0(r.gap) : '够') + '</span>' +
    '</div>');
  });
  const box = document.getElementById('gap-table');
  box.innerHTML = html.join('');
  const tip = document.getElementById('gap-tip');
  if (tip) tip.textContent = worst && worst.gap > 0
    ? worst.iso + ' 要还 ' + money0(worst.pay) + '，那个月能马上拿出来的只有 ' +
      money0(Math.max(0, worst.available)) + '，差 ' + money0(worst.gap) + '。提前把钱挪过去。'
    : '未来 12 个月每个月都还得上。';
  // 提示放进 sheet-hint
  const hint = document.querySelector('#gap-sheet .sheet-hint');
  if (hint && worst) {
    hint.innerHTML = (worst.gap > 0
      ? '<b>' + worst.iso + ' 最紧张：要还 ' + money0(worst.pay) + '，拿得出 ' +
        money0(Math.max(0, worst.available)) + '，差 ' + money0(worst.gap) + '。</b> '
      : '未来 12 个月每个月都还得上。 ') +
      '动不了的钱（公积金、医保）没算进来；卖房子卖车要扣的费用也还没减。这是估算。';
  }
}

// ③ 先还哪一笔（7.10）
function renderPayoffSheet() {
  const order = payoffOrder();
  const box = document.getElementById('payoff-list');
  box.innerHTML = order.map((x, i) => {
    const d = x.d;
    const top = i === 0;
    return '<div class="pay-item' + (top ? ' top' : '') + '">' +
      '<span class="py-rank">' + (i + 1) + '</span>' +
      '<span class="py-main">' +
        '<span class="py-name">' + d.icon + ' ' + d.name +
          (top ? '<span class="py-badge">先还这笔</span>' : '') + '</span>' +
        '<span class="py-sub">还欠 ' + money0(d.principal) + ' · 每月白给 ' +
          money0((d.monthlyInterest || 0) + (d.monthlyFee || 0)) + '</span>' +
      '</span>' +
      '<span class="py-rate">' + (x.rate * 100).toFixed(1) + '%</span>' +
      '<button class="py-btn" onclick="openPrepay(\'' + d.id + '\')">算一下提前还</button>' +
    '</div>';
  }).join('');
  const top1 = order[0];
  const hint = document.querySelector('#payoff-sheet .sheet-hint');
  if (hint && top1) {
    const others = order.slice(1).reduce((s, x) => s + x.d.principal * x.rate, 0);
    hint.innerHTML = '先还「' + top1.d.name + '」：它实际一年要付 ' + (top1.rate * 100).toFixed(1) +
      '%，是现在最贵的。剩下的钱按同样思路往下排。' +
      '<br>另一种思路是「先还最小的一笔」，还得快、容易坚持——两种都行，看你更需要省钱还是需要撑住劲。';
  }
}

// ④ 提前还款四件事
let prepayDebtId = null;
function openPrepay(id) {
  prepayDebtId = id;
  const d = DEBTS.find(x => x.id === id);
  document.getElementById('prepay-title').textContent = '提前还 ' + d.name;
  document.getElementById('prepay-amount').value = '';
  renderPrepay();
  openSheet('prepay-sheet');
}
function renderPrepay() {
  const d = DEBTS.find(x => x.id === prepayDebtId);
  if (!d) return;
  const box = document.getElementById('prepay-result');
  const amt = parseFloat(document.getElementById('prepay-amount').value);
  if (!amt || amt <= 0) {
    box.innerHTML = '<div class="empty-hint"><span class="eh-text">填个数就看得到<small>' +
      '还剩 ' + money0(d.principal) + ' 没还</small></span></div>';
    return;
  }
  const p = prepayPlan(prepayDebtId, Math.min(amt, d.principal));
  box.innerHTML =
    '<div class="pp-lead ' + (p.safe ? 'ok' : 'warn') + '">' +
      (p.safe ? '可以还：省下的利息比应急金的风险更值得。'
              : '先别急：还完你的应急金只剩 ' + p.months.toFixed(1) + ' 个月，不够 3 个月。') +
    '</div>' +
    '<div class="pp-row"><span>① 能省多少利息</span><b class="green">' + money0(p.saveInterest) + '</b></div>' +
    '<div class="pp-note">按剩余期数和实际一年 ' + (p.realRate * 100).toFixed(1) + '% 估算，各家算法不一样，以账单为准。</div>' +
    '<div class="pp-row"><span>② 提前还要交的违约金</span><b class="red">-' + money0(p.penalty) + '</b></div>' +
    '<div class="pp-row total"><span>扣完实际净省</span><b class="' + (p.netSave > 0 ? 'green' : 'red') + '">' +
      money0(p.netSave) + '</b></div>' +
    '<div class="pp-row"><span>③ 还完手上还剩能花的钱</span><b>' + money0(p.cashAfter) + '</b></div>' +
    '<div class="pp-row"><span>   够撑几个月必须花的钱</span><b class="' + (p.safe ? '' : 'red') + '">' +
      p.months.toFixed(1) + ' 个月</b></div>' +
    '<div class="pp-note">④ ' + (p.safe
      ? '建议：先留够 3 个月的必须花的钱，再拿多出来的还，这样省利息又不影响安全。'
      : '建议：先留够 3 个月的必须花的钱，剩下的再拿来还。') + '</div>';
}
