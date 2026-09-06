// mtab JS bridge and rendering shell (design D1/D2/D5).
//
// Responsibilities: collect events -> wasm dispatch -> redraw affected
// partitions -> execute effects (save/open_url/notify_error). The wasm side
// owns all business logic; this file never decides anything the store can.

const STORAGE_KEY = 'mtab.config';
const WALLPAPERS = ['w1', 'w2', 'w3', 'w4'];
const wallpaperUrl = id => `wallpapers/${id}.svg`;

/** Load the wasm-gc module with JS string builtins (task 1.2 spike result). */
async function loadWasm() {
  const bytes = await (await fetch('wasm/main.wasm')).arrayBuffer();
  const mod = new WebAssembly.Module(bytes, { builtins: ['js-string'] });
  // String literals arrive as imported globals under module "_" whose name
  // is the literal content. Materialize them by hand: engine-independent.
  const imports = { _: {} };
  for (const imp of WebAssembly.Module.imports(mod)) {
    if (imp.module === '_' && imp.kind === 'global') {
      imports._[imp.name] = imp.name;
    }
  }
  return new WebAssembly.Instance(mod, imports).exports;
}

// ---- state ----

const wasm = await loadWasm();
let config = null; // current state.config
let clockView = null; // current state.clock
let suggestions = []; // current state.suggestions (transient view)
let editingBookmarkId = null; // bookmark form mode

function todayStr() {
  const d = new Date();
  const p = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

function apply(response) {
  config = response.state.config;
  clockView = response.state.clock;
  const prevSuggestions = suggestions;
  suggestions = response.state.suggestions || [];
  runEffects(response.effects);
  renderAll();
  // the suggestion dropdown is its own partition: re-render only when the
  // suggestion list actually changed (bookmark events must not touch it)
  if (suggestions !== prevSuggestions && suggestionsChanged(prevSuggestions, suggestions)) {
    renderSuggestions();
  }
}

function suggestionsChanged(a, b) {
  if (a.length !== b.length) {
    return true;
  }
  for (let i = 0; i < a.length; i++) {
    if (a[i].query !== b[i].query || a[i].count !== b[i].count) {
      return true;
    }
  }
  return false;
}

function dispatch(event) {
  apply(JSON.parse(wasm.mtab_dispatch(JSON.stringify(event))));
}

// ---- effects (design D2) ----

function runEffects(effects) {
  for (const eff of effects) {
    switch (eff.type) {
      case 'save':
        try {
          localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
        } catch (e) {
          toast('保存失败：本地存储空间不足');
        }
        break;
      case 'open_url':
        window.location.href = eff.url; // search-box spec: current tab
        break;
      case 'notify_error':
        toast(eff.message);
        break;
    }
  }
}

let toastTimer = null;
function toast(message, type = 'error') {
  const el = document.getElementById('toast');
  el.textContent = message;
  el.classList.toggle('success', type === 'success');
  el.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (el.hidden = true), 3000);
}

// ---- rendering: one function per partition (design D5) ----

function renderAll() {
  renderClock();
  renderEngineBar();
  renderBookmarks();
  applyWallpaper();
  syncSettingsControls();
}

// clock: seconds tick locally; date line comes from wasm (design D4)
function renderClock() {
  const el = document.getElementById('clock');
  el.hidden = !config.widgets.clock;
  if (!config.widgets.clock) {
    return;
  }
  updateClockTime();
  const d = new Date();
  // festival wins the slot, jieqi only on non-festival days (spec priority)
  const special = clockView
    ? (clockView.festival || clockView.solar_term || '')
    : '';
  const parts = [
    `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`,
    clockView ? clockView.weekday : '',
    special,
    clockView && clockView.lunar ? clockView.lunar : '',
  ].filter(Boolean);
  document.getElementById('clock-date').textContent = parts.join(' · ');
}

