///|
let version : String = "0.3.3"

///|
let about : String =
  #|Parse, validate, query, and format TOML files.
  #|
  #|Every command reads from a file argument when given, and from standard
  #|input otherwise, so it composes in pipelines like `jq`:
  #|
  #|  cat config.toml | toml_cli get .server.host
  #|  echo 'a = 1' | toml_cli check
  #|
  #|Run it from mooncakes.io without installing (the binary is fetched and
  #|cached on first use; pin a version with moonbit-community/toml_cli@<version>):
  #|
  #|  moonx moonbit-community/toml_cli check config.toml
  #|  moonx moonbit-community/toml_cli format config.toml
  #|  moonx moonbit-community/toml_cli tojson config.toml
  #|  moonx moonbit-community/toml_cli get .server.host config.toml
  #|
  #|Exit codes:
  #|  0  success
  #|  1  the input could not be read or is not valid TOML, or the queried
  #|     path does not exist; a human-readable error is printed to stdout
  #|  2  usage error (unknown subcommand or missing required argument)
  #|
  #|`format` prints the normalized document to stdout; it never rewrites the
  #|input file. To format in place, redirect stdout to a temporary file and
  #|move it over the original after checking the exit code.
  #|
  #|`get` prints the value at a dotted path (e.g. `.server.host`, `.ports[0]`);
  #|strings are printed raw, other values in TOML form.

///|
fn toml_command() -> @argparse.Command {
  Command(
    "toml_cli",
    about~,
    version~,
    positionals=[
      PositionArg(
        "file",
        about="Parse TOML and print normalized TOML (default: read stdin).",
        num_args=@argparse.ValueRange(lower=0, upper=1),
      ),
    ],
    subcommands=[
      Command("format", about="Parse TOML and print normalized TOML.", positionals=[
        PositionArg(
          "file",
          about="TOML file to format (default: read stdin).",
          num_args=@argparse.ValueRange(lower=0, upper=1),
        ),
      ]),
      Command("check", about="Validate TOML without printing parsed output.", positionals=[
        PositionArg(
          "file",
          about="TOML file to validate (default: read stdin).",
          num_args=@argparse.ValueRange(lower=0, upper=1),
        ),
      ]),
      Command("tojson", about="Parse TOML and print it as JSON.", positionals=[
        PositionArg(
          "file",
          about="TOML file to convert (default: read stdin).",
          num_args=@argparse.ValueRange(lower=0, upper=1),
        ),
      ]),
      Command(
        "get",
        about="Print the value at a dotted path, e.g. .server.host.",
        positionals=[
          PositionArg(
            "path",
            about="Path expression, e.g. .server.host or .ports[0].",
            num_args=@argparse.ValueRange::single(),
          ),
          PositionArg(
            "file",
            about="TOML file to read (default: read stdin).",
            num_args=@argparse.ValueRange(lower=0, upper=1),
          ),
        ],
      ),
    ],
  )
}

///|
fn main {
  let code = run(get_args()[1:])
  if code != 0 {
    exit(code)
  }
}

///|
fn run(args : ArrayView[String]) -> Int {
  let matches = @argparse.parse(toml_command(), argv=args, env=Map([])) catch {
    err => {
      println(err)
      return 2
    }
  }
  match matches.subcommand {
    Some(("format", child)) => dispatch_source(child, format_source)
    Some(("check", child)) => dispatch_source(child, check_source)
    Some(("tojson", child)) => dispatch_source(child, tojson_source)
    Some(("get", child)) => dispatch_get(child)
    Some((name, _)) => {
      println("error: unsupported command `\{name}`")
      2
    }
    None => dispatch_source(matches, format_source)
  }
}

///|
fn dispatch_source(
  matches : @argparse.Matches,
  action : (String, String) -> Int,
) -> Int {
  match matches.values.get("file") {
    Some([path]) if path != "-" =>
      match read_source_file(path) {
        Some(source) => action(source, path)
        None => 1
      }
    _ => action(read_stdin(), "-")
  }
}

///|
fn dispatch_get(matches : @argparse.Matches) -> Int {
  let path = match matches.values.get("path") {
    Some([p]) => p
    _ => return 2
  }
  match matches.values.get("file") {
    Some([file]) if file != "-" =>
      match read_source_file(file) {
        Some(source) => get_source(source, path)
        None => 1
      }
    _ => get_source(read_stdin(), path)
  }
}

///|
fn fail_parse(label : String, err : Error) -> Int {
  let source = if label == "-" { "input" } else { label }
  println("error: failed to parse \{source}: \{err}")
  1
}

///|
fn get_source(source : String, path : String) -> Int {
  let value = @toml_lib.parse(source) catch {
    err => {
      println("error: failed to parse input: \{err}")
      return 1
    }
  }
  match get_path(value, path) {
    Some(result) => {
      println(render(result))
      0
    }
    None => {
      println("error: no value at path `\{path}`")
      1
    }
  }
}

///|
fn format_source(source : String, label : String) -> Int {
  let value = @toml_lib.parse(source) catch {
    err => return fail_parse(label, err)
  }
  println(value.to_string().trim_end().to_owned())
  0
}

///|
fn check_source(source : String, label : String) -> Int {
  let _ = @toml_lib.parse(source) catch { err => return fail_parse(label, err) }
  if label == "-" {
    println("OK")
  } else {
    println("\{label}: OK")
  }
  0
}

///|
fn tojson_source(source : String, label : String) -> Int {
  let value = @toml_lib.parse(source) catch {
    err => return fail_parse(label, err)
  }
  println(to_json(value).stringify(indent=2))
  0
}
