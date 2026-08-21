// Native stdin reader for toml-cli.
// Reads all of stdin into a MoonBit Bytes value.

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

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

#ifdef __cplusplus
}
#endif
