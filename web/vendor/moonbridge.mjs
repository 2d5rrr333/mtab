// moonbridge browser/Node runtime: boot a wasm-gc core over the JSON
// bridge protocol. The MoonBit side owns all decisions; this file only
// loads the module, forwards events, and executes reported effects.
//
// Zero dependencies, single ES module. Browser: import from a <script
// type="module"> or bundler. Node (>= 18): import from an .mjs runner.

/// Instantiate a wasm-gc module compiled by moon (js-string builtins):
/// string literals arrive as imported globals under module "_" whose name
/// is the literal content; materialize them by hand.
function materializeImports(mod) {
  const imports = { _: {} };
  for (const imp of WebAssembly.Module.imports(mod)) {
    if (imp.module === '_' && imp.kind === 'global') {
      imports._[imp.name] = imp.name;
    }
  }
  return imports;
}

async function loadExports({ wasmUrl, wasmBytes }) {
  let bytes = wasmBytes;
  if (!bytes) {
    const response = await fetch(wasmUrl);
    if (!response.ok) {
      throw new Error(`moonbridge: failed to fetch ${wasmUrl}: ${response.status}`);
    }
    bytes = await response.arrayBuffer();
  }
  const mod = new WebAssembly.Module(bytes, { builtins: ['js-string'] });
  const imports = materializeImports(mod);
  return new WebAssembly.Instance(mod, imports).exports;
}

/**
 * Boot a bridge session.
 *
 * options:
 *   wasmUrl            fetch URL of the wasm module (browser or Node>=18)
 *   wasmBytes          alternative: preloaded ArrayBuffer / Uint8Array
 *   init               name of the init export (default "init")
 *   dispatch           name of the dispatch export (default "dispatch")
 *   initArgs           () => array of arguments for the init export
 *   onState            (state) => void, called after every apply
 *   effects            { [type]: (effect, ctx) => void } handler registry
 *   onUnknownEffect    (effect) => void; default: console.warn
 *
 * The ctx passed to effect handlers carries { state, dispatch } where
 * state is the envelope's state for the current apply (already updated).
 *
 * Returns { wasm, state (getter), dispatch(eventObject), dispatchRaw(jsonText) }.
 * Both dispatch forms apply the returned envelope and also return it
 * (parsed), which is handy for tests.
 */
export async function bootBridge({
  wasmUrl,
  wasmBytes,
  init = 'init',
  dispatch = 'dispatch',
  initArgs = () => [],
  onState = () => {},
  effects = {},
  onUnknownEffect,
} = {}) {
  if (!wasmUrl && !wasmBytes) {
    throw new Error('moonbridge: wasmUrl or wasmBytes is required');
  }
  const wasm = await loadExports({ wasmUrl, wasmBytes });
  const initFn = wasm[init];
  const dispatchFn = wasm[dispatch];
  if (typeof initFn !== 'function' || typeof dispatchFn !== 'function') {
    throw new Error(
      `moonbridge: exports ${init}/${dispatch} not found on the module`,
    );
  }

  let state = null;

  function warnUnknown(effect) {
    // A newer core may report effect types this shell does not know yet;
    // warn instead of throwing so old shells keep working.
    console.warn('moonbridge: unhandled effect', effect);
  }

  function applyCore(envelopeText) {
    const envelope = JSON.parse(envelopeText);
    state = envelope.state === undefined ? null : envelope.state;
    const ctx = { state, dispatch: event => dispatchEvent(event) };
    const handlers = effects || {};
    for (const effect of envelope.effects || []) {
      const handler = handlers[effect.type];
      if (handler) {
        handler(effect, ctx);
      } else if (onUnknownEffect) {
        onUnknownEffect(effect);
      } else {
        warnUnknown(effect);
      }
    }
    onState(state);
    return envelope;
  }

  function dispatchRawText(jsonText) {
    return applyCore(dispatchFn(jsonText));
  }

  function dispatchEvent(eventObject) {
    return dispatchRawText(JSON.stringify(eventObject));
  }

  // Boot: the init envelope runs through the same apply path.
  applyCore(initFn(...initArgs()));

  return {
    wasm,
    get state() { return state; },
    dispatch: dispatchEvent,
    dispatchRaw: dispatchRawText,
  };
}
