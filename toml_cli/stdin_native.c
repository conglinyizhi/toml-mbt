// Native platform layer for toml-cli: stdin, read-only file access, args,
// and exit. Kept dependency-free on purpose (no x/fs, x/sys, core/env) so the
// wasm build stays pure WASI.

#ifdef __cplusplus
extern "C" {
#endif

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

// --- stdin ---

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_toml_cli_read_stdin(void) {
  size_t cap = 4096;
  size_t len = 0;
  char *buf = (char *)malloc(cap);
  if (!buf) {
    return moonbit_make_bytes(0, 0);
  }
  int c;
  while ((c = fgetc(stdin)) != EOF) {
    if (len + 1 >= cap) {
      cap *= 2;
      char *nb = (char *)realloc(buf, cap);
      if (!nb) {
        free(buf);
        return moonbit_make_bytes(0, 0);
      }
      buf = nb;
    }
    buf[len++] = (char)c;
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  memcpy(out, buf, len);
  free(buf);
  return out;
}

// --- read-only file access ---
// x/fs's native reader cannot read stdin (it seeks), and we want to avoid
// depending on x/fs at all for the wasm build, so a plain C reader lives here.

static moonbit_bytes_t g_read_file_content = NULL;

MOONBIT_FFI_EXPORT int moonbit_toml_cli_read_file(moonbit_bytes_t path,
                                                  int32_t path_len) {
  // moonbit bytes are not NUL-terminated; make a C string copy.
  char *path_c = (char *)malloc((size_t)path_len + 1);
  if (!path_c) {
    return -1;
  }
  memcpy(path_c, path, (size_t)path_len);
  path_c[path_len] = '\0';
  FILE *f = fopen(path_c, "rb");
  free(path_c);
  if (!f) {
    return -1;
  }
  if (fseek(f, 0, SEEK_END) != 0) {
    fclose(f);
    return -1;
  }
  long sz = ftell(f);
  if (sz < 0) {
    fclose(f);
    return -1;
  }
  rewind(f);
  g_read_file_content = moonbit_make_bytes((int32_t)sz, 0);
  size_t got = fread(g_read_file_content, 1, (size_t)sz, f);
  fclose(f);
  if (got != (size_t)sz) {
    return -1;
  }
  return 0;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_toml_cli_get_read_file_content(void) {
  return g_read_file_content ? g_read_file_content : moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_toml_cli_get_error_message(void) {
  const char *err_str = strerror(errno);
  size_t len = strlen(err_str);
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)len, 0);
  memcpy(bytes, err_str, len);
  return bytes;
}

// --- command-line arguments ---
// Join argv with '\n' into a single bytes blob; the MoonBit side splits it.
// Linux reads /proc/self/cmdline; other platforms fall back to empty.

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_toml_cli_get_args(void) {
#if defined(__linux__)
  FILE *f = fopen("/proc/self/cmdline", "rb");
  if (!f) {
    return moonbit_make_bytes(0, 0);
  }
  size_t cap = 4096;
  size_t len = 0;
  char *buf = (char *)malloc(cap);
  if (!buf) {
    fclose(f);
    return moonbit_make_bytes(0, 0);
  }
  int c;
  while ((c = fgetc(f)) != EOF) {
    if (c == '\0') {
      c = '\n';
    }
    if (len + 1 >= cap) {
      cap *= 2;
      char *nb = (char *)realloc(buf, cap);
      if (!nb) {
        free(buf);
        fclose(f);
        return moonbit_make_bytes(0, 0);
      }
      buf = nb;
    }
    buf[len++] = (char)c;
  }
  fclose(f);
  // Drop the trailing newline (cmdline ends with '\0').
  if (len > 0 && buf[len - 1] == '\n') {
    len--;
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  memcpy(out, buf, len);
  free(buf);
  return out;
#else
  return moonbit_make_bytes(0, 0);
#endif
}

// --- exit ---

MOONBIT_FFI_EXPORT void moonbit_toml_cli_exit(int code) {
  exit(code);
}

#ifdef __cplusplus
}
#endif
