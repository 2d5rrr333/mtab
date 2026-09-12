// E2E (task 4.1): drive the real wasm store through the FFI bridge.
// Loading/instance plumbing comes from the moonwebtest bridge harness
// (github.com/2d5rrr333/moonwebtest, vendored under tools/).
import { loadBridge, makeChecks } from './tools/bridge-harness.mjs';

const WASM = 'web/wasm/main.wasm';
const app = loadBridge(WASM, { init: 'mtab_init', dispatch: 'mtab_dispatch' });
const { check, finish } = makeChecks();

// -- uninitialized dispatch: the null-state error envelope --
{
  const raw = loadBridge(WASM, { init: 'mtab_init', dispatch: 'mtab_dispatch' });
  const r0 = raw.dispatch({ type: 'bookmark_add', name: 'x', url: 'y' });
  check(
    'dispatch before init answers null state + notify_error',
    r0.state === null &&
      r0.effects.length === 1 &&
      r0.effects[0].type === 'notify_error' &&
      r0.effects[0].message === '未初始化',
    r0,
  );
}

// -- init (no stored config) --
let r = app.init('', '2025-01-29');
check('init default config', r.state.config.version === 2 && r.state.config.groups.length === 1 && r.state.config.groups[0].id === 'g0');
check('init clock lunar', r.state.clock.lunar === '乙巳年正月初一', r.state.clock);
check('init clock weekday', r.state.clock.weekday === '星期三', r.state.clock);

// -- starter presets (starter-presets-and-clock) --
check('default config ships starter bookmarks',
  r.state.config.groups[0].bookmarks.length >= 6,
  r.state.config.groups[0].bookmarks.map(b => b.name));
// reset to an empty baseline so the rest of the suite keeps its
// empty-start assumptions (bookmark counts, import top-level, ...)
{
  const cfg = JSON.parse(JSON.stringify(r.state.config));
  cfg.groups = [];
  cfg.countdowns = [];
  r = app.dispatch(
    JSON.stringify({ type: 'config_import', json: JSON.stringify(cfg) }),
  );
}

// -- bookmark add --
r = app.dispatchRaw('{"type":"bookmark_add","name":"示例","url":"example.com"}');
check('add normalizes url', r.state.config.groups[0].bookmarks[0].url === 'https://example.com', r.state.config.groups[0]);
check('add requests save', r.effects.some(e => e.type === 'save'), r.effects);

// -- invalid bookmark url --
r = app.dispatchRaw('{"type":"bookmark_add","name":"坏","url":"not a url"}');
check('invalid url notifies', r.effects[0].type === 'notify_error', r.effects);

// -- engine select + search --
r = app.dispatchRaw('{"type":"engine_select","id":"bing"}');
check('engine select', r.state.config.search.current === 'bing');
r = app.dispatchRaw('{"type":"search_submit","query":"moonbit 语言"}');
check(
  'search builds url',
  r.effects[0].url === 'https://www.bing.com/search?q=moonbit%20%E8%AF%AD%E8%A8%80',
  r.effects,
);
r = app.dispatchRaw('{"type":"search_submit","query":"   "}');
check('empty query no-op', r.effects.length === 0, r.effects);

// -- widget toggle + wallpaper --
r = app.dispatchRaw('{"type":"widget_toggle","widget":"clock"}');
check('clock off', r.state.config.widgets.clock === false);
r = app.dispatchRaw('{"type":"wallpaper_set_custom","data":"data:image/jpeg;base64,QUJD"}');
check('custom wallpaper', r.state.config.wallpaper.type === 'custom', r.state.config.wallpaper);

// -- config export shape (persisted config is the export format) --
const exported = JSON.stringify(r.state.config);
check('export has version', JSON.parse(exported).version === 2);

// -- config import round-trip into a fresh instance --
const mtab2 = app.fresh();
const r2 = mtab2.init(exported, '2025-07-25');
check('import restores bookmarks', r2.state.config.groups[0].bookmarks.length === 1, r2.state.config.groups);
check('import restores wallpaper', r2.state.config.wallpaper.data === 'data:image/jpeg;base64,QUJD');
check('init leap month', r2.state.clock.lunar === '乙巳年闰六月初一', r2.state.clock);

// -- invalid import keeps current state --
r = app.dispatchRaw('{"type":"config_import","json":"{{broken"}');
check('bad import notifies', r.effects[0].type === 'notify_error', r.effects);

