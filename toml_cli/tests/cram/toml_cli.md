# TOML CLI Cram Tests

These Moon Cram tests document the native `toml` executable. `moon cram` builds
the native CLI and puts `toml-cli.exe` on `PATH`:

```bash
moon cram test --release tests/cram
```

## Help And Version

```mooncram
$ toml-cli.exe --version
0.3.3
```

```mooncram
$ toml-cli.exe --help
Usage: toml_cli [file] [command]

Parse, validate, query, and format TOML files.

Every command reads from a file argument when given, and from standard
input otherwise, so it composes in pipelines like `jq`:

  cat config.toml | toml_cli get .server.host
  echo 'a = 1' | toml_cli check

Run it from mooncakes.io without installing (the binary is fetched and
cached on first use; pin a version with moonbit-community/toml_cli@<version>):

  moonx moonbit-community/toml_cli check config.toml
  moonx moonbit-community/toml_cli format config.toml
  moonx moonbit-community/toml_cli tojson config.toml
  moonx moonbit-community/toml_cli get .server.host config.toml

Exit codes:
  0  success
  1  the input could not be read or is not valid TOML, or the queried
     path does not exist; a human-readable error is printed to stdout
  2  usage error (unknown subcommand or missing required argument)

`format` prints the normalized document to stdout; it never rewrites the
input file. To format in place, redirect stdout to a temporary file and
move it over the original after checking the exit code.

`get` prints the value at a dotted path (e.g. `.server.host`, `.ports[0]`);
strings are printed raw, other values in TOML form.

Commands:
  format  Parse TOML and print normalized TOML.
  check   Validate TOML without printing parsed output.
  tojson  Parse TOML and print it as JSON.
  get     Print the value at a dotted path, e.g. .server.host.
  help    Print help for the subcommand(s).

Arguments:
  file  Parse TOML and print normalized TOML (default: read stdin).

Options:
  -h, --help     Show help information.
  -V, --version  Show version information.
```

```mooncram
$ printf 'title = "MoonBit"\n' | toml-cli.exe
title = "MoonBit"
```


## Format A File

```mooncram
$ cat > sample.toml <<'EOF'
> title = "MoonBit"
> ports = [8000, 8001]
> [server]
> enabled = true
> EOF
> toml-cli.exe format sample.toml
title = "MoonBit"

ports = [8000, 8001]

[server]
enabled = true
```

## Check A File

```mooncram
$ cat > valid.toml <<'EOF'
> package = "toml"
> version = "0.2.3"
> EOF
> toml-cli.exe check valid.toml
valid.toml: OK
```

## Convert To JSON

Integers keep their exact 64-bit decimal representation (note `big` below
is 2^53 + 1, which a double cannot represent), and datetimes become their
TOML string form:

```mooncram
$ cat > convert.toml <<'EOF'
> title = "MoonBit"
> ports = [8000, 8001]
> pi = 3.14
> big = 9007199254740993
> date = 1979-05-27T07:32:00Z
> [server]
> enabled = true
> EOF
> toml-cli.exe tojson convert.toml
{
  "title": "MoonBit",
  "ports": [
    8000,
    8001
  ],
  "pi": 3.14,
  "big": 9007199254740993,
  "date": "1979-05-27T07:32:00Z",
  "server": {
    "enabled": true
  }
}
```

## Report Parse Errors

```mooncram
$ cat > invalid.toml <<'EOF'
> key =
> EOF
> toml-cli.exe check invalid.toml
error: failed to parse invalid.toml: Failure(parser.mbt:*@conglinyizhi/toml FAILED: Expected value at { start: { line: 1, column: 6 }, end: { line: 2, column: 1 } }) (glob)
[1]
```


## Query A Value (get)

```mooncram
$ cat > query.toml <<'EOF'
> title = "MoonBit"
> [server]
> host = "example.com"
> ports = [8000, 8001]
> EOF
> toml-cli.exe get .server.host query.toml
example.com
```

```mooncram
$ cat > query.toml <<'EOF'
> [server]
> ports = [8000, 8001]
> EOF
> toml-cli.exe get .server.ports[1] query.toml
8001
```

```mooncram
$ cat > query.toml <<'EOF'
> [server]
> ports = [8000, 8001]
> EOF
> toml-cli.exe get .server.ports[9] query.toml
error: no value at path `.server.ports[9]`
[1]
```

```mooncram
$ printf 'a = 1\n' | toml-cli.exe get .a
1
```
