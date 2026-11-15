// ==================== 分类管理 ====================
// 规则（软件设计想法 4.1 / 5.1 / 10.5）：
//   1. 支出与收入分类都只有一层，不分级
//   2. 预定义分类不可删除，但可隐藏；自定义可删可隐藏
//   3. 每个分类至少：名称、排序、图标（可上传图片，否则用默认 emoji）

const CAT_ICON_MAX_SIZE = 512 * 1024;          // 自定义图标上限 512KB
const CAT_ICON_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

// 预定义支出分类（4.1）
const PRESET_EXPENSE = ['三餐','零食饮料','水果','外卖','买菜做饭','水电燃气','物业','房租','话费网费',
  '看病买药','日用品','交通','加油','打车','衣服鞋帽','美容护肤','教育学习','书报杂志','孩子花销',
  '孝敬长辈','宠物','人情往来','娱乐休闲','旅游出行','烟酒','健身运动','家居装修','电器数码',
  '保险','税费','其他'];

// 预定义收入分类（5.1）
const PRESET_INCOME = ['工资','奖金','兼职外快','投资收益','退款退货','报销到账','礼金红包','二手变卖','中奖','其他'];

// 默认图标：没有贴图的分类用它，取名称首字
const DEFAULT_ICON = { kind: 'text', value: '' };

let categories = {
  expense: [],
  income: []
};
let cmType = 'expense';        // 当前管理的类型
let cmShowHidden = false;      // 是否展示已隐藏
let cmEditing = null;          // 正在编辑的分类对象（新建时为草稿）

// ---------- 工具 ----------
function uid() {
  return 'cat_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
}

// 给预定义分类配一个贴合语义的默认 emoji
function emojiFor(kind, name) {
  const map = {
    '三餐':'🍚','零食饮料':'🥤','水果':'🍎','外卖':'🥡','买菜做饭':'🛒','水电燃气':'⚡','物业':'🏢',
    '房租':'🏠','话费网费':'📱','看病买药':'💊','日用品':'🧻','交通':'🚌','加油':'⛽','打车':'🚕',
    '衣服鞋帽':'👕','美容护肤':'💄','教育学习':'📖','书报杂志':'📰','孩子花销':'🧸','孝敬长辈':'🎋',
    '宠物':'🐱','人情往来':'🎁','娱乐休闲':'🎮','旅游出行':'✈️','烟酒':'🍶','健身运动':'🏃',
    '家居装修':'🛋️','电器数码':'💻','保险':'🛡️','税费':'📄','其他':'📦',
    '工资':'💰','奖金':'🏆','兼职外快':'🧑‍💻','投资收益':'📈','退款退货':'↩️','报销到账':'🧾',
    '礼金红包':'🧧','二手变卖':'🔄','中奖':'🎊'
  };
  return map[name] || (kind === 'income' ? '💵' : '📦');
}

// 初始化：把预定义分类铺进列表，排序按预设顺序
function initCategories() {
  if (categories.expense.length || categories.income.length) return;
  PRESET_EXPENSE.forEach((name, i) => {
    categories.expense.push({
      id: uid(), name: name, kind: 'expense', order: i,
      icon: { kind: 'emoji', value: emojiFor('expense', name) },
      preset: true, hidden: false,
      // 支出专属：必须花的 / 可省的（4.2，默认未分类，不打就不参与判断）
      necessity: 'unset',
      createdAt: Date.now(), updatedAt: Date.now()
    });
  });
  PRESET_INCOME.forEach((name, i) => {
    categories.income.push({
      id: uid(), name: name, kind: 'income', order: i,
      icon: { kind: 'emoji', value: emojiFor('income', name) },
      preset: true, hidden: false,
      // 收入专属：每月都有的 / 偶尔才有的（5.2）
      stability: 'unset',
      createdAt: Date.now(), updatedAt: Date.now()
    });
  });
}

// 取可见分类（记账弹层用这个）：按 order 升序、过滤隐藏
function visibleCategories(kind) {
  return categories[kind].filter(c => !c.hidden).sort((a, b) => a.order - b.order);
}