function updateClockTime() {
  const d = new Date();
  const p = n => String(n).padStart(2, '0');
  document.getElementById('clock-time').textContent =
    `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

// search: only the engine bar is state-driven; the input is never re-rendered
// so focus and draft text survive (design D5).
function renderEngineBar() {
  const bar = document.getElementById('engine-bar');
  bar.replaceChildren();
  for (const engine of config.search.engines) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = engine.name;
    btn.classList.toggle('active', engine.id === config.search.current);
    btn.addEventListener('click', () => {
      dispatch({ type: 'engine_select', id: engine.id });
      document.getElementById('search-input').focus();
    });
    bar.appendChild(btn);
  }
}

function submitSearch() {
  const input = document.getElementById('search-input');
  dispatch({ type: 'search_submit', query: input.value, at: Date.now() });
  hideSuggestions();
}

// suggestions: transient view partition (search-history design D3/D6).
// The input element itself is never re-rendered; only the dropdown is.
let suggestIndex = -1; // highlighted entry, -1 = none (shell-local UI state)

function renderSuggestions() {
  const box = document.getElementById('search-suggest');
  box.replaceChildren();
  const list = suggestions || [];
  const input = document.getElementById('search-input');
  input.setAttribute('aria-expanded', String(list.length > 0));
  if (list.length === 0) {
    box.hidden = true;
    suggestIndex = -1;
    return;
  }
  let idx = 0;
  for (const entry of list) {
    const i = idx++;
    const item = document.createElement('div');
    item.className = 'suggest-item';
    item.setAttribute('role', 'option');
    item.dataset.query = entry.query;
    item.dataset.index = String(i);
    const text = document.createElement('span');
    text.className = 'suggest-text';
    text.textContent = entry.query;
    item.appendChild(text);
    const count = document.createElement('span');
    count.className = 'suggest-count';
    count.textContent = `×${entry.count}`;
    item.appendChild(count);
    const del = document.createElement('button');
    del.type = 'button';
    del.className = 'suggest-del';
    del.title = '删除该条历史';
    del.textContent = '✕';
    item.appendChild(del);
    box.appendChild(item);
  }
  suggestIndex = -1; // fresh render resets highlight (design D6)
  box.hidden = false;
}

function hideSuggestions() {
  const box = document.getElementById('search-suggest');
  box.hidden = true;
  suggestIndex = -1;
  document.getElementById('search-input').setAttribute('aria-expanded', 'false');
}

function highlightedQuery() {
  const box = document.getElementById('search-suggest');
  const el = box.querySelector(`.suggest-item[data-index="${suggestIndex}"]`);
  return el ? el.dataset.query : null;
}

function moveHighlight(delta) {
  const box = document.getElementById('search-suggest');
  const items = [...box.querySelectorAll('.suggest-item')];
  if (items.length === 0) {
    return;
  }
  suggestIndex = Math.min(items.length - 1, Math.max(-1, suggestIndex + delta));
  for (let el of items) {
    el.classList.toggle('active', Number(el.dataset.index) === suggestIndex);
    el.setAttribute('aria-selected', String(Number(el.dataset.index) === suggestIndex));
  }
}

// bookmarks: group sections rebuilt on data change, interactions via
// delegation (bookmark-groups design D4)
function renderBookmarks() {
  const section = document.getElementById('bookmarks');
  section.hidden = !config.widgets.bookmarks;
  if (!config.widgets.bookmarks) {
    return;
  }
  const container = document.getElementById('bm-groups');
  const empty = document.getElementById('bm-empty');
  container.replaceChildren();
  const total = config.groups.reduce((n, g) => n + g.bookmarks.length, 0);
  // global empty state only when just the default group exists and it is
  // empty (keeps the legacy empty-state copy and its assertions intact)
  empty.hidden = !(total === 0 && config.groups.length === 1);
  for (const group of config.groups) {
    container.appendChild(groupNode(group));
  }
}

function groupNode(group) {
  const section = document.createElement('section');
  section.className = 'bm-group';
  section.dataset.gid = group.id;

  const header = document.createElement('div');
  header.className = 'bm-group-header';
  const drag = document.createElement('span');
  drag.className = 'bm-group-drag';
  drag.textContent = '⋮⋮';
  drag.title = '拖动排序分组';
  header.appendChild(drag);
  const name = document.createElement('span');
  name.className = 'bm-group-name';
  name.textContent = group.name;
  header.appendChild(name);
  const isDefault = group.id === 'g0';
  if (!isDefault) {
    const ops = document.createElement('span');
    ops.className = 'bm-group-ops';
    const rename = document.createElement('button');
    rename.type = 'button';
    rename.className = 'bm-group-rename';
    rename.title = '重命名分组';
    rename.textContent = '✎';
    ops.appendChild(rename);
    const del = document.createElement('button');
    del.type = 'button';
    del.className = 'bm-group-del';
    del.title = '删除分组（书签移回默认分组）';
    del.textContent = '🗑';
    ops.appendChild(del);
    header.appendChild(ops);
  }
  section.appendChild(header);

  const grid = document.createElement('div');
  grid.className = 'bm-grid';
  for (const bm of group.bookmarks) {
    grid.appendChild(bookmarkNode(bm));
  }
  section.appendChild(grid);

  if (group.bookmarks.length === 0) {
    const hint = document.createElement('div');
    hint.className = 'bm-group-empty';
    hint.textContent = '拖动书签到这个分组';
    section.appendChild(hint);
  }
  return section;
}

function bookmarkNode(bm) {
  const item = document.createElement('div');
  item.className = 'bookmark';
  item.dataset.id = bm.id;
  item.dataset.url = bm.url;
  item.title = bm.url;

  const icon = document.createElement('img');
  icon.alt = '';
  icon.src = faviconFor(bm.url);
  icon.loading = 'lazy';
  icon.addEventListener('error', () => replaceWithFallback(icon, bm.name));
  item.appendChild(icon);

  const name = document.createElement('div');
  name.className = 'bm-name';
  name.textContent = bm.name;
  item.appendChild(name);

  const ops = document.createElement('div');
  ops.className = 'bm-ops';
  const edit = document.createElement('button');
  edit.type = 'button';
  edit.title = '编辑';
  edit.textContent = '✎';
  edit.className = 'bm-edit';
  ops.appendChild(edit);
  const del = document.createElement('button');
  del.type = 'button';
  del.title = '删除';
  del.textContent = '✕';
  del.className = 'bm-delete';
  ops.appendChild(del);
  item.appendChild(ops);
  return item;
}

function replaceWithFallback(img, name) {
  const span = document.createElement('div');
  span.className = 'bm-fallback';
  // first character of the bookmark name (bookmark-grid spec: icon fallback)
  const first = (name || '?').trim().charAt(0) || '?';
  span.textContent = first.toUpperCase();
  img.replaceWith(span);
}

function faviconFor(url) {
  try {
    return `https://${new URL(url).host}/favicon.ico`;
  } catch {
    return 'data:,';
  }
}

