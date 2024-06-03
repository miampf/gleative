import gleam/result
import gleam/io
import gleam/iterator

import shellout
import simplifile.{write, read}
import tom.{parse}
import spinner
import gleam_community/ansi

pub fn main() {
  let spinner =
    spinner.new("Gleative compile")
    |> spinner.with_colour(ansi.blue)
    |> spinner.start

  spinner.set_text(spinner, "Compiling gleam project to javascript...")

  build_js()
  write_config()
  compile_native(spinner)

  spinner.stop(spinner)
  "Finished compilation! You can find your native executables in ./build/gleative_out"
  |> ansi.green
  |> io.println
}

fn build_js() {
  let res = shellout.command(run: "gleam", in: ".", with: ["build", "--target", "javascript"], opt: [])

  case result.is_error(res) {
    True -> io.println("Failed to execute gleam")
    False -> Nil
  }
}

fn write_config() {
  // parse the projects gleam.toml file
  let assert Ok(project_toml) = read(from: "./gleam.toml")
  let assert Ok(parsed) = parse(project_toml)
  let assert Ok(name) = tom.get_string(parsed, ["name"])

  // write the compile.js file
  let compile_content = "import {main} from \"./" <> name <> "/" <> name <> ".mjs\";main();"
  let res = compile_content
    |> write(to: "./build/dev/javascript/compile.js")
  case result.is_error(res) {
    True -> io.println("Failed to write file")
    False -> Nil
  }

  // write the deno configuration (disables some checks)
  let deno_config = "{\"compilerOptions\":{\"noImplicitAny\":false,\"strict\":false}}"

  let res = deno_config
    |> write(to: "./build/dev/javascript/deno.json")
  case result.is_error(res) {
    True -> io.println("Failed to write file")
    False -> Nil
  }
}

fn compile_native(spinner) {
  // parse the gleative.toml file
  let assert Ok(gleative_toml) = read(from: "./gleative.toml")
  let assert Ok(parsed) = parse(gleative_toml)
  let assert Ok(targets) = tom.get_array(parsed, ["targets"])

  // compile to native executable with deno
  iterator.from_list(targets)
  |> iterator.map(fn(target_toml) {
    let target = case target_toml {
      tom.String(target) -> target
      _ -> {
        io.println("Not a string")
        ""
      }
    }
    spinner.set_text(spinner, "Compiling target " <> target <> " with deno...")    
    let res = shellout.command(run: "deno", in: "./build/dev/javascript", with: ["compile", "--no-check", "-A", "--config", "./deno.json", "--target", target, "--output", "../../gleative_out/" <> target <> "/out", "./compile.js"], opt: [])
    case result.is_error(res) {
      True -> io.println("Failed to execute deno for target " <> target)
      False -> Nil
    }
  })
  |> iterator.to_list // execute the iterator
}
