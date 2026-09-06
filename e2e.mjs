// E2E (task 4.1): drive the real wasm store through the FFI bridge.
import { readFileSync } from 'node:fs';
const bytes = readFileSync('web/wasm/main.wasm');
const mod = new WebAssembly.Module(bytes, { builtins: ['js-string'] });
const imports = { _: {} };
for (const imp of WebAssembly.Module.imports(mod)) {
  if (imp.module === '_' && imp.kind === 'global') {
    imports._[imp.name] = imp.name;
  }
}
const mtab = new WebAssembly.Instance(mod, imports).exports;

let failures = 0;
function check(name, cond, detail) {
  if (cond) {
    console.log('  ok:', name);
  } else {
    failures += 1;
    console.log('FAIL:', name, detail === undefined ? '' : JSON.stringify(detail));
  }
}

// -- init (no stored config) --
let r = JSON.parse(mtab.mtab_init('', '2025-01-29'));
check('init default config', r.state.config.version === 2 && r.state.config.groups.length === 1 && r.state.config.groups[0].id === 'g0');
check('init clock lunar', r.state.clock.lunar === '乙巳年正月初一', r.state.clock);
check('init clock weekday', r.state.clock.weekday === '星期三', r.state.clock);

// -- bookmark add --
r = JSON.parse(mtab.mtab_dispatch('{"type":"bookmark_add","name":"示例","url":"example.com"}'));
check('add normalizes url', r.state.config.groups[0].bookmarks[0].url === 'https://example.com', r.state.config.groups[0]);
check('add requests save', r.effects.some(e => e.type === 'save'), r.effects);

// -- invalid bookmark url --
r = JSON.parse(mtab.mtab_dispatch('{"type":"bookmark_add","name":"坏","url":"not a url"}'));
check('invalid url notifies', r.effects[0].type === 'notify_error', r.effects);

// -- engine select + search --
r = JSON.parse(mtab.mtab_dispatch('{"type":"engine_select","id":"bing"}'));
check('engine select', r.state.config.search.current === 'bing');
r = JSON.parse(mtab.mtab_dispatch('{"type":"search_submit","query":"moonbit 语言"}'));
check(
  'search builds url',
  r.effects[0].url === 'https://www.bing.com/search?q=moonbit%20%E8%AF%AD%E8%A8%80',
  r.effects,
);
r = JSON.parse(mtab.mtab_dispatch('{"type":"search_submit","query":"   "}'));
check('empty query no-op', r.effects.length === 0, r.effects);

// -- widget toggle + wallpaper --
r = JSON.parse(mtab.mtab_dispatch('{"type":"widget_toggle","widget":"clock"}'));
check('clock off', r.state.config.widgets.clock === false);
r = JSON.parse(mtab.mtab_dispatch('{"type":"wallpaper_set_custom","data":"data:image/jpeg;base64,QUJD"}'));
check('custom wallpaper', r.state.config.wallpaper.type === 'custom', r.state.config.wallpaper);

// -- config export shape (persisted config is the export format) --
const exported = JSON.stringify(r.state.config);
check('export has version', JSON.parse(exported).version === 2);

// -- config import round-trip into a fresh instance --
const mod2 = new WebAssembly.Module(bytes, { builtins: ['js-string'] });
const mtab2 = new WebAssembly.Instance(mod2, { _: imports._ }).exports;
const r2 = JSON.parse(mtab2.mtab_init(exported, '2025-07-25'));
check('import restores bookmarks', r2.state.config.groups[0].bookmarks.length === 1, r2.state.config.groups);
check('import restores wallpaper', r2.state.config.wallpaper.data === 'data:image/jpeg;base64,QUJD');
check('init leap month', r2.state.clock.lunar === '乙巳年闰六月初一', r2.state.clock);

// -- invalid import keeps current state --
r = JSON.parse(mtab.mtab_dispatch('{"type":"config_import","json":"{{broken"}'));
check('bad import notifies', r.effects[0].type === 'notify_error', r.effects);