// ---------- 页面切换 ----------
function switchCategoryType(kind) {
  cmType = kind;
  document.getElementById('cm-tab-expense').classList.toggle('active', kind === 'expense');
  document.getElementById('cm-tab-income').classList.toggle('active', kind === 'income');
  document.getElementById('cm-tip-text').textContent = kind === 'expense'
    ? '拖动右侧 ⠿ 可调整顺序。预设分类不能删除，但可以隐藏，隐藏后记账时不会出现。'
    : '拖动右侧 ⠿ 可调整顺序。预设分类不能删除，但可以隐藏，隐藏后记账时不会出现。';
  renderCategoryList();
}

function toggleHiddenShown() {
  cmShowHidden = !cmShowHidden;
  document.getElementById('cm-toggle-hidden').textContent = cmShowHidden ? '隐藏已隐藏' : '显示已隐藏';
  renderCategoryList();
}

// ---------- 列表渲染 ----------
function renderCategoryList() {
  const list = document.getElementById('cm-list');
  const all = categories[cmType].slice().sort((a, b) => a.order - b.order);
  const shown = cmShowHidden ? all : all.filter(c => !c.hidden);

  list.innerHTML = shown.map(c => {
    const badges = [];
    badges.push(c.preset
      ? '<span class="cm-badge preset">预设</span>'
      : '<span class="cm-badge custom">自定义</span>');
    if (c.hidden) badges.push('<span class="cm-badge off">已隐藏</span>');
    if (cmType === 'expense' && c.necessity && c.necessity !== 'unset') {
      badges.push(c.necessity === 'must'
        ? '<span class="cm-badge must">必须花的</span>'
        : '<span class="cm-badge flex">可省的</span>');
    }
    if (cmType === 'income' && c.stability && c.stability !== 'unset') {
      badges.push(c.stability === 'fixed'
        ? '<span class="cm-badge fixed">每月都有</span>'
        : '<span class="cm-badge flex">偶尔才有</span>');
    }

    const iconHtml = c.icon && c.icon.kind === 'image'
      ? '<img src="' + c.icon.value + '" alt="">'
      : '<span class="cm-emoji">' + (c.icon && c.icon.value ? c.icon.value : c.name.slice(0, 1)) + '</span>';

    const meta = '排序 ' + (c.order + 1) +
      (c.updatedAt ? ' · 改于 ' + new Date(c.updatedAt).toLocaleDateString('zh-CN') : '');

    return '<div class="cm-item' + (c.hidden ? ' hidden-cat' : '') + '" data-id="' + c.id + '" draggable="true" ' +
      'ondragstart="cmDragStart(event,\'' + c.id + '\')" ' +
      'ondragover="cmDragOver(event)" ' +
      'ondrop="cmDrop(event,\'' + c.id + '\')" ' +
      'ondragend="cmDragEnd(event)">' +

      '<span class="cm-drag" title="按住拖动排序">⠿</span>' +

      '<div class="cm-avatar" onclick="openCategoryEditor(\'' + c.id + '\')">' + iconHtml +
        '<span class="cm-cam">📷</span>' +
      '</div>' +

      '<div class="cm-main">' +
        '<div class="cm-name-row">' +
          '<span class="cm-name">' + escapeHtml(c.name) + '</span>' +
          badges.join('') +
        '</div>' +
        '<div class="cm-meta"><span>' + meta + '</span></div>' +
      '</div>' +

      '<div class="cm-ops">' +
        '<button class="cm-input-num cm-sort" title="直接填序号改排序" ' +
          'onclick="promptOrder(\'' + c.id + '\')">' + (c.order + 1) + '</button>' +
        '<button class="cm-btn' + (c.hidden ? '' : ' on') + '" ' +
          'onclick="toggleCategoryHidden(\'' + c.id + '\')">' + (c.hidden ? '已隐藏' : '在用') + '</button>' +
        '<button class="cm-btn" onclick="openCategoryEditor(\'' + c.id + '\')">编辑</button>' +
        (c.preset
          ? '<button class="cm-btn" title="预设分类不能删除" onclick="hintPreset()">✕</button>'
          : '<button class="cm-btn danger" title="删除" onclick="confirmDeleteCategory(\'' + c.id + '\')">🗑</button>') +
      '</div>' +
    '</div>';
  }).join('');

  if (!shown.length) {
    list.innerHTML = '<div class="cm-foot-hint">这里还没有分类，点右上角 ＋ 新建一个。</div>';
  }

  // 统计
  const arr = categories[cmType];
  document.getElementById('cm-count-active').textContent = arr.filter(c => !c.hidden).length;
  document.getElementById('cm-count-hidden').textContent = arr.filter(c => c.hidden).length;
  document.getElementById('cm-count-custom').textContent = arr.filter(c => !c.preset).length;

  document.getElementById('cm-foot-hint').innerHTML = cmType === 'expense'
    ? '「必须花的 / 可省的」由你自己定，不打标记就不参与判断。算"失业能撑几个月"时，只用标了"必须花的"的分类。'
    : '「每月都有 / 偶尔才有」由你自己定，不打标记就不参与判断。标了"每月都有"的会计入每月固定收入。';
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, m => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[m]));
}

