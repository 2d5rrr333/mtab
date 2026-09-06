// wasm exports: mtab_init / mtab_dispatch (bridge contract, design D2).

///|
/// The single mutable store instance held across dispatches.
let state : Ref[@store.Store?] = Ref(None)

///|
#export_name("mtab_init")
pub fn mtab_init(stored_config : String, today : String) -> String {
  let stored = if stored_config == "" { None } else { Some(stored_config) }
  let resp = @store.open(stored, today)
  state.val = Some(resp.state)
  ToJson::to_json(resp).stringify()
}

///|
#export_name("mtab_dispatch")
pub fn mtab_dispatch(event : String) -> String {
  match state.val {
    None => {
      let empty : @store.Store? = None
      let json : Json = {
        "state": empty,
        "effects": [{ "type": "notify_error", "message": "未初始化" }],
      }
      json.stringify()
    }
    Some(store) =>
      try {
        let ev : @store.Event = @json.from_json(@json.parse(event))
        let resp = @store.update(store, ev)
        state.val = Some(resp.state)
        ToJson::to_json(resp).stringify()
      } catch {
        _ => {
          let json : Json = {
            "state": store,
            "effects": [
              { "type": "notify_error", "message": "无效的事件" },
            ],
          }
          json.stringify()
        }
      }
  }
}