// ---- pointer drag & drop (bookmark-groups design D3) ----
// JS reports geometry only; the store decides the outcome via
// bookmark_move / group_move. Clicks (sub-threshold) pass through.

const DRAG_THRESHOLD_PX = 6;
let dragState = null; // { kind: 'bookmark'|'group', id, started, fromGroup, fromIndex, indicator }

function dragEvents() {
  const groupsEl = document.getElementById('bm-groups');
  // pointerdown on a bookmark card or group drag handle
  groupsEl.addEventListener('pointerdown', e => {
    if (e.button !== 0) {
      return;
    }
    const groupSection = e.target.closest('.bm-group');
    if (!groupSection) {
      return;
    }
    const card = e.target.closest('.bookmark');
    const handle = e.target.closest('.bm-group-drag');
    if (card) {
      dragState = {
        kind: 'bookmark',
        id: card.dataset.id,
        fromGroup: groupSection.dataset.gid,
        startX: e.clientX,
        startY: e.clientY,
        started: false,
        card,
      };
    } else if (handle) {
      dragState = {
        kind: 'group',
        id: groupSection.dataset.gid,
        startX: e.clientX,
        startY: e.clientY,
        started: false,
        section: groupSection,
      };
    }
  });
  document.addEventListener('pointermove', e => {
    if (!dragState) {
      return;
    }
    const dx = e.clientX - dragState.startX;
    const dy = e.clientY - dragState.startY;
    if (!dragState.started) {
      if (dx * dx + dy * dy < DRAG_THRESHOLD_PX * DRAG_THRESHOLD_PX) {
        return;
      }
      dragState.started = true;
      document.body.classList.add('dragging');
      if (dragState.kind === 'bookmark') {
        dragState.card.classList.add('drag-source');
      } else {
        dragState.section.classList.add('drag-source');
      }
    }
    updateDropIndicator(e);
  });
  document.addEventListener('pointerup', e => {
    if (!dragState) {
      return;
    }
    const state = dragState;
    dragState = null;
    document.body.classList.remove('dragging');
    clearIndicator();
    if (!state.started) {
      return; // plain click: existing delegation handles it
    }
    if (state.kind === 'bookmark') {
      state.card.classList.remove('drag-source');
      const hit = hitTestBookmark(e);
      if (hit) {
        dispatch({
          type: 'bookmark_move',
          id: state.id,
          to_group: hit.gid,
          to_index: hit.index,
        });
      }
    } else {
      state.section.classList.remove('drag-source');
      const hit = hitTestGroup(e);
      if (hit !== null) {
        dispatch({ type: 'group_move', id: state.id, to_index: hit });
      }
    }
  });
}

