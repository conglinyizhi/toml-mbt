//! stdin support for the `wasm` / `wasm-gc` targets.
//!
//! The moonrun sandbox exposes the `__moonbit_io_unstable` host import
//! `read_bytes_from_stdin`, which returns the full stdin content as an
//! extern byte array. We copy it into a MoonBit `Bytes` via the
//! `__moonbit_fs_unstable` byte-array reader.

///|
#external
type XExternByteArray

///|
#external
type XByteArrayReadHandle

///|
fn read_bytes_from_stdin_ffi() -> XExternByteArray = "__moonbit_io_unstable" "read_bytes_from_stdin"

///|
fn begin_read_byte_array(s : XExternByteArray) -> XByteArrayReadHandle = "__moonbit_fs_unstable" "begin_read_byte_array"

///|
fn byte_array_read_byte(handle : XByteArrayReadHandle) -> Int = "__moonbit_fs_unstable" "byte_array_read_byte"

///|
fn finish_read_byte_array(handle : XByteArrayReadHandle) = "__moonbit_fs_unstable" "finish_read_byte_array"

///|
fn byte_array_from_extern(e : XExternByteArray) -> Bytes {
  let buf = Array::new()
  let handle = begin_read_byte_array(e)
  while true {
    let ch = byte_array_read_byte(handle)
    if ch == -1 {
      break
    } else {
      buf.push(ch.to_byte())
    }
  }
  finish_read_byte_array(handle)
  Bytes::from_array(buf)
}

///|
/// Read all of stdin as a UTF-8 string.
pub fn read_stdin() -> String {
  let bytes = byte_array_from_extern(read_bytes_from_stdin_ffi())
  @utf8.decode_lossy(bytes.view())
}