function hintPreset() {
  // 设计原则：预设分类不能删，但能隐藏——把出口直接指给用户
  const tip = document.getElementById('cm-tip');
  tip.style.display = 'flex';
  document.getElementById('cm-tip-text').textContent =
    '预设分类不能删除，但可以隐藏——把它切成「已隐藏」就行，记账时不会再出现。';
}

// ---------- 隐藏 / 排序 / 删除 ----------
function toggleCategoryHidden(id) {
  const c = categories[cmType].find(x => x.id === id);
  if (!c) return;
  c.hidden = !c.hidden;
  c.updatedAt = Date.now();
  renderCategoryList();
}

function promptOrder(id) {
  const c = categories[cmType].find(x => x.id === id);
  if (!c) return;
  const total = categories[cmType].length;
  const input = prompt('填一个 1 ~ ' + total + ' 的数字，' + c.name + ' 会排到这个位置', c.order + 1);
  if (input === null) return;
  const target = parseInt(input, 10);
  if (isNaN(target) || target < 1 || target > total) {
    _cmToast('请填 1 ~ ' + total + ' 之间的数字');
    return;
  }
  moveCategoryTo(c, target - 1);
}

// 把 c 插到目标下标，其余顺移
function moveCategoryTo(c, targetIndex) {
  const arr = categories[cmType].slice().sort((a, b) => a.order - b.order);
  const from = arr.indexOf(c);
  if (from < 0 || from === targetIndex) return;
  arr.splice(from, 1);
  arr.splice(targetIndex, 0, c);
  arr.forEach((item, i) => { item.order = i; item.updatedAt = Date.now(); });
  renderCategoryList();
}

function confirmDeleteCategory(id) {
  const c = categories[cmType].find(x => x.id === id);
  if (!c) return;
  if (c.preset) { hintPreset(); return; }
  if (!confirm('删除「' + c.name + '」？\n已记过的账不受影响，这条分类会进回收站，30 天内可恢复。')) return;
  categories[cmType] = categories[cmType].filter(x => x.id !== id);
  categories[cmType].sort((a, b) => a.order - b.order).forEach((item, i) => { item.order = i; });
  _cmToast('已删除「' + c.name + '」，30 天内可在回收站恢复');
  renderCategoryList();
}

// ---------- 拖拽排序 ----------
let cmDragId = null;

function cmDragStart(e, id) {
  cmDragId = id;
  e.dataTransfer.effectAllowed = 'move';
  e.target.closest('.cm-item').style.opacity = '0.4';
}

function cmDragOver(e) {
  e.preventDefault();
  e.dataTransfer.dropEffect = 'move';
}

function cmDrop(e, targetId) {
  e.preventDefault();
  if (!cmDragId || cmDragId === targetId) return;
  const arr = categories[cmType].slice().sort((a, b) => a.order - b.order);
  const target = arr.find(x => x.id === targetId);
  const dragging = arr.find(x => x.id === cmDragId);
  if (!target || !dragging) return;
  moveCategoryTo(dragging, arr.indexOf(target));
}

function cmDragEnd(e) {
  cmDragId = null;
  document.querySelectorAll('.cm-item').forEach(el => { el.style.opacity = ''; });
}

// ---------- 编辑器弹层 ----------
const CM_EMOJI_POOL = ['🍚','🥤','🍎','🥡','🛒','⚡','🏢','🏠','📱','💊','🧻','🚌','⛽','🚕','👕','💄',
  '📖','📰','🧸','🎋','🐱','🎁','🎮','✈️','🍶','🏃','🛋️','💻','🛡️','📄','📦','💰','🏆','🧑‍💻','📈',
  '↩️','🧾','🧧','🔄','🎊','💵','❤️','⭐','🎯','🌱','🚗','🏥','🎓','🐶','🍺','☕','🧊'];