/// Where would a dropped bookmark land: { gid, index } or null.
function hitTestBookmark(e) {
  const grid = gridAtPoint(e.clientX, e.clientY);
  if (!grid) {
    return null;
  }
  const cards = [...grid.querySelectorAll('.bookmark:not(.drag-source)')];
  const gridRect = grid.getBoundingClientRect();
  let index = cards.length;
  for (let i = 0; i < cards.length; i++) {
    const r = cards[i].getBoundingClientRect();
    if (e.clientX < r.left + r.width / 2) {
      index = i;
      break;
    }
  }
  // empty grids / below all cards: append (gridRect unused, kept for clarity)
  void gridRect;
  return { gid: grid.closest('.bm-group').dataset.gid, index };
}

/// Which absolute group index a dropped group header lands on (or null).
function hitTestGroup(e) {
  const sections = [...document.querySelectorAll('.bm-group')];
  let target = null;
  for (let i = 0; i < sections.length; i++) {
    const r = sections[i].getBoundingClientRect();
    if (e.clientY < r.top + r.height / 2) {
      target = i;
      break;
    }
  }
  if (target === null) {
    target = sections.length - 1;
  }
  return target;
}

function gridAtPoint(x, y) {
  const grids = [...document.querySelectorAll('.bm-group .bm-grid')];
  // pick the grid whose bounding box contains the point; fall back to the
  // nearest one vertically (a drop slightly outside still counts)
  let best = null;
  let bestDist = Infinity;
  for (const g of grids) {
    const r = g.getBoundingClientRect();
    let inside = x >= r.left && x <= r.right && y >= r.top && y <= r.bottom;
    let dist = inside
      ? 0
      : Math.max(r.top - y, 0, y - r.bottom);
    if (dist < bestDist) {
      bestDist = dist;
      best = g;
    }
  }
  return bestDist <= 120 ? best : null;
}

/// Insertion indicator line (pure DOM, removed on drop).
function updateDropIndicator(e) {
  clearIndicator();
  if (dragState.kind === 'bookmark') {
    const hit = hitTestBookmark(e);
    if (!hit) {
      return;
    }
    const grid = gridAtPoint(e.clientX, e.clientY);
    const cards = [...grid.querySelectorAll('.bookmark:not(.drag-source)')];
    const card = cards[Math.min(hit.index, cards.length - 1)];
    if (card) {
      card.classList.add(hit.index >= cards.length ? 'drag-indicator after' : 'drag-indicator');
    }
  }
  // group drag indicator: subtle, the section highlight suffices
}

