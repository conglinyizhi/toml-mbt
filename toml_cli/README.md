# toml_cli

A command-line tool to parse, validate, and format TOML files, built on
[`moonbit-community/toml`](https://mooncakes.io/docs/moonbit-community/toml).

## Run without installing

The prebuilt binary can be run directly from mooncakes.io — it is fetched
and cached on first use, and arguments are passed straight through (no `--`
separator needed). Pin a version with `moonbit-community/toml_cli@<version>` for
reproducible behavior:

```bash
moonx moonbit-community/toml_cli --help
moonx moonbit-community/toml_cli check config.toml
moonx moonbit-community/toml_cli format config.toml
```

## Usage

```
toml <file>           Parse TOML and print normalized TOML (same as `format`)
toml format <file>    Parse TOML and print normalized TOML
toml check <file>     Validate TOML without printing parsed output
toml tojson <file>    Parse TOML and print it as JSON
```

Exit codes: `0` on success, `1` on read/parse failure, `2` on usage errors.

`tojson` maps tables to objects and arrays to arrays; datetimes become their
TOML string form, integers keep their exact 64-bit decimal representation,
and non-finite floats become the strings `"nan"`/`"inf"`/`"-inf"`.

## Run from source

```bash
moon runwasm .                          # in this directory
moon run --target native . -- --help    # native build
```