// -- search history (search-history change) --
// input on empty query returns recent history: last submitted first
r = app.dispatchRaw('{"type":"search_input","query":"","at":9000}');
check(
  'empty input suggests most recent first',
  r.state.suggestions.map(s => s.query).join(',') === 'moonbit 语言',
  r.state.suggestions,
);
// prefix filter is case-insensitive
r = app.dispatchRaw('{"type":"search_submit","query":"MoonBit 教程","at":9500}');
r = app.dispatchRaw('{"type":"search_input","query":"moonbit","at":9600}');
check(
  'prefix filter is case-insensitive',
  r.state.suggestions.map(s => s.query).join(',') === 'MoonBit 教程,moonbit 语言',
  r.state.suggestions,
);
// repeat submit bumps count instead of duplicating
r = app.dispatchRaw('{"type":"search_submit","query":"MoonBit 教程","at":9700}');
const hist = r.state.config.search.history;
check(
  'repeat submit bumps count',
  hist.length === 2 &&
    hist.find(h => h.query === 'MoonBit 教程').count === 2 &&
    hist.find(h => h.query === 'MoonBit 教程').lastUsedMs === 9700,
  hist,
);
// single delete removes only that entry
r = app.dispatchRaw('{"type":"history_delete","query":"moonbit 语言"}');
check(
  'history_delete removes the entry',
  r.state.config.search.history.map(h => h.query).join(',') === 'MoonBit 教程',
  r.state.config.search.history,
);
// clear empties everything and persists
r = app.dispatchRaw('{"type":"history_clear"}');
check(
  'history_clear empties history and suggests nothing',
  r.state.config.search.history.length === 0 && r.state.suggestions.length === 0,
  r.state,
);
// old config (no history field) imports cleanly with empty history
const legacy = JSON.stringify({ version: 1, bookmarks: [], search: { engines: [], current: 'baidu' }, widgets: { clock: true, bookmarks: true }, wallpaper: { type: 'builtin', id: 'w1' } });
r = app.dispatch(`{"type":"config_import","json":${JSON.stringify(legacy)}}`);
check('legacy config imports with empty history', r.state.config.search.history.length === 0, r.state.config.search);

// -- bookmark groups lifecycle (bookmark-groups change) --
const mtabG = app.fresh();
let rg = mtabG.init('', '2025-01-29');
// v1 file migration: flat bookmarks land in the default group in order
const v1file = JSON.stringify({ version: 1, bookmarks: [
  { id: 'b1', name: '甲', url: 'https://a.com' },
  { id: 'b2', name: '乙', url: 'https://b.com' },
], search: { engines: [], current: 'baidu' }, widgets: { clock: true, bookmarks: true }, wallpaper: { type: 'builtin', id: 'w1' } });
rg = mtabG.dispatch(`{"type":"config_import","json":${JSON.stringify(v1file)}}`);
check('v1 import migrates into default group in order',
  rg.state.config.groups.length === 1 &&
  rg.state.config.groups[0].bookmarks.map(b => b.id).join(',') === 'b1,b2',
  rg.state.config.groups);
// group lifecycle: add -> add bookmark -> rename -> bookmark_move -> delete
rg = mtabG.dispatchRaw('{"type":"group_add","name":"工作"}');
check('group_add appends g1', rg.state.config.groups[1].id === 'g1');
rg = mtabG.dispatchRaw('{"type":"bookmark_add","name":"丙","url":"c.com","group":"g1"}');
check('add into named group lands there', rg.state.config.groups[1].bookmarks[0].id === 'b3');
rg = mtabG.dispatchRaw('{"type":"group_rename","id":"g1","name":"学习"}');
check('group_rename updates the name', rg.state.config.groups[1].name === '学习');
rg = mtabG.dispatchRaw('{"type":"group_move","id":"g1","to_index":0}');
check('group_move keeps g0 first', rg.state.config.groups.map(g => g.id).join(',') === 'g0,g1');
rg = mtabG.dispatchRaw('{"type":"bookmark_move","id":"b2","to_group":"g1","to_index":0}');
check('bookmark_move crosses groups',
  rg.state.config.groups[1].bookmarks.map(b => b.id).join(',') === 'b2,b3' &&
  rg.state.config.groups[0].bookmarks.map(b => b.id).join(',') === 'b1');
rg = mtabG.dispatchRaw('{"type":"group_delete","id":"g1"}');
check('group_delete falls bookmarks back into g0 in order',
  rg.state.config.groups.length === 1 &&
  rg.state.config.groups[0].bookmarks.map(b => b.id).join(',') === 'b1,b2,b3',
  rg.state.config.groups[0]);
// g0 protection
rg = mtabG.dispatchRaw('{"type":"group_delete","id":"g0"}');
check('g0 delete is refused', rg.effects[0].type === 'notify_error');
rg = mtabG.dispatchRaw('{"type":"group_rename","id":"g0","name":"x"}');
check('g0 rename is refused', rg.effects[0].type === 'notify_error');