function clearIndicator() {
  for (const el of document.querySelectorAll('.drag-indicator')) {
    el.classList.remove('drag-indicator', 'after');
  }
}

// wallpaper: two-layer crossfade (design D4) — background-image itself
// cannot transition, so the new image fades in on the layer that is
// currently hidden, then the layers swap roles.
// The image is decoded BEFORE the fade starts: a large custom image that
// finishes decoding after the fade would pop in hard (ui-a11y-polish D1).
let activeWallpaperLayer = null;
let currentWallpaperImage = '';
let wallpaperRequestId = 0;
function applyWallpaper() {
  const wp = config.wallpaper;
  const image = wp.type === 'custom' ? wp.data : wallpaperUrl(wp.id);
  if (image === currentWallpaperImage) {
    return;
  }
  const request = ++wallpaperRequestId;
  currentWallpaperImage = image;
  const img = new Image();
  img.src = image;
  // decode (or its failure) settles the fade; a timeout guards against
  // environments where decode never completes (headless virtual time)
  // and against unreasonably slow decodes blocking "takes effect
  // immediately" (configuration spec). Same reveal path either way.
  const decoded = img.decode().then(
    () => {},
    () => {},
  );
  const timeout = new Promise(resolve => setTimeout(resolve, 800));
  Promise.race([decoded, timeout]).then(() => revealWallpaper(image, request));
}

function revealWallpaper(image, request) {
  // a newer switch superseded this one while it was decoding
  if (request !== wallpaperRequestId) {
    return;
  }
  const layers = [
    document.getElementById('wallpaper-a'),
    document.getElementById('wallpaper-b'),
  ];
  const prev = activeWallpaperLayer;
  const next = layers.find(l => l !== prev);
  next.style.backgroundImage = `url("${image}")`;
  next.classList.add('visible');
  activeWallpaperLayer = next;
  if (prev) {
    setTimeout(() => {
      // guard: a newer switch may already have re-activated this layer
      if (prev !== activeWallpaperLayer) {
        prev.classList.remove('visible');
      }
    }, 450);
  }
}

// settings panel controls reflect state
function syncSettingsControls() {
  document.getElementById('toggle-clock').checked = config.widgets.clock;
  document.getElementById('toggle-bookmarks').checked = config.widgets.bookmarks;
  const list = document.getElementById('wallpaper-list');
  for (const btn of list.querySelectorAll('button')) {
    const active =
      config.wallpaper.type === 'builtin' && config.wallpaper.id === btn.dataset.wp;
    btn.classList.toggle('active', active);
  }
}

function buildWallpaperList() {
  const list = document.getElementById('wallpaper-list');
  for (const id of WALLPAPERS) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.dataset.wp = id;
    btn.style.backgroundImage = `url("${wallpaperUrl(id)}")`;
    btn.title = `内置壁纸 ${id}`;
    btn.addEventListener('click', () => {
      dispatch({ type: 'wallpaper_set_builtin', id });
    });
    list.appendChild(btn);
  }
}

// ---- bookmark form ----

/// Locate a bookmark across all groups: { bm, gid } or null.
function findBookmark(id) {
  for (const g of config.groups) {
    for (const b of g.bookmarks) {
      if (b.id === id) {
        return { bm: b, gid: g.id };
      }
    }
  }
  return null;
}

/// Rebuild the form's group dropdown from state.
function syncGroupSelect(selected) {
  const select = document.getElementById('bm-form-group');
  select.replaceChildren();
  for (const g of config.groups) {
    const opt = document.createElement('option');
    opt.value = g.id;
    opt.textContent = g.name;
    select.appendChild(opt);
  }
  if (selected) {
    select.value = selected;
  } else {
    select.value = config.groups[0] ? config.groups[0].id : '';
  }
}

