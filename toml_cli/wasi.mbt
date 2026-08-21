//! Minimal WASIp1 (preview1) I/O layer for the `wasm` / `wasm-gc` targets.
//!
//! Self-contained on purpose: a wasm-only registry dependency (like miniio)
//! would break the `native` build of this same executable package, so we keep
//! just the WASI calls toml-cli needs (stdin, args, read-only file access,
//! exit) plus the tiny memory helpers they rely on.
//!
//! Memory helpers and WASI calling conventions adapted from
//! `moonbit-community/miniio` (Apache-2.0), trimmed to the read-only subset.
//! The resulting wasm imports only `wasi_snapshot_preview1`, so it runs on any
//! WASIp1 host (moonrun, wasmtime, wasmer, ...).

// --- memory helpers (inline wasm) ---

///|
pub extern "wasm" fn store32(offset : Int, value : Int) =
  #|(func (param i32) (param i32) local.get 0 local.get 1 i32.store)

///|
pub extern "wasm" fn load32(offset : Int) -> Int =
  #|(func (param i32) (result i32) local.get 0 i32.load)

///|
#owned(bytes)
pub extern "wasm" fn bytes2ptr(bytes : Bytes) -> Int =
  #|(func (param i32) (result i32) local.get 0)

///|
pub fn malloc(size : Int) -> Int {
  bytes2ptr(Bytes::make(size, b'\x00'))
}

///|
pub extern "wasm" fn free(position : Int) =
  #|(func (param i32) local.get 0 call $moonbit.decref)

// --- WASI preview1 imports ---

///|
fn fd_read_ffi(fd : Int, iovs : Int, iovs_len : Int, nread : Int) -> UInt = "wasi_snapshot_preview1" "fd_read"

///|
fn fd_close_ffi(fd : Int) -> UInt = "wasi_snapshot_preview1" "fd_close"

///|
fn fd_prestat_get_ffi(fd : Int, buf : Int) -> UInt = "wasi_snapshot_preview1" "fd_prestat_get"

///|
fn path_open_ffi(
  dirfd : Int,
  dirflags : UInt,
  path : Int,
  path_len : Int,
  oflags : UInt,
  fs_rights_base : UInt64,
  fs_rights_inheriting : UInt64,
  fs_flags : UInt,
  fd : Int,
) -> UInt = "wasi_snapshot_preview1" "path_open"

///|
fn args_sizes_get_ffi(argc : Int, size : Int) -> UInt = "wasi_snapshot_preview1" "args_sizes_get"

///|
fn args_get_ffi(argv : Int, argv_buf : Int) -> UInt = "wasi_snapshot_preview1" "args_get"

///|
fn exit_internal(code : Int) -> Unit = "wasi_snapshot_preview1" "proc_exit"

// --- stdin ---

///|
fn fd_read_once(fd : Int, buf : Bytes) -> Int {
  let iovs = malloc(8)
  defer free(iovs)
  store32(iovs, bytes2ptr(buf))
  store32(iovs + 4, buf.length())
  let nread = malloc(4)
  defer free(nread)
  if fd_read_ffi(fd, iovs, 1, nread) != 0 {
    return -1
  }
  load32(nread)
}

///|
fn read_fd_loop(fd : Int) -> Bytes {
  let chunks = []
  while true {
    let buf = Bytes::make(4096, b'\x00')
    let n = fd_read_once(fd, buf)
    if n <= 0 {
      break
    }
    chunks.push(buf[:n].to_owned())
    if n < 4096 {
      break
    }
  }
  let all : Array[Byte] = []
  for chunk in chunks {
    for byte in chunk {
      all.push(byte)
    }
  }
  Bytes::from_array(all)
}

// --- args ---

///|
fn args_internal() -> Array[String] {
  let argc_ptr = malloc(4)
  defer free(argc_ptr)
  let size_ptr = malloc(4)
  defer free(size_ptr)
  if args_sizes_get_ffi(argc_ptr, size_ptr) != 0 {
    return []
  }
  let argc = load32(argc_ptr)
  let size = load32(size_ptr)
  if argc == 0 {
    return []
  }
  let argv_ptr = malloc(argc * 4)
  defer free(argv_ptr)
  let argv_buf = Bytes::make(size, b'\x00')
  let argv_buf_ptr = bytes2ptr(argv_buf)
  if args_get_ffi(argv_ptr, argv_buf_ptr) != 0 {
    return []
  }
  let result = []
  for i in 0..<argc {
    let start = load32(argv_ptr + i * 4) - argv_buf_ptr
    let end = if i == argc - 1 {
      size
    } else {
      load32(argv_ptr + (i + 1) * 4) - argv_buf_ptr
    }
    let len = end - start - 1
    result.push(@utf8.decode_lossy(argv_buf[start:start + len].view()))
  }
  result
}

// --- read-only file access ---

///|
fn find_preopen_dir() -> Int? {
  for fd in 3..<32 {
    let buf = malloc(8)
    defer free(buf)
    if fd_prestat_get_ffi(fd, buf) == 0 && load32(buf) == 0 {
      return Some(fd)
    }
  }
  None
}

///|
/// Read a file as UTF-8 text relative to the first preopened directory;
/// `None` on failure (e.g. no preopen, missing file, or WASI sandbox denies it).
fn read_text_file_internal(path : String) -> String? {
  let dirfd = match find_preopen_dir() {
    Some(fd) => fd
    None => return None
  }
  let rel = match path.strip_prefix("/") {
    Some(rest) => rest.to_owned()
    None => path
  }
  let path_bytes = @utf8.encode(rel)
  let path_ptr = bytes2ptr(path_bytes)
  let fd_ptr = malloc(4)
  defer free(fd_ptr)
  let err = path_open_ffi(
    dirfd,
    0,
    path_ptr,
    path_bytes.length(),
    0,
    0x26, // FD_READ | FD_SEEK | FD_TELL
    0,
    0,
    fd_ptr,
  )
  if err != 0 {
    return None
  }
  let fd = load32(fd_ptr)
  defer ignore(fd_close_ffi(fd))
  Some(@utf8.decode_lossy(read_fd_loop(fd).view()))
}
