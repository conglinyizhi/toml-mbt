//! Platform I/O for the `wasm` / `wasm-gc` targets.
//!
//! Backed by the self-contained WASIp1 layer in `wasi.mbt`, so the generated
//! wasm imports only `wasi_snapshot_preview1` and runs on any WASIp1 host
//! (moonrun, wasmtime, wasmer, ...).

///|
/// Read all of stdin as a UTF-8 string.
pub fn read_stdin() -> String {
  @utf8.decode_lossy(read_fd_loop(0).view())
}

///|
/// Read a file as UTF-8 text; `None` (with an error printed) on failure.
pub fn read_source_file(path : String) -> String? {
  match read_text_file_internal(path) {
    Some(text) => Some(text)
    None => {
      println("error: failed to read \{path} (WASI sandbox)")
      None
    }
  }
}

///|
/// Command-line arguments.
pub fn get_args() -> Array[String] {
  // Some WASI hosts (wasmtime) pass the `--` separator through to argv;
  // drop it so argparse does not treat the rest as positionals.
  args_internal().filter(fn(a) { a != "--" })
}

///|
/// Exit the program with the given code.
pub fn exit(code : Int) -> Unit {
  exit_internal(code)
}