function openBookmarkForm(bookmark, gid) {
  editingBookmarkId = bookmark ? bookmark.id : null;
  document.getElementById('bm-form-title').textContent = bookmark
    ? '编辑书签'
    : '添加书签';
  const form = document.getElementById('bm-form');
  form.elements.name.value = bookmark ? bookmark.name : '';
  form.elements.url.value = bookmark ? bookmark.url : '';
  syncGroupSelect(gid || null);
  document.getElementById('bm-form-error').hidden = true;
  document.getElementById('bm-modal').hidden = false;
  form.elements.url.focus();
}

function closeBookmarkForm() {
  document.getElementById('bm-modal').hidden = true;
  editingBookmarkId = null;
}

// ---- wallpaper upload (configuration spec: compress, reject non-image) ----

async function compressWallpaper(file) {
  const bitmap = await createImageBitmap(file);
  const max = 1920;
  const scale = Math.min(1, max / Math.max(bitmap.width, bitmap.height));
  const w = Math.max(1, Math.round(bitmap.width * scale));
  const h = Math.max(1, Math.round(bitmap.height * scale));
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  canvas.getContext('2d').drawImage(bitmap, 0, 0, w, h);
  bitmap.close();
  return canvas.toDataURL('image/jpeg', 0.8);
}

// ---- config import / export (configuration spec) ----

