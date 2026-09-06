// Trie: character-level prefix index over arbitrary "entries" identified by
// a String id (search-history design D4). Case normalization is the caller's
// concern; this structure is an exact-match prefix index.

///|
/// A trie node: children keyed by character plus the entry ids whose key
/// terminates here. Node 0 of `nodes` is the root.
struct Node {
  children : Map[Char, Int]
  ids : Array[String]
} derive(Debug)

///|
/// The trie. `size` is the number of stored (id, key) pairs, counting
/// duplicates separately so remove is symmetric with insert.
pub struct Trie {
  nodes : Array[Node]
  mut size : Int
} derive(Debug)

///|
/// An empty trie.
pub fn Trie::new() -> Trie {
  { nodes: [{ children: {}, ids: [], }], size: 0, }
}

///|
/// Insert `id` under `key`. The same id may sit under several keys; the
/// same (id, key) pair may be inserted twice and is then removed twice.
pub fn Trie::insert(self : Trie, key : String, id : String) -> Unit {
  let mut node = 0
  for _, ch in key {
    let node_obj = self.nodes[node]
    let next = match node_obj.children.get(ch) {
      Some(i) => i
      None => {
        let i = self.nodes.length()
        self.nodes.push({ children: {}, ids: [], })
        self.nodes[node].children[ch] = i
        i
      }
    }
    node = next
  }
  self.nodes[node].ids.push(id)
  self.size = self.size + 1
}

///|
/// Remove one occurrence of `id` under `key`; true when something was
/// removed. Empty husk nodes are left in place (bounded by total insertions).
pub fn Trie::remove(self : Trie, key : String, id : String) -> Bool {
  // Collect the path so ids can be pruned bottom-up when empty.
  let path : Array[(Int, Char)] = []
  let mut node = 0
  for _, ch in key {
    let next = match self.nodes[node].children.get(ch) {
      Some(i) => i
      None => return false
    }
    path.push((node, ch))
    node = next
  }
  let ids = self.nodes[node].ids
  let mut idx = -1
  for i, v in ids {
    if v == id {
      idx = i
      break
    }
  }
  if idx < 0 {
    return false
  }
  ignore(ids.remove(idx))
  self.size = self.size - 1
  // Prune nodes that hold no ids and no children, bottom-up.
  for pair in path.rev() {
    let (parent, ch) = pair
    let child = self.nodes[parent].children[ch]
    if self.nodes[child].ids.length() == 0 &&
      self.nodes[child].children.length() == 0 {
      self.nodes[parent].children.remove(ch)
    } else {
      break
    }
  }
  true
}

///|
/// All entry ids whose keys start with `prefix` (exact characters). An
/// empty prefix matches everything. Order is unspecified; callers sort.
pub fn Trie::prefix_query(self : Trie, prefix : String) -> Array[String] {
  let mut node = 0
  for _, ch in prefix {
    node = match self.nodes[node].children.get(ch) {
      Some(i) => i
      None => return []
    }
  }
  let out : Array[String] = []
  fn walk(t : Trie, n : Int, acc : Array[String]) -> Unit {
    for id in t.nodes[n].ids {
      acc.push(id)
    }
    for _, child in t.nodes[n].children {
      walk(t, child, acc)
    }
  }
  walk(self, node, out)
  out
}