// -- group collapse + wallpaper blur (group-collapse-blur change) --
rg = mtabG.dispatchRaw('{"type":"group_add","name":"可折叠"}');
rg = mtabG.dispatchRaw('{"type":"group_toggle_collapse","id":"g1"}');
check('collapse toggles on and saves',
  rg.state.config.groups[1].collapsed === true && rg.effects[0].type === 'save');
rg = mtabG.dispatchRaw('{"type":"group_toggle_collapse","id":"g1"}');
check('collapse toggles back off',
  rg.state.config.groups[1].collapsed === false);
rg = mtabG.dispatchRaw('{"type":"group_toggle_collapse","id":"zz"}');
check('collapse of missing group notifies', rg.effects[0].type === 'notify_error');
rg = mtabG.dispatchRaw('{"type":"wallpaper_blur_set","amount":99}');
check('blur clamps to 20 and saves',
  rg.state.config.wallpaperBlur === 20 && rg.effects[0].type === 'save');
rg = mtabG.dispatchRaw('{"type":"wallpaper_blur_set","amount":-5}');
check('blur clamps to 0',
  rg.state.config.wallpaperBlur === 0 && rg.effects[0].type === 'save');
rg = mtabG.dispatchRaw('{"type":"wallpaper_blur_set","amount":0}');
check('blur no-op when unchanged', rg.effects.length === 0);

// -- pinyin suggestions (pinyin-suggest change) --
const mtabP = app.fresh();
let rp = mtabP.init('', '2025-01-29');
rp = mtabP.dispatchRaw('{"type":"search_submit","query":"春节","at":1000}');
rp = mtabP.dispatchRaw('{"type":"search_submit","query":"中秋节","at":1100}');
rp = mtabP.dispatchRaw('{"type":"search_input","query":"chun","at":1200}');
check('full pinyin matches 春节',
  rp.state.suggestions.map(s => s.query).join(',') === '春节', rp.state.suggestions);
rp = mtabP.dispatchRaw('{"type":"search_input","query":"zqj","at":1200}');
check('initials match 中秋节',
  rp.state.suggestions.map(s => s.query).join(',') === '中秋节', rp.state.suggestions);
rp = mtabP.dispatchRaw('{"type":"search_input","query":"zzz","at":1200}');
check('no pinyin match is empty', rp.state.suggestions.length === 0);

// -- solar terms & festivals (solar-terms-festivals change) --// fresh instance on a festival day: 2025-01-29 春节 (festival wins)
const mtab3 = app.fresh();
const r3 = mtab3.init('', '2025-01-29');
check(
  'init on 春节 carries festival, not term',
  r3.state.clock.festival === '春节' && r3.state.clock.solar_term === undefined,
  r3.state.clock,
);
// fresh instance on a term day: 2025-10-08 寒露
const mtab4 = app.fresh();
const r4 = mtab4.init('', '2025-10-08');
check(
  'init on 2025-10-08 carries 寒露',
  r4.state.clock.solar_term === '寒露' && r4.state.clock.festival === undefined,
  r4.state.clock,
);
// tick_date moves off the term day
const r5 = mtab4.dispatchRaw('{"type":"tick_date","date":"2025-10-07"}');
check('tick_date off term day clears it', r5.state.clock.solar_term === undefined, r5.state.clock);

// -- bookmark import (bookmark-import change) --
// fresh instance so the section owns its whole config (pitfall: config_import
// replaces everything; the sections before/after are unaffected anyway)
const mtabI = app.fresh();
let ri = mtabI.init('', '2025-01-29');
// empty baseline: the default config now ships starter bookmarks
{
  const cfg = JSON.parse(JSON.stringify(ri.state.config));
  cfg.groups = [];
  cfg.countdowns = [];
  ri = mtabI.dispatch(
    JSON.stringify({ type: 'config_import', json: JSON.stringify(cfg) }),
  );
}
ri = mtabI.dispatchRaw('{"type":"group_add","name":"工作"}');
const bmHtml = `<!DOCTYPE NETSCAPE-Bookmark-file-1>
<DL><p>
    <DT><H3>工作</H3>
    <DL><p>
        <DT><A HREF="https://e2e.example/?a=1&amp;b=2">重复项</A>
        <DT><A HREF="nested.example.com">嵌套</A>
    </DL><p>
    <DT><A HREF="https://top.example/">顶层</A>
</DL><p>`;
ri = mtabI.dispatch(`{"type":"bookmark_import","html":${JSON.stringify(bmHtml)}}`);
check('import merges into same-name group',
  ri.state.config.groups.length === 2 &&
    ri.state.config.groups[1].name === '工作' &&
    ri.state.config.groups[1].bookmarks.length === 2 &&
    ri.state.config.groups[1].bookmarks[0].url === 'https://e2e.example/?a=1&b=2' &&
    ri.state.config.groups[1].bookmarks[1].url === 'https://nested.example.com',
  ri.state.config.groups);