// -- search history (search-history change) --
// input on empty query returns recent history: last submitted first
r = JSON.parse(mtab.mtab_dispatch('{"type":"search_input","query":"","at":9000}'));
check(
  'empty input suggests most recent first',
  r.state.suggestions.map(s => s.query).join(',') === 'moonbit 语言',
  r.state.suggestions,
);
// prefix filter is case-insensitive
r = JSON.parse(mtab.mtab_dispatch('{"type":"search_submit","query":"MoonBit 教程","at":9500}'));
r = JSON.parse(mtab.mtab_dispatch('{"type":"search_input","query":"moonbit","at":9600}'));
check(
  'prefix filter is case-insensitive',
  r.state.suggestions.map(s => s.query).join(',') === 'MoonBit 教程,moonbit 语言',
  r.state.suggestions,
);
// repeat submit bumps count instead of duplicating
r = JSON.parse(mtab.mtab_dispatch('{"type":"search_submit","query":"MoonBit 教程","at":9700}'));
const hist = r.state.config.search.history;
check(
  'repeat submit bumps count',
  hist.length === 2 &&
    hist.find(h => h.query === 'MoonBit 教程').count === 2 &&
    hist.find(h => h.query === 'MoonBit 教程').lastUsedMs === 9700,
  hist,
);
// single delete removes only that entry
r = JSON.parse(mtab.mtab_dispatch('{"type":"history_delete","query":"moonbit 语言"}'));
check(
  'history_delete removes the entry',
  r.state.config.search.history.map(h => h.query).join(',') === 'MoonBit 教程',
  r.state.config.search.history,
);
// clear empties everything and persists
r = JSON.parse(mtab.mtab_dispatch('{"type":"history_clear"}'));
check(
  'history_clear empties history and suggests nothing',
  r.state.config.search.history.length === 0 && r.state.suggestions.length === 0,
  r.state,
);
// old config (no history field) imports cleanly with empty history
const legacy = JSON.stringify({ version: 1, bookmarks: [], search: { engines: [], current: 'baidu' }, widgets: { clock: true, bookmarks: true }, wallpaper: { type: 'builtin', id: 'w1' } });
r = JSON.parse(mtab.mtab_dispatch(`{"type":"config_import","json":${JSON.stringify(legacy)}}`));
check('legacy config imports with empty history', r.state.config.search.history.length === 0, r.state.config.search);

// -- bookmark groups lifecycle (bookmark-groups change) --
const modG = new WebAssembly.Module(bytes, { builtins: ['js-string'] });
const mtabG = new WebAssembly.Instance(modG, { _: imports._ }).exports;
let rg = JSON.parse(mtabG.mtab_init('', '2025-01-29'));
// v1 file migration: flat bookmarks land in the default group in order
const v1file = JSON.stringify({ version: 1, bookmarks: [
  { id: 'b1', name: '甲', url: 'https://a.com' },
  { id: 'b2', name: '乙', url: 'https://b.com' },
], search: { engines: [], current: 'baidu' }, widgets: { clock: true, bookmarks: true }, wallpaper: { type: 'builtin', id: 'w1' } });
rg = JSON.parse(mtabG.mtab_dispatch(`{"type":"config_import","json":${JSON.stringify(v1file)}}`));
check('v1 import migrates into default group in order',
  rg.state.config.groups.length === 1 &&
  rg.state.config.groups[0].bookmarks.map(b => b.id).join(',') === 'b1,b2',
  rg.state.config.groups);
// group lifecycle: add -> add bookmark -> rename -> bookmark_move -> delete
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"group_add","name":"工作"}'));
check('group_add appends g1', rg.state.config.groups[1].id === 'g1');
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"bookmark_add","name":"丙","url":"c.com","group":"g1"}'));
check('add into named group lands there', rg.state.config.groups[1].bookmarks[0].id === 'b3');
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"group_rename","id":"g1","name":"学习"}'));
check('group_rename updates the name', rg.state.config.groups[1].name === '学习');
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"group_move","id":"g1","to_index":0}'));
check('group_move keeps g0 first', rg.state.config.groups.map(g => g.id).join(',') === 'g0,g1');
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"bookmark_move","id":"b2","to_group":"g1","to_index":0}'));
check('bookmark_move crosses groups',
  rg.state.config.groups[1].bookmarks.map(b => b.id).join(',') === 'b2,b3' &&
  rg.state.config.groups[0].bookmarks.map(b => b.id).join(',') === 'b1');
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"group_delete","id":"g1"}'));
check('group_delete falls bookmarks back into g0 in order',
  rg.state.config.groups.length === 1 &&
  rg.state.config.groups[0].bookmarks.map(b => b.id).join(',') === 'b1,b2,b3',
  rg.state.config.groups[0]);
