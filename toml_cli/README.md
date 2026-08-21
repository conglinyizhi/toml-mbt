# toml_cli

A jq-style command-line tool to parse, query, validate, and format TOML,
built on [`conglinyizhi/toml`](https://mooncakes.io/docs/conglinyizhi/toml).

Every command reads from a file argument when given, and from standard input
otherwise, so it composes in pipelines:

```bash
cat config.toml | toml_cli get .server.host
echo 'a = 1' | toml_cli check
```

## Run without installing

The prebuilt binary can be run directly from mooncakes.io (as a WASM skill)
— it is fetched and cached on first use:

```bash
moon runwasm conglinyizhi/toml-cli --help
moon runwasm conglinyizhi/toml-cli check config.toml
moon runwasm conglinyizhi/toml-cli format config.toml
moon runwasm conglinyizhi/toml-cli get .server.host config.toml
```

## Usage

```
toml [file]           Parse TOML and print normalized TOML (default: stdin)
toml format [file]    Parse TOML and print normalized TOML
toml check [file]     Validate TOML without printing parsed output
toml tojson [file]    Parse TOML and print it as JSON
toml get <path> [file]  Print the value at a dotted path
```

`get` path syntax: `.` or empty for the whole document, `.server.host` for
nested keys, `.ports[0]` for array indices. Strings are printed raw (no
quotes); tables and arrays are printed in TOML form.

Exit codes: `0` on success, `1` on read/parse failure or a missing path,
`2` on usage errors.

`tojson` maps tables to objects and arrays to arrays; datetimes become their
TOML string form, integers keep their exact 64-bit decimal representation,
and non-finite floats become the strings `"nan"`/`"inf"`/`"-inf"`.

## Run from source

```bash
moon runwasm .                          # in this directory (wasm)
moon run --target native . -- --help    # native build
```