check('import top-level lands in default group',
  ri.state.config.groups[0].bookmarks.map(b => b.url).join(',') === 'https://top.example/',
  ri.state.config.groups[0]);
check('import saves and toasts',
  ri.effects[0].type === 'save' && ri.effects[1].type === 'toast' &&
    ri.effects[1].message === '导入完成：新增 0 组 3 条书签',
  ri.effects);
// re-import: all three urls dedupe, no save, report skipped
ri = mtabI.dispatch(`{"type":"bookmark_import","html":${JSON.stringify(bmHtml)}}`);
check('re-import dedupes without saving',
  ri.effects.length === 1 && ri.effects[0].type === 'toast' &&
    ri.effects[0].message === '未导入新内容：跳过 3 条重复或无效书签',
  ri.effects);
// invalid file: state kept, notify_error
const beforeBad = JSON.stringify(ri.state.config);
ri = mtabI.dispatchRaw('{"type":"bookmark_import","html":"<html><body>nope</body></html>"}');
check('invalid bookmark file notifies and keeps state',
  ri.effects[0].type === 'notify_error' &&
    JSON.stringify(ri.state.config) === beforeBad,
  ri.effects);

// -- countdown widget (countdown-widget change) --
const mtabC = app.fresh();
let rc = mtabC.init('', '2026-09-10');
check('countdown widget off by default', rc.state.config.widgets.countdown === false);
check('open seeds today', rc.state.today === '2026-09-10');
rc = mtabC.dispatchRaw('{"type":"countdown_add","name":"生日","date":"2026-12-01"}');
check('countdown_add appends and derives days',
  rc.state.config.countdowns.length === 1 &&
    rc.state.countdown_views[0].days === 82,
  rc.state.countdown_views);
check('countdown_add saves', rc.effects[0].type === 'save');
rc = mtabC.dispatchRaw('{"type":"countdown_add","name":"  ","date":"2026-12-01"}');
check('blank countdown name rejected',
  rc.effects[0].type === 'notify_error' && rc.state.config.countdowns.length === 1);
rc = mtabC.dispatchRaw('{"type":"countdown_add","name":"坏","date":"2026-02-30"}');
check('impossible countdown date rejected',
  rc.effects[0].type === 'notify_error' && rc.state.config.countdowns.length === 1);
// today / past semantics + rollover
rc = mtabC.dispatchRaw('{"type":"countdown_add","name":"今天","date":"2026-09-10"}');
rc = mtabC.dispatchRaw('{"type":"countdown_add","name":"过去","date":"2026-09-08"}');
rc = mtabC.dispatchRaw('{"type":"tick_date","date":"2026-09-11"}');
check('tick_date updates views without saving',
  rc.effects.length === 0 &&
    rc.state.countdown_views.map(v => v.days).join(',') === '81,-1,-3',
  rc.state.countdown_views);
// delete
rc = mtabC.dispatchRaw('{"type":"countdown_delete","id":"c1"}');
check('countdown_delete removes the entry',
  rc.state.config.countdowns.length === 2 && rc.effects[0].type === 'save');
rc = mtabC.dispatchRaw('{"type":"countdown_delete","id":"zz"}');
check('missing countdown delete notifies', rc.effects[0].type === 'notify_error');
// widget toggle round-trip
rc = mtabC.dispatchRaw('{"type":"widget_toggle","widget":"countdown"}');
check('countdown widget toggles on',
  rc.state.config.widgets.countdown === true);
// config round-trip carries countdowns; legacy file decodes without them
const withCountdowns = JSON.stringify(rc.state.config);
const mtabC2 = mtabC.fresh();
let rc2 = mtabC2.init(withCountdowns, '2026-09-15');
check('config round-trip keeps countdowns and derives fresh days',
  rc2.state.config.countdowns.length === 2 &&
    rc2.state.countdown_views[0].days === -5,
  rc2.state.countdown_views);
const legacyNoCd = JSON.stringify({
  version: 2, groups: [], search: { engines: [], current: 'baidu', history: [] },
  widgets: { clock: true, bookmarks: true }, wallpaper: { type: 'builtin', id: 'w1' },
});
rc2 = mtabC2.dispatch(`{"type":"config_import","json":${JSON.stringify(legacyNoCd)}}`);
check('legacy config imports with empty countdowns',
  rc2.state.config.countdowns.length === 0 && rc2.effects[0].type === 'save');

// -- unknown event --
r = app.dispatchRaw('{"type":"nope"}');
check('unknown event notifies', r.effects[0].type === 'notify_error', r.effects);
r = app.dispatchRaw('not json');
check('garbage event notifies', r.effects[0].type === 'notify_error', r.effects);

finish();
