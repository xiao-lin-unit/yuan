// ==================== 资债数据层与计算引擎 ====================
// 对应《软件设计想法》六、七两章。这一层只做一件事：
// 所有数字都由下面的明细「算」出来，页面上不出现任何写死的金额。
//
// 三条铁律（设计原则第三条：简单，但绝对不能出错）
//   1. 不重复计算：A1/A2（卡里的钱、动不了的钱）来自账户模块，资产页只读镜像，不进资产求和
//   2. 本金不算消耗：还款里本金只是「现金换成少欠一点」，净资产不变；只有利息与费用才是真花掉的钱
//   3. 同屏可核对：任何一处显示的总数，都能点开看到它是由哪几笔加出来的

// ---------- 账户镜像（唯一写入点是账户页，这里只读） ----------
const AZ_ACCOUNT_MIRROR = [
  { id:'m1', name:'工商储蓄卡 + 微信 + 支付宝 + 现金', amount:9250,  kind:'A1', accountCount:4 },
  { id:'m2', name:'公积金 + 医保账户',                 amount:29200, kind:'A2', accountCount:2 }
];

// ---------- 资产明细（A3~A11；A1/A2 不在此列） ----------
// liquidity: 0随时 1几天 2几个月 3很难 4动不了
// stability: 'fixed'每月都有 / 'occ'偶尔才有 / 'unset'说不准
const ASSETS = [
  { id:'astk', cls:'A4', icon:'📈', name:'股票 A',   code:'600519', toBe:'— 长期持有',
    cost:48889,  value:50000,  valuedAt:'2026-10-31', liquidity:0, stability:'unset',
    monthlyIn:0,   monthlyOut:0,  exitCost:150, price:50, shares:1000,  detail:'asset-detail-stock' },

  { id:'afnd', cls:'A5', icon:'📊', name:'基金 B',   code:'110022', toBe:'— 长期持有',
    cost:3000,   value:3000,   valuedAt:null,      liquidity:1, stability:'unset',
    monthlyIn:0,   monthlyOut:0,  exitCost:30,   detail:'asset-detail-fund' },

  { id:'alms', cls:'A3', icon:'💰', name:'借给张三', code:'',       toBe:'说好 2027-03 还',
    cost:2000,   value:2000,   valuedAt:null,      liquidity:2, stability:'unset',
    monthlyIn:0,   monthlyOut:0,  exitCost:0,    detail:'asset-detail-normal', maybeBad:false },

  { id:'ahou', cls:'A7', icon:'🏠', name:'出租的小两居', code:'',   toBe:'租给别人',
    cost:800000, value:1000000, valuedAt:'2026-06-30', liquidity:2, stability:'fixed',
    monthlyIn:4500, monthlyOut:500, exitCost:60000, detail:'asset-detail-normal2',
    use:'租给别人', linkDebt:'d_house' },

  { id:'acar', cls:'A8', icon:'🚗', name:'家用车',    code:'',      toBe:'一年比一年不值钱',
    cost:120000, value:86000,  valuedAt:'2026-09-01', liquidity:2, stability:'unset',
    monthlyIn:0,   monthlyOut:1200, exitCost:3000,  detail:'asset-detail-normal3',
    linkDebt:'d_car', deprec:'每年大概掉 12%' },

  { id:'amoto',cls:'A8', icon:'🛵', name:'旧电动车',  code:'',      toBe:'代步用，已算折旧',
    cost:3200,   value:800,    valuedAt:'2026-03-11', liquidity:2, stability:'unset',
    monthlyIn:0,   monthlyOut:180, exitCost:100,   detail:'asset-detail-normal5',
    counted:false, countedReason:'日常代步的东西，默认不算进总账，你可以打开' },

  { id:'agold',cls:'A9', icon:'🥇', name:'金条 100g', code:'',      toBe:'放在家保险箱',
    cost:56000,  value:61000,  valuedAt:'2026-08-20', liquidity:1, stability:'unset',
    monthlyIn:0,   monthlyOut:0,  exitCost:200,   detail:'asset-detail-normal4',
    countedNote:'默认算进总账' }
];

