import gleam/result
import gleam/io
import gleam/iterator

import shellout
import simplifile.{write, read}
import tom.{parse}

pub fn main() {
  // build the js build
  let res = shellout.command(run: "gleam", in: ".", with: ["build", "--target", "javascript"], opt: [])

  case result.is_error(res) {
    True -> io.debug("Failed to execute gleam")
    False -> io.debug("Executed gleam")
  }

  // parse the projects gleam.toml file
  let assert Ok(project_toml) = read(from: "./gleam.toml")
  let assert Ok(parsed) = parse(project_toml)
  let assert Ok(name) = tom.get_string(parsed, ["name"])

  // write the compile.js file
  let compile_content = "import {main} from \"./" <> name <> "/" <> name <> ".mjs\";main();"
  let res = compile_content
            |> write(to: "./build/dev/javascript/compile.js")
  case result.is_error(res) {
    True -> io.debug("Failed to write file")
    False -> io.debug("Wrote file")
  }

  // write the deno configuration (disables some checks)
  let deno_config = "
{
  \"compilerOptions\": {
    \"noImplicitAny\": false,
    \"strict\": false
  }
}
    "

  let res = deno_config
            |> write(to: "./build/dev/javascript/deno.json")
  case result.is_error(res) {
    True -> io.debug("Failed to write file")
    False -> io.debug("Wrote file")
  }

  // parse the gleative.toml file
  let assert Ok(gleative_toml) = read(from: "./gleative.toml")
  let assert Ok(parsed) = parse(gleative_toml)
  let assert Ok(targets) = tom.get_array(parsed, ["targets"])

  // compile to native executable with deno
  iterator.from_list(targets)
  |> iterator.map(fn(target_toml) {
    let target = case target_toml {
      tom.String(target) -> target
      _ -> io.debug("Not a string")
    }
    let res = shellout.command(run: "deno", in: "./build/dev/javascript", with: ["compile", "--no-check", "-A", "--config", "./deno.json", "--target", target, "--output", "../../gleative_out/" <> target <> "/out", "./compile.js"], opt: [])
    case result.is_error(res) {
      True -> io.debug("Failed to execute deno for target " <> target)
      False -> io.debug("Executed deno for " <> target)
    }
  })
  |> iterator.to_list // execute the iterator
}
