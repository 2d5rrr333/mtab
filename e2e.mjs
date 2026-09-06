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
check('init default config', r.state.config.version === 1);
check('init clock lunar', r.state.clock.lunar === '乙巳年正月初一', r.state.clock);
check('init clock weekday', r.state.clock.weekday === '星期三', r.state.clock);

// -- bookmark add --
r = JSON.parse(mtab.mtab_dispatch('{"type":"bookmark_add","name":"示例","url":"example.com"}'));
check('add normalizes url', r.state.config.bookmarks[0].url === 'https://example.com', r.state.config.bookmarks);
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
check('export has version', JSON.parse(exported).version === 1);

// -- config import round-trip into a fresh instance --
const mod2 = new WebAssembly.Module(bytes, { builtins: ['js-string'] });
const mtab2 = new WebAssembly.Instance(mod2, { _: imports._ }).exports;
const r2 = JSON.parse(mtab2.mtab_init(exported, '2025-07-25'));
check('import restores bookmarks', r2.state.config.bookmarks.length === 1, r2.state.config.bookmarks);
check('import restores wallpaper', r2.state.config.wallpaper.data === 'data:image/jpeg;base64,QUJD');
check('init leap month', r2.state.clock.lunar === '乙巳年闰六月初一', r2.state.clock);

// -- invalid import keeps current state --
r = JSON.parse(mtab.mtab_dispatch('{"type":"config_import","json":"{{broken"}'));
check('bad import notifies', r.effects[0].type === 'notify_error', r.effects);

// -- unknown event --
r = JSON.parse(mtab.mtab_dispatch('{"type":"nope"}'));
check('unknown event notifies', r.effects[0].type === 'notify_error', r.effects);
r = JSON.parse(mtab.mtab_dispatch('not json'));
check('garbage event notifies', r.effects[0].type === 'notify_error', r.effects);

console.log(failures === 0 ? 'ALL E2E CHECKS PASSED' : failures + ' FAILURES');
process.exit(failures === 0 ? 0 : 1);
