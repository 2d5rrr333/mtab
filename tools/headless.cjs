// Headless Chromium runner: serve static files, launch a browser, dump
// DOM, and extract test-harness page results (task 1.5). Library-ized
// from mtab's in-repo headless.cjs; works for any project whose test page
// follows the marker contract:
//   - each check logs a line containing 'PASS ' or 'FAIL '
//   - a summary element with id="test-summary" holds the final line
//   - success summary matches /ALL \d+ BROWSER CHECKS PASSED/
//
// Usage:
//   const { serveStatic, runChromium, extractHarnessSummary, report, detectBrowser } = require('./node/headless.cjs');
//   const site = await serveStatic('web', 8932);
//   const dom = await runChromium({ url: site.url + '/', waitMarker: 'test-summary' });
//   const sum = extractHarnessSummary(dom);
//   await site.close();

const { createServer } = require('node:http');
const { readFile, rmSync } = require('node:fs/promises');
const { existsSync } = require('node:fs');
const path = require('node:path');
const { spawn, execSync } = require('node:child_process');

const TYPES = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.wasm': 'application/wasm',
  '.svg': 'image/svg+xml',
};

/// Serve a directory over HTTP. port 0 picks a free port.
async function serveStatic(root, port = 0) {
  const server = createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://localhost');
      const file = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
      const data = await readFile(path.join(root, file));
      res.writeHead(200, {
        'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream',
      });
      res.end(data);
    } catch {
      res.writeHead(404);
      res.end('not found');
    }
  });
  await new Promise(resolve => server.listen(port, resolve));
  const address = server.address();
  return {
    server,
    url: `http://localhost:${address.port}/`,
    async close() {
      await new Promise(resolve => server.close(resolve));
    },
  };
}

const WINDOWS_CANDIDATES = [
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
];

function fromPath(name) {
  try {
    const where = process.platform === 'win32' ? 'where' : 'which';
    const out = execSync(`${where} ${name}`, { stdio: ['ignore', 'pipe', 'ignore'] })
      .toString()
      .split(/\r?\n/)[0]
      .trim();
    if (out && existsSync(out)) {
      return out;
    }
  } catch {}
  return null;
}

/**
 * Resolve a Chromium-family browser. Priority: the MOONWEBTEST_BROWSER
 * env var, then platform defaults (Windows fixed paths, elsewhere PATH
 * lookup of msedge/chrome/chromium/google-chrome). Throws with the list
 * of candidates tried so misconfiguration is diagnosable.
 */
function detectBrowser() {
  const tried = [];
  const fromEnv = process.env.MOONWEBTEST_BROWSER;
  if (fromEnv) {
    if (existsSync(fromEnv)) {
      return fromEnv;
    }
    tried.push(`MOONWEBTEST_BROWSER=${fromEnv} (not found)`);
  }
  if (process.platform === 'win32') {
    for (const candidate of WINDOWS_CANDIDATES) {
      tried.push(candidate);
      if (existsSync(candidate)) {
        return candidate;
      }
    }
  } else {
    for (const name of ['msedge', 'chrome', 'chromium', 'google-chrome']) {
      tried.push(`PATH:${name}`);
      const found = fromPath(name);
      if (found) {
        return found;
      }
    }
  }
  throw new Error(
    'moonwebtest: no Chromium-family browser found. Tried:\n  ' +
      tried.join('\n  ') +
      '\nSet MOONWEBTEST_BROWSER to your browser executable.',
  );
}

let runCounter = 0;

/**
 * Launch the browser headless and resolve with its stdout.
 *
 * options:
 *   browser      executable path (default: detectBrowser())
 *   args         extra CLI args (e.g. ['--dump-dom', url] or
 *                ['--force-prefers-reduced-motion', '--dump-dom', url])
 *   profileRoot  directory for per-run user-data-dirs (a killed browser
 *                can hold the profile lock; unique dirs avoid flakiness)
 *   waitMarker   resolve early once stdout contains this marker (e.g.
 *                'test-summary'); omit to wait for process exit
 *   timeoutMs    hard cap for a hung renderer (default 60000)
 */
function runChromium({
  browser,
  args = [],
  profileRoot,
  waitMarker,
  timeoutMs = 60000,
} = {}) {
  const exe = browser || detectBrowser();
  if (!profileRoot) {
    throw new Error('moonwebtest: profileRoot is required (use a temp dir)');
  }
  return new Promise(resolve => {
    const profile = path.join(profileRoot, `run-${++runCounter}`);
    console.log('  [browser] launching:', args.join(' '));
    const proc = spawn(exe, [
      '--headless=new',
      '--disable-gpu',
      '--no-first-run',
      '--window-size=1280,800',
      `--user-data-dir=${profile}`,
      '--virtual-time-budget=60000',
      ...args,
    ]);
    let out = '';
    let err = '';
    let done = false;
    const finish = value => {
      if (done) {
        return;
      }
      done = true;
      clearTimeout(timer);
      clearTimeout(quietTimer);
      try { proc.kill(); } catch {}
      resolve(value);
    };
    // After the wait marker appears, allow a quiet period for any
    // remaining stdout chunks to land: --dump-dom output can exceed a
    // single pipe chunk, and finishing on the first chunk that happens
    // to contain the marker truncates the capture.
    let quietTimer = null;
    proc.stdout.on('data', d => {
      out += d;
      if (waitMarker && out.includes(waitMarker)) {
        clearTimeout(quietTimer);
        quietTimer = setTimeout(() => {
          console.log('  [browser] marker captured, ending early');
          finish(out);
        }, 500);
      }
    });
    proc.stderr.on('data', d => (err += d));
    proc.stdout.on('error', () => {});
    proc.stderr.on('error', () => {});
    const timer = setTimeout(() => {
      console.log('  [browser] TIMEOUT, killing. stderr tail:', err.slice(-400));
      finish(out);
    }, timeoutMs);
    proc.on('close', () => finish(out));
    proc.on('error', e => {
      console.log('  [browser] spawn error', e);
      finish('');
    });
  });
}

/**
 * Parse a dumped test-harness page. Returns { passed, failed, failLines,
 * summaryText, ok } — ok is true only when a summary line matching
 * /ALL \d+ BROWSER CHECKS PASSED/ is present.
 */
function extractHarnessSummary(dom) {
  const passed = (dom.match(/>PASS /g) || []).length;
  const failed = (dom.match(/>FAIL /g) || []).length;
  const failLines = dom
    .split('\n')
    .filter(line => /FAIL /.test(line))
    .map(line => line.trim().replace(/<[^>]+>/g, ''));
  const summary = /id="test-summary"[^>]*>([^<]+)</.exec(dom);
  const summaryText = summary ? summary[1] : null;
  return {
    passed,
    failed,
    failLines,
    summaryText,
    ok: summaryText !== null && /ALL \d+ BROWSER CHECKS PASSED/.test(summaryText),
  };
}

/// mtab-style report line; returns 0 on success and 1 on failure.
function report(name, ok) {
  console.log((ok ? '  ok: ' : 'FAIL: ') + name);
  return ok ? 0 : 1;
}

module.exports = {
  serveStatic,
  detectBrowser,
  runChromium,
  extractHarnessSummary,
  report,
};
