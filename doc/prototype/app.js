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
    'liability-detail-friend': 'page-liability-detail-friend'
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

  document.getElementById('view-asset').style.display = view === 'asset' ? 'block' : 'none';
  document.getElementById('view-liability').style.display = view === 'liability' ? 'block' : 'none';
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
}
function closeSheet() {
  document.getElementById('sheet-mask').classList.remove('show');
  document.querySelectorAll('.sheet').forEach(s => s.classList.remove('show'));
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

// 首次引导
window.addEventListener('DOMContentLoaded', () => {
  setTimeout(() => openSheet('onboard-sheet'), 400);
});
