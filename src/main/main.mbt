// wasm exports: mtab_init / mtab_dispatch (bridge contract, design D2).
// Protocol mechanics (envelope assembly, error paths) live in moonbridge;
// this file only wires mtab's store into a Session.

///|
/// Adapter: the store's update returns a Response struct; the Session
/// takes the (state, effects) tuple.
fn update_adapter(
  state : @store.Store,
  ev : @store.Event,
) -> (@store.Store, Array[@store.Effect]) {
  let resp = @store.update(state, ev)
  (resp.state, resp.effects)
}

///|
/// The single bridge session held across dispatches.
let session : @bridge.Session[@store.Store, @store.Event, @store.Effect] = @bridge.Session::make(
  update_adapter,
  texts={ not_initialized: "未初始化", invalid_event: "无效的事件", },
)

///|
#export_name("mtab_init")
pub fn mtab_init(stored_config : String, today : String) -> String {
  let stored = if stored_config == "" { None } else { Some(stored_config) }
  let resp = @store.open(stored, today)
  session.init(resp.state, resp.effects)
}

///|
#export_name("mtab_dispatch")
pub fn mtab_dispatch(event : String) -> String {
  session.dispatch(event)
}
