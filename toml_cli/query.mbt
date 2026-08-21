//! Path queries over a parsed TOML document, in the spirit of `jq`.
//!
//! Supported path syntax (all optional leading `.`):
//!
//! - `.` or empty string: the whole document
//! - `.server.host`: nested table keys
//! - `.ports[0]`: array index
//! - `.matrix[1].name`: mixed nesting
//!
//! A lookup that hits a missing key or an out-of-range index yields `None`.

///|
enum PathSeg {
  Key(String)
  Index(Int)
}

///|
fn parse_path(path : String) -> Array[PathSeg] {
  let segs = Array::new()
  let mut s = match path.strip_prefix(".") {
    Some(rest) => rest.to_owned()
    None => path
  }
  while s.length() > 0 {
    if s.has_prefix("[") {
      let end = s.find("]")
      match end {
        Some(e) => {
          let idx = @string.parse_int(s[1:e].to_owned()) catch {
            _ => abort("invalid array index in path `\{path}`")
          }
          segs.push(Index(idx))
          s = s[e + 1:].to_owned()
        }
        None => abort("unbalanced `[` in path `\{path}`")
      }
    } else {
      let dot = s.find(".")
      let bracket = s.find("[")
      let end = match (dot, bracket) {
        (Some(d), Some(b)) => if d < b { d } else { b }
        (Some(d), None) => d
        (None, Some(b)) => b
        (None, None) => s.length()
      }
      segs.push(Key(s[:end].to_owned()))
      s = s[end:].to_owned()
    }
    // Skip the separator between segments (`.` after a key or `]`).
    s = match s.strip_prefix(".") {
      Some(rest) => rest.to_owned()
      None => s
    }
  }
  segs
}

///|
/// Look up `path` inside `root`; `None` when any segment is missing.
pub fn get_path(
  root : @toml_lib.TomlValue,
  path : String,
) -> @toml_lib.TomlValue? {
  if path.is_empty() || path == "." {
    return Some(root)
  }
  let segs = parse_path(path)
  let mut cur : @toml_lib.TomlValue = root
  for seg in segs {
    match (cur, seg) {
      (TomlTable(table), Key(key)) =>
        match table.get(key) {
          Some(value) => cur = value
          None => return None
        }
      (TomlArray(array), Index(i)) =>
        if i >= 0 && i < array.length() {
          cur = array[i]
        } else {
          return None
        }
      _ => return None
    }
  }
  Some(cur)
}

///|
/// Render a value for `get` output: strings are printed raw (no quotes),
/// everything else uses the TOML serializer.
pub fn render(value : @toml_lib.TomlValue) -> String {
  match value {
    TomlString(s) => s
    _ => value.to_string()
  }
}
