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
let editingBookmarkId = null; // bookmark form mode

function todayStr() {
  const d = new Date();
  const p = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

function apply(response) {
  config = response.state.config;
  clockView = response.state.clock;
  runEffects(response.effects);
  renderAll();
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
  const parts = [
    `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`,
    clockView ? clockView.weekday : '',
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
  dispatch({ type: 'search_submit', query: input.value });
}

// bookmarks: grid rebuilt on data change, interactions via delegation
function renderBookmarks() {
  const section = document.getElementById('bookmarks');
  section.hidden = !config.widgets.bookmarks;
  if (!config.widgets.bookmarks) {
    return;
  }
  const grid = document.getElementById('bm-grid');
  const empty = document.getElementById('bm-empty');
  grid.replaceChildren();
  empty.hidden = config.bookmarks.length > 0;
  for (const bm of config.bookmarks) {
    grid.appendChild(bookmarkNode(bm));
  }
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
  img.decode().then(
    () => revealWallpaper(image, request),
    // decode failed (broken data url): apply anyway, "takes effect
    // immediately" must not be blocked (ui-a11y-polish D1 degrade path)
    () => revealWallpaper(image, request),
  );
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

function openBookmarkForm(bookmark) {
  editingBookmarkId = bookmark ? bookmark.id : null;
  document.getElementById('bm-form-title').textContent = bookmark
    ? '编辑书签'
    : '添加书签';
  const form = document.getElementById('bm-form');
  form.elements.name.value = bookmark ? bookmark.name : '';
  form.elements.url.value = bookmark ? bookmark.url : '';
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
  document.getElementById('search-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') {
      submitSearch();
    }
  });
  document.getElementById('search-go').addEventListener('click', submitSearch);

  // bookmark grid: event delegation (design D5)
  const grid = document.getElementById('bm-grid');
  grid.addEventListener('click', e => {
    const item = e.target.closest('.bookmark');
    if (!item) {
      return;
    }
    if (e.target.closest('.bm-edit')) {
      const bm = config.bookmarks.find(b => b.id === item.dataset.id);
      openBookmarkForm(bm);
      return;
    }
    if (e.target.closest('.bm-delete')) {
      dispatch({ type: 'bookmark_delete', id: item.dataset.id });
      return;
    }
    window.open(item.dataset.url, '_blank', 'noopener'); // bookmark-grid spec
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
    if (editingBookmarkId) {
      dispatch({ type: 'bookmark_edit', id: editingBookmarkId, name, url });
    } else {
      dispatch({ type: 'bookmark_add', name, url });
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
