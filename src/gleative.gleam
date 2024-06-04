import gleam/int
import gleam/io
import gleam/result

import gleam_community/ansi
import shellout
import simplifile.{read, write}
import snag.{type Result}
import spinner
import tom.{parse}

pub fn main() {
  let spinner =
    spinner.new("Gleative compile")
    |> spinner.with_colour(ansi.blue)
    |> spinner.start

  spinner.set_text(spinner, "Compiling gleam project to javascript...")

  let _ =
    build_js()
    |> snag.context("Failed to build javascript")
    |> result.map_error(fn(e) {
      io.println("")
      e
      |> snag.pretty_print
      |> ansi.red
      |> io.println_error
    })
  let _ =
    write_config()
    |> snag.context("Failed to write necessary configuration and glue code")
    |> result.map_error(fn(e) {
      io.println("")
      e
      |> snag.pretty_print
      |> ansi.red
      |> io.println_error
    })
  let _ =
    compile_native(spinner)
    |> snag.context("Failed to compile javascript to a native executable")
    |> result.map_error(fn(e) {
      io.println("")
      e
      |> snag.pretty_print
      |> ansi.red
      |> io.println_error
    })

  spinner.stop(spinner)
  "Finished compilation! You can find your native executables in ./build/gleative_out"
  |> ansi.green
  |> io.println
}

/// `build_js` builds the gleam project for javascript.
fn build_js() -> Result(Nil) {
  shellout.command(
    run: "gleam",
    in: ".",
    with: ["build", "--target", "javascript"],
    opt: [],
  )
  |> result.map_error(fn(detail) {
    let #(status, message) = detail

    snag.new(
      "Gleam failed with exit code " <> int.to_string(status) <> ": " <> message,
    )
  })
  // we don't care about the command output
  |> result.map(fn(_) { Nil })
}

/// `write_config` writes configuration and glue code. The configuration just
/// disables a few checks.
fn write_config() {
  // parse the projects gleam.toml file
  use name <- result.try(get_project_name())
  use _ <- result.try(write_compile_js(name))
  write_deno_config()
}

/// `get_project_name` gets the project name from `gleam.toml`.
fn get_project_name() -> Result(String) {
  read(from: "./gleam.toml")
  |> result.replace_error(snag.new("Failed to read \"gleam.toml\""))
  |> result.map(fn(content) {
    content
    |> parse
    |> result.replace_error(snag.new("Failed to parse \"gleam.toml\""))
  })
  |> result.flatten
  |> result.map(fn(parsed) {
    tom.get_string(parsed, ["name"])
    |> result.replace_error(snag.new("Failed to get name from \"gleam.toml\""))
  })
  |> result.flatten
}

/// `write_deno_config` writes configuration for deno.
fn write_deno_config() {
  let deno_config =
    "{\"compilerOptions\":{\"noImplicitAny\":false,\"strict\":false}}"

  deno_config
  |> write(to: "./build/dev/javascript/deno.json")
  |> result.replace_error(snag.new(
    "Failed to write \"./build/dev/javascript/deno.json\"",
  ))
}

/// `write_compile_js` writes some glue code into `compile.js` that just
/// executes the `main` function of the compiled gleam project.
fn write_compile_js(name) {
  // write the compile.js file
  let compile_content =
    "import {main} from \"./" <> name <> "/" <> name <> ".mjs\";main();"
  compile_content
  |> write(to: "./build/dev/javascript/compile.js")
  |> result.replace_error(snag.new(
    "Failed to write \"./build/dev/javascript/compile.js\"",
  ))
}

/// `compile_native` uses deno to compile the `compile.js` file into a native
/// executable.
fn compile_native(spinner) -> Result(Nil) {
  let targets =
    get_targets()
    |> snag.context("Failed to get targets")

  case targets {
    Error(e) -> Error(e)
    Ok(targets) -> Ok(compile_targets(spinner, targets))
  }
}

/// `get_targets` gets the defined list of targets from `gleative.toml`.
fn get_targets() -> Result(List(tom.Toml)) {
  // parse the gleative.toml file
  read(from: "./gleative.toml")
  |> result.replace_error(snag.new("Failed to read \"gleative.toml\""))
  |> result.map(fn(content) {
    content
    |> parse
    |> result.replace_error(snag.new("Failed to parse \"gleative.toml\""))
  })
  |> result.flatten
  |> result.map(fn(parsed) {
    tom.get_array(parsed, ["targets"])
    |> result.replace_error(snag.new(
      "Failed to get targets from \"gleative.toml\"",
    ))
  })
  |> result.flatten
}

/// `compile_targets` compiles `compile.js` for all given targets.
fn compile_targets(spinner, targets) {
  case targets {
    [first, ..rest] -> {
      let target =
        get_target_string(first)
        |> snag.context("Target is not a string, continuing with next target")
        |> result.map_error(fn(e) {
          io.println("")
          e
          |> snag.pretty_print
          |> ansi.red
          |> io.println_error
        })

      case result.is_error(target) {
        // if it's not a string, just do the next target
        True -> compile_targets(spinner, rest)
        // else, do the current target
        False -> {
          let target = result.unwrap(target, "")
          let _ =
            execute_deno(target)
            |> snag.context(
              "Failed to compile target " <> target <> " with deno",
            )
            // we want to continue compilation so we just print
            |> result.map_error(fn(e) {
              io.println("")
              e
              |> snag.pretty_print
              |> ansi.red
              |> io.println_error
            })
          compile_targets(spinner, rest)
        }
      }
    }
    [] -> Nil
  }
}

/// `get_target_string` tries to convert a `tom.String` to a String.
fn get_target_string(target) -> Result(String) {
  case target {
    tom.String(target) -> Ok(target)
    _ -> Error(snag.new("Target value is not a string"))
  }
}

/// `execute_deno` executes deno to compile `compile.js` to native code.
fn execute_deno(target) -> Result(Nil) {
  shellout.command(
    run: "deno",
    in: "./build/dev/javascript",
    with: [
      "compile",
      "--no-check",
      "-A",
      "--config",
      "./deno.json",
      "--target",
      target,
      "--output",
      "../../gleative_out/" <> target <> "/out",
      "./compile.js",
    ],
    opt: [],
  )
  |> result.map_error(fn(detail) {
    let #(status, message) = detail

    snag.new(
      "Deno failed to execute for "
      <> target
      <> " with exit code "
      <> int.to_string(status)
      <> ": "
      <> message,
    )
  })
  // just nil the output of deno
  |> result.map(fn(_) { Nil })
}
