//! Platform I/O for the `native` / `llvm` targets.
//!
//! Everything goes through a small C stub (`stdin_native.c`) so that the
//! package does not import `moonbitlang/x/fs`, `moonbitlang/x/sys`, or
//! `moonbitlang/core/env` — those packages' wasm implementations import
//! moonrun-specific host functions (`__moonbit_fs_unstable` etc.) and would
//! leak into the wasm build, breaking pure-WASI portability.

///|
extern "C" fn read_stdin_ffi() -> Bytes = "moonbit_toml_cli_read_stdin"

///|
#borrow(path)
extern "C" fn read_file_ffi(path : Bytes, path_len : Int) -> Int = "moonbit_toml_cli_read_file"

///|
extern "C" fn get_file_content_ffi() -> Bytes = "moonbit_toml_cli_get_read_file_content"

///|
extern "C" fn get_error_message_ffi() -> Bytes = "moonbit_toml_cli_get_error_message"

///|
extern "C" fn get_args_ffi() -> Bytes = "moonbit_toml_cli_get_args"

///|
extern "C" fn exit_ffi(code : Int) = "moonbit_toml_cli_exit"

///|
/// Read all of stdin as a UTF-8 string.
pub fn read_stdin() -> String {
  @utf8.decode_lossy(read_stdin_ffi().view())
}

///|
/// Read a file as UTF-8 text; `None` (with an error printed) on failure.
pub fn read_source_file(path : String) -> String? {
  let path_bytes = @utf8.encode(path)
  let res = read_file_ffi(path_bytes, path_bytes.length())
  if res == -1 {
    let msg = @utf8.decode_lossy(get_error_message_ffi().view())
    println("error: failed to read \{path}: \{msg}")
    None
  } else {
    Some(@utf8.decode_lossy(get_file_content_ffi().view()))
  }
}

///|
/// Command-line arguments.
pub fn get_args() -> Array[String] {
  let raw = @utf8.decode_lossy(get_args_ffi().view())
  if raw.is_empty() {
    []
  } else {
    raw.split("\n").to_array().map(fn(part) { part.to_owned() })
  }
}

///|
/// Exit the program with the given code.
pub fn exit(code : Int) -> Unit {
  exit_ffi(code)
}