// g0 protection
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"group_delete","id":"g0"}'));
check('g0 delete is refused', rg.effects[0].type === 'notify_error');
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"group_rename","id":"g0","name":"x"}'));
check('g0 rename is refused', rg.effects[0].type === 'notify_error');

// -- group collapse + wallpaper blur (group-collapse-blur change) --
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"group_add","name":"可折叠"}'));
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"group_toggle_collapse","id":"g1"}'));
check('collapse toggles on and saves',
  rg.state.config.groups[1].collapsed === true && rg.effects[0].type === 'save');
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"group_toggle_collapse","id":"g1"}'));
check('collapse toggles back off',
  rg.state.config.groups[1].collapsed === false);
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"group_toggle_collapse","id":"zz"}'));
check('collapse of missing group notifies', rg.effects[0].type === 'notify_error');
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"wallpaper_blur_set","amount":99}'));
check('blur clamps to 20 and saves',
  rg.state.config.wallpaperBlur === 20 && rg.effects[0].type === 'save');
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"wallpaper_blur_set","amount":-5}'));
check('blur clamps to 0',
  rg.state.config.wallpaperBlur === 0 && rg.effects[0].type === 'save');
rg = JSON.parse(mtabG.mtab_dispatch('{"type":"wallpaper_blur_set","amount":0}'));
check('blur no-op when unchanged', rg.effects.length === 0);

// -- pinyin suggestions (pinyin-suggest change) --
const modP = new WebAssembly.Module(bytes, { builtins: ['js-string'] });
const mtabP = new WebAssembly.Instance(modP, { _: imports._ }).exports;
let rp = JSON.parse(mtabP.mtab_init('', '2025-01-29'));
rp = JSON.parse(mtabP.mtab_dispatch('{"type":"search_submit","query":"春节","at":1000}'));
rp = JSON.parse(mtabP.mtab_dispatch('{"type":"search_submit","query":"中秋节","at":1100}'));
rp = JSON.parse(mtabP.mtab_dispatch('{"type":"search_input","query":"chun","at":1200}'));
check('full pinyin matches 春节',
  rp.state.suggestions.map(s => s.query).join(',') === '春节', rp.state.suggestions);
rp = JSON.parse(mtabP.mtab_dispatch('{"type":"search_input","query":"zqj","at":1200}'));
check('initials match 中秋节',
  rp.state.suggestions.map(s => s.query).join(',') === '中秋节', rp.state.suggestions);
rp = JSON.parse(mtabP.mtab_dispatch('{"type":"search_input","query":"zzz","at":1200}'));
check('no pinyin match is empty', rp.state.suggestions.length === 0);

// -- solar terms & festivals (solar-terms-festivals change) --// fresh instance on a festival day: 2025-01-29 春节 (festival wins)
const mod3 = new WebAssembly.Module(bytes, { builtins: ['js-string'] });
const mtab3 = new WebAssembly.Instance(mod3, { _: imports._ }).exports;
const r3 = JSON.parse(mtab3.mtab_init('', '2025-01-29'));
check(
  'init on 春节 carries festival, not term',
  r3.state.clock.festival === '春节' && r3.state.clock.solar_term === undefined,
  r3.state.clock,
);
// fresh instance on a term day: 2025-10-08 寒露
const mod4 = new WebAssembly.Module(bytes, { builtins: ['js-string'] });
const mtab4 = new WebAssembly.Instance(mod4, { _: imports._ }).exports;
const r4 = JSON.parse(mtab4.mtab_init('', '2025-10-08'));
check(
  'init on 2025-10-08 carries 寒露',
  r4.state.clock.solar_term === '寒露' && r4.state.clock.festival === undefined,
  r4.state.clock,
);
// tick_date moves off the term day
const r5 = JSON.parse(mtab4.mtab_dispatch('{"type":"tick_date","date":"2025-10-07"}'));
check('tick_date off term day clears it', r5.state.clock.solar_term === undefined, r5.state.clock);

// -- unknown event --
r = JSON.parse(mtab.mtab_dispatch('{"type":"nope"}'));
check('unknown event notifies', r.effects[0].type === 'notify_error', r.effects);
r = JSON.parse(mtab.mtab_dispatch('not json'));
check('garbage event notifies', r.effects[0].type === 'notify_error', r.effects);

console.log(failures === 0 ? 'ALL E2E CHECKS PASSED' : failures + ' FAILURES');
process.exit(failures === 0 ? 0 : 1);
