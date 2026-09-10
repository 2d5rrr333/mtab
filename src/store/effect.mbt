// Bridge effects (design D1/D2): side-effect intents the JS shell executes.
// On the wire they are JSON objects with a snake_case "type" tag.

///|
pub(all) enum Effect {
  Save
  OpenUrl(url~ : String)
  NotifyError(message~ : String)
  Toast(message~ : String)
} derive(Eq, Debug)

///|
pub impl ToJson for Effect with fn to_json(self) {
  match self {
    Save => { "type": "save" }
    OpenUrl(url~) => { "type": "open_url", "url": url }
    NotifyError(message~) => { "type": "notify_error", "message": message }
    Toast(message~) => { "type": "toast", "message": message }
  }
}