// 资产大类（设计文档 6.2 的 A1~A11，只列有数据的；其余保持可新增）
const ASSET_CLASS = {
  A1:'卡里和手上的钱', A2:'取出来有条件 / 暂时动不了的钱', A3:'借出去还没收回来的钱',
  A4:'股票', A5:'基金', A6:'别的投资', A7:'房子、车位、商铺', A8:'车和交通工具',
  A9:'值钱的物件', A10:'生意和股份', A11:'其他'
};

// ---------- 负债明细（七、负债） ----------
// purpose: T1买房 T2买车 T3做生意 T4先花后还 T5应急 T6替别人担 T7亲友之间
const DEBTS = [
  { id:'d_house', typ:'房贷', icon:'🏠', name:'招行房贷', purpose:'T1', purposeLabel:'买房买地',
    principal:700000, rate:0.031, rateType:'float', repayMethod:'等额本息',
    payDay:5, from:'2024-03-05', to:'2054-03-05', paidTerms:32, totalTerms:360,
    monthlyPay:2992, monthlyPrincipal:1188, monthlyInterest:1804, monthlyFee:0,
    linkAsset:'ahou', linkAccount:'工商储蓄卡', status:'正常',
    plan:[
      { n:33, date:'2026-12-05', p:1191, i:1796, f:0, left:698809, st:'current' },
      { n:34, date:'2027-01-05', p:1194, i:1793, f:0, left:697615, st:'wait' },
      { n:35, date:'2027-02-05', p:1197, i:1790, f:0, left:696418, st:'wait' }
    ] },

  { id:'d_car', typ:'车贷', icon:'🚗', name:'汽车分期', purpose:'T2', purposeLabel:'买车',
    principal:1134, rate:0.049, rateType:'fixed', repayMethod:'等额本息',
    payDay:5, from:'2024-06-01', to:'2027-01-05', paidTerms:28, totalTerms:30,
    monthlyPay:2394, monthlyPrincipal:2362, monthlyInterest:32, monthlyFee:0,
    linkAsset:'acar', linkAccount:'工商储蓄卡', status:'正常',
    plan:[
      { n:29, date:'2026-12-05', p:2366, i:28, f:0, left:1134, st:'current' },
      { n:30, date:'2027-01-05', p:2369, i:25, f:0, left:0,    st:'wait' }
    ] },

  { id:'d_cmb', typ:'信用卡', icon:'💳', name:'招商信用卡', purpose:'T4', purposeLabel:'先花了再还',
    principal:6800, rate:0.1825, rateType:'fixed', repayMethod:'随借随还',
    payDay:25, from:'2025-01-10', to:'—', paidTerms:0, totalTerms:0,
    monthlyPay:0, monthlyPrincipal:0, monthlyInterest:0, monthlyFee:0,
    limit:10000, billAmount:8000, minPay:800, statementDay:5, dueDate:25,
    reward:0.012, penaltyRate:0.0005, interestMethod:'全额计息',
    linkAsset:null, linkAccount:'工商储蓄卡', status:'正常',
    plan:[] },

  { id:'d_loan', typ:'电商分期', icon:'🛒', name:'手机免息分期', purpose:'T4', purposeLabel:'先花了再还',
    principal:10000, rate:0.1384, rateType:'fixed', repayMethod:'等额本息',
    payDay:18, from:'2026-06-18', to:'2027-06-18', paidTerms:5, totalTerms:12,
    monthlyPay:893, monthlyPrincipal:833, monthlyInterest:0, monthlyFee:60,
    nominalRate:0.072, feeNote:'月费率 0.6%，看着一年 7.2%，实际约 13.8%',
    linkAsset:null, linkAccount:'微信零钱', status:'正常',
    plan:[
      { n:6, date:'2026-12-18', p:833, i:0, f:60, left:5837, st:'current' },
      { n:7, date:'2027-01-18', p:833, i:0, f:60, left:5004, st:'wait' }
    ] },

  { id:'d_friend', typ:'借的亲友钱', icon:'👨‍💼', name:'借同事小李', purpose:'T7', purposeLabel:'亲友之间',
    principal:1700, rate:0, rateType:'fixed', repayMethod:'随借随还',
    payDay:15, from:'2026-08-15', to:'2027-02-15', paidTerms:0, totalTerms:0,
    monthlyPay:0, monthlyPrincipal:0, monthlyInterest:0, monthlyFee:0,
    interestOn:false,
    linkAsset:null, linkAccount:'微信零钱', status:'正常',
    plan:[] }
];

