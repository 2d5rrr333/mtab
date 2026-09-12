// Node harness: drive a wasm-gc module's bridge exports from Node (task
// 1.4). Works for any moonbridge-style app (or hand-rolled bridge) with
// init/dispatch exports speaking the {state, effects} envelope.
//
// Usage:
//   import { loadBridge, makeChecks } from './node/bridge-harness.mjs';
//   const app = await loadBridge('path/to/main.wasm', {
//     init: 'mtab_init', dispatch: 'mtab_dispatch',
//   });
//   let r = app.init(...initArgs);          // parsed envelope {state, effects}
//   r = app.dispatch({ type: '...' });      // object or string in
//   const app2 = app.fresh();                // isolated instance, same bytes
//   const { check, finish } = makeChecks();
//   check('name', cond, detail);
//   process.exit(finish());                 // summary line + exit code

import { readFileSync } from 'node:fs';

/// Compile once; each instance gets its own state.
function materializeImports(mod) {
  const imports = { _: {} };
  for (const imp of WebAssembly.Module.imports(mod)) {
    if (imp.module === '_' && imp.kind === 'global') {
      imports._[imp.name] = imp.name;
    }
  }
  return imports;
}

function makeApp(mod, init, dispatch) {
  const instance = new WebAssembly.Instance(mod, materializeImports(mod)).exports;
  const initFn = instance[init];
  const dispatchFn = instance[dispatch];
  if (typeof initFn !== 'function' || typeof dispatchFn !== 'function') {
    throw new Error(`bridge-harness: exports ${init}/${dispatch} not found`);
  }
  let state = null;
  return {
    exports: instance,
    init(...args) {
      const envelope = JSON.parse(initFn(...args));
      state = envelope.state === undefined ? null : envelope.state;
      return envelope;
    },
    dispatch(event) {
      const envelope = JSON.parse(
        dispatchFn(typeof event === 'string' ? event : JSON.stringify(event)),
      );
      state = envelope.state === undefined ? null : envelope.state;
      return envelope;
    },
    dispatchRaw(jsonText) {
      return this.dispatch(jsonText);
    },
    get state() {
      return state;
    },
  };
}

/**
 * Load a wasm bridge app. Returns an app object with init/dispatch (both
 * return the parsed envelope) and fresh() for isolated instances.
 */
export function loadBridge(wasmPath, { init = 'init', dispatch = 'dispatch' } = {}) {
  const bytes = readFileSync(wasmPath);
  const mod = new WebAssembly.Module(bytes, { builtins: ['js-string'] });
  const app = makeApp(mod, init, dispatch);
  app.fresh = () => loadBridge(wasmPath, { init, dispatch });
  return app;
}

/**
 * mtab-style check accounting: check(name, cond, detail) logs ok/FAIL
 * lines; finish() prints the summary and returns the failure count (0
 * means pass) after setting the process exit code.
 */
export function makeChecks() {
  let failures = 0;
  function check(name, cond, detail) {
    if (cond) {
      console.log('  ok:', name);
    } else {
      failures += 1;
      console.log(
        'FAIL:',
        name,
        detail === undefined ? '' : JSON.stringify(detail),
      );
    }
  }
  function finish(label = 'ALL E2E CHECKS PASSED') {
    if (failures === 0) {
      console.log(label);
    } else {
      console.log(failures + ' FAILURES');
    }
    process.exitCode = failures === 0 ? 0 : 1;
    return failures;
  }
  return { check, finish };
}