function openCategoryEditor(id) {
  if (id) {
    const c = categories[cmType].find(x => x.id === id);
    if (!c) return;
    cmEditing = JSON.parse(JSON.stringify(c));   // 编辑副本，取消就不落盘
  } else {
    cmEditing = {
      id: null, name: '', kind: cmType,
      order: categories[cmType].length,
      icon: { kind: 'emoji', value: cmType === 'income' ? '💵' : '📦' },
      preset: false, hidden: false,
      necessity: 'unset', stability: 'unset',
      createdAt: Date.now(), updatedAt: Date.now()
    };
  }
  cmRenderEditor();
  openSheet('category-editor-sheet');
}

function cmRenderEditor() {
  const c = cmEditing;
  if (!c) return;

  document.getElementById('cm-editor-title').textContent =
    c.id ? '编辑分类' : (cmType === 'expense' ? '新增支出分类' : '新增收入分类');
  document.getElementById('cm-preset-lock').style.display = c.preset ? 'block' : 'none';

  const nameInput = document.getElementById('cm-name-input');
  nameInput.value = c.name;
  nameInput.classList.remove('invalid');
  document.getElementById('cm-name-count').textContent = c.name.length;

  // 图标区
  const prev = document.getElementById('cm-icon-preview');
  prev.innerHTML = c.icon.kind === 'image'
    ? '<img src="' + c.icon.value + '" alt="">'
    : '<span>' + (c.icon.value || c.name.slice(0, 1) || '·') + '</span>';
  document.getElementById('cm-emoji-grid').innerHTML = CM_EMOJI_POOL.map(e =>
    '<div class="cm-emoji-cell' + (c.icon.kind === 'emoji' && c.icon.value === e ? ' active' : '') +
    '" onclick="cmPickEmoji(\'' + e + '\')">' + e + '</div>').join('');
  document.getElementById('cm-upload-tip').textContent =
    c.icon.kind === 'image' ? '已使用上传的图片，点「恢复默认图标」换回 emoji。'
                            : '不传就用上面的默认图标，JPG / PNG / WEBP / GIF，不超过 512KB。';
  document.getElementById('cm-reset-icon').style.display = c.icon.kind === 'image' ? 'block' : 'none';

  // 排序
  document.getElementById('cm-order-input').value = c.order + 1;
  document.getElementById('cm-order-max').textContent = categories[cmType].length;

  // 隐藏开关
  document.getElementById('cm-hidden-switch').className = 'switch' + (c.hidden ? ' on' : '');
  document.getElementById('cm-hidden-switch').innerHTML = '<i></i>';

  // 类型专属标记
  const mustBox = document.getElementById('cm-must-box');
  const flexBox = document.getElementById('cm-flex-box');
  const fixedBox = document.getElementById('cm-fixed-box');
  mustBox.style.display = cmType === 'expense' ? 'block' : 'none';
  flexBox.style.display = cmType === 'expense' ? 'block' : 'none';
  fixedBox.style.display = cmType === 'income' ? 'block' : 'none';

  if (cmType === 'expense') {
    cmSetChoice('cm-must-choice', c.necessity === 'must' ? 'must' : '');
    cmSetChoice('cm-flex-choice', c.necessity === 'flex' ? 'flex' : '');
  } else {
    cmSetChoice('cm-fixed-choice', c.stability === 'fixed' ? 'fixed' : '');
  }
}

function cmSetChoice(id, val) {
  const box = document.getElementById(id);
  box.querySelectorAll('button').forEach(b => b.classList.toggle('on', b.dataset.v === val));
}

function cmPickEmoji(e) {
  if (!cmEditing) return;
  cmEditing.icon = { kind: 'emoji', value: e };
  cmRenderEditor();
}

function cmResetIcon() {
  if (!cmEditing) return;
  cmEditing.icon = { kind: 'emoji', value: emojiFor(cmEditing.kind, cmEditing.name) || '📦' };
  cmRenderEditor();
}