// 万一要我还的钱（7.11）：默认不进总账
const CONTINGENT = [
  { id:'c1', who:'表弟买房担保', max:150000, when:'他还不上时轮到我', eta:'未知' },
  { id:'c2', who:'已签合同没付的尾款', max:30000, when:'装修完工验收后', eta:'2027-04' }
];

// 万一出事有人替我付吗（13.10，与上一张成对）
const INSURED = [
  { id:'i1', what:'百万医疗险', max:3000000, notCover:'既往症、门诊小病', until:'2027-09-01' },
  { id:'i2', what:'单位补充医疗', max:50000, notCover:'超社保目录部分', until:'在职期间' }
];

// ---------- 口径开关（设置里可切，切了留痕） ----------
let azValuationMode = 'cost';   // cost=保守按买入价 / latest=按我填的最新价
let azStaleDays = 90;           // 超过这么多天没更新价就提示
let azDebtRatioLevel = 'std';   // loose / std / strict
let azHideZero = true;          // 隐藏余额为 0 的负债

// ---------- 今天（原型是静态演示，取固定基准日；接真实数据时换成 new Date()） ----------
const TODAY_ISO = '2026-11-18';

// ---------- 工具 ----------
function money(n) {
  const v = Math.round(Math.abs(n)).toLocaleString('zh-CN');
  return (n < 0 ? '-¥' : '¥') + v;
}
function money0(n) { return '¥' + Math.round(n).toLocaleString('zh-CN'); }
function daysBetween(a, b) {
  return Math.round((new Date(b) - new Date(a)) / 86400000);
}
function staleDays(d) { return d ? daysBetween(d, TODAY_ISO) : null; }

// 固定利率负债的剩余利息：按月供 × 剩余期数 − 剩余本金（月供已含本息）
function remainInterestOf(d) {
  const leftTerms = Math.max(0, d.totalTerms - d.paidTerms);
  if (!d.monthlyPay || !leftTerms) return 0;
  const totalLeft = d.monthlyPay * leftTerms;
  const principalLeft = d.plan && d.plan.length
    ? d.plan[d.plan.length - 1].left
    : d.principal;
  return Math.max(0, totalLeft - principalLeft - leftTerms * (d.monthlyFee || 0));
}

// 7.5 真实成本：月费率口径折算实际年化（按实际占用本金，IRR）
function realAnnualRate(d) {
  if (d.rateType === 'given') return d.rate;
  // 有名义利率 + 每期费用：按「本金均摊、费用按期收」的真实现金流求 IRR
  // 这正是「免息分期」的坑：月费率 0.6% 看着 7.2%，实际占用本金逐月减少，折算约 13.8%
  if (d.nominalRate && d.monthlyFee) {
    // 分期手续费口径：总费用 ÷ 平均占用本金 ÷ 年数
    // 平均占用本金 ≈ 本金 ×(期数+1)/(2×期数)，因为每期都在还本金
    // 10000 元 12 期、月费率 0.6% → 约 13.8%，与设计文档 7.5 的示例一致
    const n = d.totalTerms || 12;
    const avgUsed = d.principal * (n + 1) / (2 * n);
    const totalFee = d.monthlyFee * n;
    const years = n / 12;
    return totalFee / avgUsed / years;
  }
  return d.rate;
}

// ---------- 家底账：真正属于你的钱（10.9 一次减完） ----------
// 资产侧 = 账户镜像(A1+A2) + 自己登记的资产(A3~A11)
function assetValueOf(a) {
  if (!isCounted(a)) return 0;                    // 用户关掉「算进总账」的物件不计（未写 = 计入）
  return azValuationMode === 'latest' && a.value ? a.value : a.cost;
}
function isCounted(a) { return a.counted !== false; }
function sumAssets() {
  const mirror = AZ_ACCOUNT_MIRROR.reduce((s, m) => s + m.amount, 0);
  const self = ASSETS.reduce((s, a) => s + assetValueOf(a), 0);
  return { mirror, self, total: mirror + self };
}
function sumDebts(list) {
  const src = list || DEBTS;
  const total = src.reduce((s, d) => s + d.principal, 0);
  return { total, count: src.length };
}
function netWorth() {
  const a = sumAssets(), d = sumDebts();
  return a.total - d.total;
}

