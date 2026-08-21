---
name: conglinyizhi/toml-cli
description: Parse, query, validate, and format TOML from stdin or files. jq-style dotted-path queries (get), TOML↔JSON conversion, and formatting.
---

# toml-cli

A jq-style command-line tool for TOML. Reads TOML from a file argument or
from standard input, so it composes in pipelines.

## Usage

```bash
moon runwasm conglinyizhi/toml-cli@0.3.3 check config.toml   # validate a file
moon runwasm conglinyizhi/toml-cli@0.3.3 get .server.host config.toml
cat config.toml | moon runwasm conglinyizhi/toml-cli get .ports[0]
echo 'a = 1' | moon runwasm conglinyizhi/toml-cli check
moon runwasm conglinyizhi/toml-cli tojson config.toml
```

## Subcommands

- `format [file]` — print normalized TOML (default command; reads stdin when no file given)
- `check [file]` — validate; prints `OK` or an error
- `tojson [file]` — convert TOML to JSON
- `get <path> [file]` — print the value at a dotted path

## Path syntax for `get`

- `.` or empty — whole document
- `.server.host` — nested table keys
- `.ports[0]` — array index
- `.matrix[1].name` — mixed nesting

Strings are printed raw (no quotes); tables and arrays are printed in TOML form.

## Exit codes

- `0` success
- `1` invalid input / missing path
- `2` usage error

## Examples

Input: `[server]\nhost = "example.com"\nports = [8000, 8001]\n`

```bash
$ printf '[server]\nhost = "example.com"\nports = [8000, 8001]\n' \
    | moon runwasm conglinyizhi/toml-cli get .server.host
example.com

$ printf '[server]\nports = [8000, 8001]\n' \
    | moon runwasm conglinyizhi/toml-cli get .server.ports[1]
8001
```