function exportConfig() {
  const blob = new Blob([JSON.stringify(config)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'mtab-config.json';
  a.click();
  URL.revokeObjectURL(a.href);
  toast('已导出配置文件', 'success');
}

function importConfig(file) {
  const reader = new FileReader();
  reader.onload = () => dispatch({ type: 'config_import', json: String(reader.result) });
  reader.readAsText(file);
}

// ---- wiring ----

function wireEvents() {
  // search
  const input = document.getElementById('search-input');
  input.addEventListener('keydown', e => {
    if (e.key === 'Enter') {
      const picked = highlightedQuery();
      if (picked !== null) {
        dispatch({ type: 'search_submit', query: picked, at: Date.now() });
        hideSuggestions();
      } else {
        submitSearch();
      }
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      moveHighlight(1);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      moveHighlight(-1);
    } else if (e.key === 'Escape') {
      hideSuggestions();
    }
  });
  input.addEventListener('input', () => {
    dispatch({ type: 'search_input', query: input.value, at: Date.now() });
  });
  input.addEventListener('focus', () => {
    dispatch({ type: 'search_input', query: input.value, at: Date.now() });
  });
  document.getElementById('search-go').addEventListener('click', submitSearch);

  // suggestion dropdown: delegated clicks (pick entry / delete one)
  document.getElementById('search-suggest').addEventListener('mousedown', e => {
    e.preventDefault(); // keep input focus
    const item = e.target.closest('.suggest-item');
    if (!item) {
      return;
    }
    if (e.target.closest('.suggest-del')) {
      dispatch({ type: 'history_delete', query: item.dataset.query });
      return;
    }
    input.value = item.dataset.query;
    dispatch({ type: 'search_submit', query: item.dataset.query, at: Date.now() });
    hideSuggestions();
  });
  // click outside closes the dropdown
  document.addEventListener('click', e => {
    if (!e.target.closest('#search')) {
      hideSuggestions();
    }
  });

  // bookmark groups: event delegation (design D5); one listener for cards
  // and group-header ops alike
  const groupsEl = document.getElementById('bm-groups');
  groupsEl.addEventListener('click', e => {
    const groupSection = e.target.closest('.bm-group');
    if (groupSection && e.target.closest('.bm-group-rename')) {
      const g = config.groups.find(g => g.id === groupSection.dataset.gid);
      if (g) {
        const name = prompt('新的分组名称', g.name);
        if (name !== null && name.trim() !== '') {
          dispatch({ type: 'group_rename', id: g.id, name });
        }
      }
      return;
    }
    if (groupSection && e.target.closest('.bm-group-del')) {
      dispatch({ type: 'group_delete', id: groupSection.dataset.gid });
      return;
    }
    const item = e.target.closest('.bookmark');
    if (!item) {
      return;
    }
    if (e.target.closest('.bm-edit')) {
      const bm = findBookmark(item.dataset.id);
      openBookmarkForm(bm.bm, bm.gid);
      return;
    }
    if (e.target.closest('.bm-delete')) {
      dispatch({ type: 'bookmark_delete', id: item.dataset.id });
      return;
    }
    window.open(item.dataset.url, '_blank', 'noopener'); // bookmark-grid spec
  });
  dragEvents();

  // new group button
  document.getElementById('group-add').addEventListener('click', () => {
    const name = prompt('分组名称');
    if (name !== null && name.trim() !== '') {
      dispatch({ type: 'group_add', name });
    }
  });

  // toolbar
  document.getElementById('bm-add').addEventListener('click', () => openBookmarkForm(null));
  document.getElementById('settings-open').addEventListener('click', () => {
    document.getElementById('settings-modal').hidden = false;
  });
  document.getElementById('settings-close').addEventListener('click', () => {
    document.getElementById('settings-modal').hidden = true;
  });

  // bookmark form
  const form = document.getElementById('bm-form');
  form.addEventListener('submit', e => {
    e.preventDefault();
    const name = form.elements.name.value.trim();
    const url = form.elements.url.value.trim();
    const group = form.elements.group.value || null;
    if (editingBookmarkId) {
      dispatch({ type: 'bookmark_edit', id: editingBookmarkId, name, url, group });
    } else {
      dispatch({ type: 'bookmark_add', name, url, group });
    }
    closeBookmarkForm();
  });
  document.getElementById('bm-cancel').addEventListener('click', closeBookmarkForm);

  // settings: widget toggles
  document.getElementById('toggle-clock').addEventListener('change', e => {
    // the toggle's own checkbox already flipped; sync back to state on render
    dispatch({ type: 'widget_toggle', widget: 'clock' });
    e.target.checked = config.widgets.clock;
  });
  document.getElementById('toggle-bookmarks').addEventListener('change', e => {
    dispatch({ type: 'widget_toggle', widget: 'bookmarks' });
    e.target.checked = config.widgets.bookmarks;
  });

  // settings: wallpaper upload
  document.getElementById('wallpaper-upload').addEventListener('change', async e => {
    const file = e.target.files[0];
    e.target.value = '';
    if (!file) {
      return;
    }
    if (!file.type.startsWith('image/')) {
      toast('请选择图片文件');
      return; // configuration spec: reject, keep current wallpaper
    }
    try {
      const data = await compressWallpaper(file);
      dispatch({ type: 'wallpaper_set_custom', data });
    } catch {
      toast('图片处理失败，请换一张试试');
    }
  });

  // settings: import / export
  document.getElementById('config-export').addEventListener('click', exportConfig);
  document.getElementById('history-clear').addEventListener('click', () => {
    dispatch({ type: 'history_clear' });
    toast('已清空搜索历史', 'success');
  });
  document.getElementById('config-import').addEventListener('change', e => {
    const file = e.target.files[0];
    e.target.value = '';
    if (file) {
      importConfig(file);
    }
  });
}

// ---- boot ----

function startClock() {
  updateClockTime();
  setInterval(updateClockTime, 1000); // clock-widget spec: seconds tick locally
  // day rollover -> ask wasm for the new lunar/weekday (design D4)
  let lastDay = todayStr();
  setInterval(() => {
    const now = todayStr();
    if (now !== lastDay) {
      lastDay = now;
      dispatch({ type: 'tick_date', date: now });
    }
  }, 30 * 1000);
}

buildWallpaperList();
wireEvents();
apply(
  JSON.parse(wasm.mtab_init(localStorage.getItem(STORAGE_KEY) || '', todayStr())),
);
startClock();
document.getElementById('search-input').focus(); // search-box spec: autofocus

// console handle for manual verification (task 4.1)
window.mtab = {
  dispatch,
  get config() { return config; },
  wallpaperLayer() { return activeWallpaperLayer; },
};
console.info('mtab ready. window.mtab.dispatch({type:...}) to drive the store.');
