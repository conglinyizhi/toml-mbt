//! stdin support for the `native` / `llvm` targets.
//!
//! `moonbitlang/x/fs` cannot read stdin (it seeks to measure file size,
//! which fails on pipes), so we route through a small C stub compiled via
//! the `native-stub` mechanism in `moon.pkg`.

///|
extern "C" fn read_stdin_ffi() -> Bytes = "moonbit_toml_cli_read_stdin"

///|
/// Read all of stdin as a UTF-8 string.
pub fn read_stdin() -> String {
  let bytes = read_stdin_ffi()
  @utf8.decode_lossy(bytes.view())
}
