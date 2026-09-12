// Headless browser harness: serves web/ and checks rendering via a
// headless Chromium-family browser --dump-dom. Two phases:
//   1. index.html render checks
//   2. test-harness.html interaction checks (results dumped into the DOM)
// Browser plumbing comes from the moonwebtest headless runner
// (github.com/2d5rrr333/moonwebtest, vendored under tools/).
// Usage: node headless.cjs
const path = require('node:path');
const { rmSync } = require('node:fs');
const { get: httpGet } = require('node:http');
const {
  serveStatic,
  runChromium,
  report,
} = require('./tools/headless.cjs');

const ROOT = path.join(__dirname, 'web');
const PROFILE_ROOT = path.join(__dirname, '.edge-profile');
const PORT = 8932;

// Best-effort cleanup of all run profiles at startup. Each runChromium call
// uses its own unique profile dir instead: a killed browser can keep the
// directory lock for a while, which would make a per-run rmSync fail
// silently and leak localStorage between back-to-back runs.
try {
  rmSync(PROFILE_ROOT, { recursive: true, force: true });
} catch {}

async function runEdge(args) {
  return runChromium({
    args,
    profileRoot: PROFILE_ROOT,
    waitMarker: args.includes('--dump-dom') ? 'test-summary' : undefined,
    timeoutMs: 60000,
  });
}

(async () => {
  const site = await serveStatic(ROOT, PORT);
  const base = site.url;
  let failed = 0;

  // favicon reachable with svg content type (ui-a11y-polish D4).
  const fav = await new Promise((resolve, reject) => {
    httpGet(base + 'favicon.svg', res => {
      res.resume();
      resolve(res);
    }).on('error', reject);
  });
  failed += report('favicon served', fav.statusCode === 200 &&
    (fav.headers['content-type'] || '').includes('svg'));

  // Phase 1: index.html render.
  const dom = await runEdge(['--dump-dom', base]);
  failed += report('favicon linked in head', /<link rel="icon"[^>]*href="favicon\.svg"/.test(dom));
  failed += report('theme-color meta present', /<meta name="theme-color" content="#1c1e26"/.test(dom));
  failed += report('clock rendered with time', /id="clock-time"[^>]*>\d{2}:\d{2}/.test(dom));
  failed += report('date line has 星期', /星期[一二三四五六日]/.test(dom));
  failed += report('lunar text rendered', /[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥]年(闰)?[正二三四五六七八九十冬腊]月/.test(dom));
  failed += report('engine bar has 3 engines', (dom.match(/class="engine-bar"[\s\S]*?<\/div>/) || [''])[0].split('<button').length - 1 >= 3);
  failed += report('baidu active', /active[^>]*>百度|>百度<\/button>/.test(dom));
  failed += report('search input present', /id="search-input"/.test(dom));
  failed += report('bookmark empty state shown', /还没有书签/.test(dom));
  failed += report('settings button', /id="settings-open"/.test(dom));
  failed += report('wallpaper list 4 items', (dom.match(/data-wp=/g) || []).length === 4);
  failed += report('no startup error', !/mtab failed to start/.test(dom));

  // Phase 2: test-harness.html interactions.
  async function runHarness(label, extraArgs) {
    const harnessDom = await runEdge([...extraArgs, '--dump-dom', base + 'test-harness.html']);
    const passCount = (harnessDom.match(/>PASS /g) || []).length;
    const failCount = (harnessDom.match(/>FAIL /g) || []).length;
    for (const line of harnessDom.split('\n')) {
      if (/FAIL /.test(line)) {
        console.log('  ' + line.trim().replace(/<[^>]+>/g, ''));
      }
    }
    const summary = /id="test-summary"[^>]*>([^<]+)</.exec(harnessDom);
    console.log(`  ${label}: ${passCount} passed, ${failCount} failed :: ${summary ? summary[1] : 'NO SUMMARY (crashed?)'}`);
    if (!summary) {
      return 1;
    }
    return /ALL \d+ BROWSER CHECKS PASSED/.test(summary[1]) ? 0 : 1;
  }

  failed += await runHarness('harness', []);
  // Same harness with forced reduced motion: the kill-switch segment
  // self-activates via matchMedia (ui-a11y-polish D5).
  failed += await runHarness('harness (reduced motion)', ['--force-prefers-reduced-motion']);

  await runEdge(['--screenshot=' + path.join(__dirname, 'headless.png'), '--window-size=1280,800', base]);
  console.log('screenshot: headless.png');

  await site.close();
  console.log(failed === 0 ? 'HEADLESS CHECKS PASSED' : failed + ' FAILURES');
  process.exit(failed === 0 ? 0 : 1);
})();