function onCategoryIconPicked(e) {
  const file = e.target.files && e.target.files[0];
  e.target.value = '';                       // 允许重复选同一张
  if (!file || !cmEditing) return;

  if (CAT_ICON_TYPES.indexOf(file.type) === -1) {
    _cmToast('格式不支持，请选 JPG / PNG / WEBP / GIF');
    return;
  }
  if (file.size > CAT_ICON_MAX_SIZE) {
    _cmToast('图片超过 512KB，换一张小一点的');
    return;
  }
  const reader = new FileReader();
  reader.onload = () => compressCategoryIcon(reader.result, dataUrl => {
    if (!cmEditing) return;
    cmEditing.icon = { kind: 'image', value: dataUrl };
    cmRenderEditor();
  });
  reader.readAsDataURL(file);
}

// 正方裁切 + 压到 96px，图标只占 36px，2x/3x 屏足够，别拿原图塞进本地存储
function compressCategoryIcon(dataUrl, done) {
  const img = new Image();
  img.onload = () => {
    const side = Math.min(img.width, img.height);
    const size = Math.min(96, side);
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, (img.width - side) / 2, (img.height - side) / 2, side, side, 0, 0, size, size);
    done(canvas.toDataURL('image/png'));
  };
  img.src = dataUrl;
}

function cmToggleHidden() {
  if (!cmEditing) return;
  cmEditing.hidden = !cmEditing.hidden;
  cmRenderEditor();
}

function cmChooseMust(v) {
  if (!cmEditing) return;
  cmEditing.necessity = cmEditing.necessity === v ? 'unset' : v;
  cmRenderEditor();
}

function cmChooseFlex(v) {
  if (!cmEditing) return;
  cmEditing.necessity = cmEditing.necessity === v ? 'unset' : v;
  cmRenderEditor();
}

function cmChooseFixed(v) {
  if (!cmEditing) return;
  cmEditing.stability = cmEditing.stability === v ? 'unset' : v;
  cmRenderEditor();
}

function saveCategoryEditor() {
  const c = cmEditing;
  if (!c) return;

  const nameInput = document.getElementById('cm-name-input');
  const name = nameInput.value.trim();
  nameInput.classList.remove('invalid');

  if (name.length < 1 || name.length > 8) {
    nameInput.classList.add('invalid');
    document.getElementById('cm-edit-tip').textContent = '分类名要填 1 ~ 8 个字，太长了记账时显示不下。';
    return;
  }
  const dup = categories[cmType].find(x => x.name === name && x.id !== c.id);
  if (dup) {
    nameInput.classList.add('invalid');
    document.getElementById('cm-edit-tip').textContent = '已经有同名分类「' + name + '」了，换个名字。';
    return;
  }

  c.name = name;
  if (c.icon.kind !== 'image' && !c.icon.value) c.icon.value = emojiFor(c.kind, name);

  // 排序落盘：插到目标位置，其余顺移
  const total = categories[cmType].length;
  const target = Math.max(1, Math.min(total, parseInt(document.getElementById('cm-order-input').value, 10) || 1)) - 1;
  const list = categories[cmType].slice().sort((a, b) => a.order - b.order);

  if (c.id) {
    const old = list.find(x => x.id === c.id);
    if (old) {
      old.name = c.name;
      old.icon = c.icon;
      old.hidden = c.hidden;
      old.necessity = c.necessity;
      old.stability = c.stability;
      old.updatedAt = Date.now();
      moveCategoryTo(old, target);
    }
  } else {
    list.splice(target, 0, c);
    list.forEach((item, i) => { item.order = i; });
    categories[cmType] = list;
  }

  cmEditing = null;
  closeSheet();
  renderCategoryList();
  _cmToast('已保存');
}

// ---------- 供记账弹层调用：渲染可点分类 ----------
function renderCategoryPicker(kind) {
  const box = document.getElementById('cat-picker');
  if (!box) return;
  const list = visibleCategories(kind);
  box.innerHTML = list.map(c => {
    const icon = c.icon.kind === 'image'
      ? '<img src="' + c.icon.value + '" alt="">'
      : '<span>' + (c.icon.value || c.name.slice(0, 1)) + '</span>';
    return '<div class="cat-cell" onclick="selectCategory(\'' + c.id + '\')">' + icon + escapeHtml(c.name) + '</div>';
  }).join('') +
  '<div class="cat-cell" onclick="openCategoryEditor()"><span>＋</span>新建分类</div>';
}

function _cmToast(msg) {
  const t = document.getElementById('cm-toast');
  if (!t) return;
  t.textContent = msg;
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 1600);
}