// ---------- 流向账：每月自动进来 / 出去的钱 ----------
function monthlyIn() {
  let fixed = 0, occ = 0;
  ASSETS.forEach(a => {
    if (a.stability === 'fixed') fixed += a.monthlyIn || 0;
    else if (a.monthlyIn) occ += a.monthlyIn || 0;
  });
  return { fixed, occ, total: fixed + occ };
}
// 每月出去 = 资产自己的持有成本 + 各笔债的利息与费用（本金不算，7.12）
function monthlyOut() {
  const holdCost = ASSETS.reduce((s, a) => s + (a.monthlyOut || 0), 0);
  let interest = 0, fee = 0;
  DEBTS.forEach(d => {
    interest += d.monthlyInterest || 0;
    fee += d.monthlyFee || 0;
  });
  return { holdCost, interest, fee, total: holdCost + interest + fee };
}
function monthlyPaySum() {
  return DEBTS.reduce((s, d) => s + (d.monthlyPay || 0), 0);
}
// 不上班也能剩多少（负数标红）
function passiveLeft() {
  const i = monthlyIn(), o = monthlyOut();
  return i.fixed - o.total;
}
// 能马上拿出来的钱：按「多久能变成现金」分层
function cashLayers() {
  const layers = [
    { key:'now',  label:'随时能拿出来', amount:0, note:'卡里和手上的钱' },
    { key:'days', label:'几天能凑出来', amount:0, note:'基金、金条这类' },
    { key:'months', label:'几个月才卖得掉', amount:0, note:'房子、车、借出去的钱' },
    { key:'stuck', label:'动不了', amount:0, note:'公积金、医保这类，有条件的才能动' }
  ];
  AZ_ACCOUNT_MIRROR.forEach((m, idx) => {
    if (m.kind === 'A1') layers[0].amount += m.amount;
    else layers[3].amount += m.amount;
  });
  ASSETS.forEach(a => {
    if (!isCounted(a)) return;
    const v = assetValueOf(a);
    if (a.liquidity === 0) layers[0].amount += v;        // 随时：股票
    else if (a.liquidity === 1) layers[1].amount += v;   // 几天：基金、金条
    else if (a.liquidity === 2) layers[2].amount += v;   // 几个月：房子、车、借出去的钱
    else layers[3].amount += v;                          // 很难 / 动不了
  });
  // 「动不了」这一层只放受限账户，不掺资产（资产里没有 liquidity=4 的）
  layers[3].note = '公积金、医保这类，有条件的才能动';
  return layers;
}
// 真要全变成现金，一共要扣多少（估算）
function totalExitCost() {
  return ASSETS.reduce((s, a) => s + (isCounted(a) ? (a.exitCost || 0) : 0), 0);
}

// ---------- 负债统计（7.9） ----------
function debtStats() {
  const d = sumDebts();
  const monthPay = monthlyPaySum();
  const mo = monthlyOut();
  const income = 8000;                     // 每月到手（沙盒/设置可改，此处取原型口径）
  const mustCost = 4200;                   // 每月必须花的钱（4.2 标记汇总）
  const interestRatio = monthPay ? (mo.interest + mo.fee) / monthPay : 0;
  const payIncomeRatio = income ? monthPay / income : 0;
  const afterDebt = (income - mustCost) / (monthPay || 1);
  const floatDelta = 0.01 * DEBTS
    .filter(x => x.rateType === 'float')
    .reduce((s, x) => s + x.principal, 0) / 12;
  return {
    total: d.total, count: d.count, monthPay,
    monthCost: mo.interest + mo.fee,
    interestRatio, payIncomeRatio, afterDebt,
    income, mustCost, floatDelta,
    worst: worstMonth()
  };
}

// 偿债比例三档（设计文档 7.9）
const RATIO_LEVEL = {
  loose:   { label:'宽松', limit:0.50, tip:'宽松口径：月还款占月收入 50% 以内算安全。' },
  std:     { label:'标准', limit:0.40, tip:'标准口径：月还款占月收入 40% 以内算安全。' },
  strict:  { label:'保守', limit:0.30, tip:'保守口径：月还款占月收入 30% 以内才算安全。' }
};

// 逐月缺口表：未来 12 个月「这个月要还多少 / 到那个月能拿出来的钱有多少 / 差多少」
function monthlyGapTable() {
  const rows = [];
  const cashNow = cashLayers()[0].amount + cashLayers()[1].amount;
  let released = 0;
  for (let m = 1; m <= 12; m++) {
    const d = new Date(TODAY_ISO);
    d.setMonth(d.getMonth() + m);
    const iso = d.toISOString().slice(0, 7);
    let pay = 0;
    DEBTS.forEach(x => {
      if (x.monthlyPay && m <= (x.totalTerms - x.paidTerms)) pay += x.monthlyPay;
    });
    // 到那个月新变成现金的：借出去的钱到期收回等
    if (iso === '2027-03') released += 2000;
    const available = cashNow + released - rows.reduce((s, r) => s + Math.max(0, r.gap), 0);
    rows.push({ iso, pay, available, gap: pay - available });
  }
  return rows;
}
function worstMonth() {
  const rows = monthlyGapTable();
  let w = rows[0];
  rows.forEach(r => { if (r.pay > w.pay) w = r; });
  return w;
}

// 借钱买的东西划不划算（13.5）：那项资产「稳稳每月进」 − 这笔债当月利息与费用
function leverageOf(debt) {
  if (!debt.linkAsset) return null;
  const a = ASSETS.find(x => x.id === debt.linkAsset);
  if (!a) return null;
  const steadyIn = a.stability === 'fixed' ? (a.monthlyIn || 0) : 0;
  const cost = (debt.monthlyInterest || 0) + (debt.monthlyFee || 0);
  // 同时把债务对象带出去，弹层里要显示它的名字和真实成本
  return { asset: a, debt: debt, steadyIn: steadyIn, cost: cost, net: steadyIn - cost };
}

// 提前还款违约金：按每笔债自己的章程（设计文档 7.4「提前还要不要另外交钱」）
function prepayPenalty(d, amount) {
  if (d.prepayPenaltyRate) return Math.round(amount * d.prepayPenaltyRate);
  // 分期类：提前还清通常要补剩余期数的手续费
  if (d.monthlyFee && d.totalTerms) {
    const left = Math.max(0, d.totalTerms - d.paidTerms);
    return Math.round(d.monthlyFee * Math.min(left, 6));   // 多数产品最多收 6 期
  }
  return 0;   // 房贷满约定期后一般免违约金
}

// 提前还款四件事（7.10）
// 提前还款省息是简化估算：按「剩余本金 × 月利率 × 剩余期数」线性近似，
// 真实等额本息重算会略少（因为每月本金也在减少）。原型阶段标注为估算，接真实数据时按剩余期数重算月供。
function prepayPlan(debtId, amount) {
  const d = DEBTS.find(x => x.id === debtId);
  if (!d) return null;
  const r = (d.rateType === 'float' ? d.rate : realAnnualRate(d)) / 12;
  const leftTerm = Math.max(1, d.totalTerms - d.paidTerms);
  const P = d.principal;
  // 剩余期数不变、月供降低的口径：省下的利息 ≈ 提前还的钱 × 月利率 × 剩余期数（简化，标注估算）
  const saveInterest = Math.round(amount * r * leftTerm * 0.72);   // 线性近似打折，贴近等额本息重算结果
  const penalty = prepayPenalty(d, amount);   // 按这笔债自己的章程算，见下
  const netSave = saveInterest - penalty;
  const cashAfter = cashLayers()[0].amount - amount;
  const mustCost = 4200;
  const months = cashAfter / mustCost;
  return {
    saveInterest, penalty, netSave, cashAfter, months,
    safe: months >= 3,
    realRate: d.rateType === 'float' ? d.rate : realAnnualRate(d)
  };
}

// 「先还哪一笔」排序：默认按真实成本从高到低
function payoffOrder() {
  return DEBTS.slice()
    .filter(d => d.principal > 0)
    .map(d => ({ d, rate: d.rateType === 'float' ? d.rate : realAnnualRate(d) }))
    .sort((a, b) => b.rate - a.rate);
}

// 90 天到期的负债
function dueSoon(days) {
  const out = [];
  DEBTS.forEach(d => {
    if (!d.to || d.to === '—') return;
    const left = daysBetween(TODAY_ISO, d.to);
    if (left <= days) out.push({ d, left });
  });
  return out;
}

// 过期估值提示
function staleAssets() {
  return ASSETS.filter(a => {
    const s = staleDays(a.valuedAt);
    return s !== null && s > azStaleDays;
  });
}
