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

  build_js()
  write_config()
  let _ =
    compile_native(spinner)
    |> result.map_error(snag.pretty_print)

  spinner.stop(spinner)
  "Finished compilation! You can find your native executables in ./build/gleative_out"
  |> ansi.green
  |> io.println
}

fn build_js() {
  let res =
    shellout.command(
      run: "gleam",
      in: ".",
      with: ["build", "--target", "javascript"],
      opt: [],
    )

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
  let compile_content =
    "import {main} from \"./" <> name <> "/" <> name <> ".mjs\";main();"
  let res =
    compile_content
    |> write(to: "./build/dev/javascript/compile.js")
  case result.is_error(res) {
    True -> io.println("Failed to write file")
    False -> Nil
  }

  // write the deno configuration (disables some checks)
  let deno_config =
    "{\"compilerOptions\":{\"noImplicitAny\":false,\"strict\":false}}"

  let res =
    deno_config
    |> write(to: "./build/dev/javascript/deno.json")
  case result.is_error(res) {
    True -> io.println("Failed to write file")
    False -> Nil
  }
}

fn compile_native(spinner) -> Result(Nil) {
  let targets =
    get_targets()
    |> snag.context("Failed to get targets")

  case targets {
    Error(e) -> Error(e)
    Ok(targets) -> Ok(compile_targets(spinner, targets))
  }
}

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

fn compile_targets(spinner, targets) {
  // compile to native executable with deno
  // iterator.from_list(targets)
  // |> iterator.map(fn(target_toml) {
  //   let target = case target_toml {
  //     tom.String(target) -> target
  //     _ -> {
  //       io.println("Not a string")
  //       ""
  //     }
  //   }
  //   spinner.set_text(spinner, "Compiling target " <> target <> " with deno...")
  //   let res =
  //     shellout.command(
  //       run: "deno",
  //       in: "./build/dev/javascript",
  //       with: [
  //         "compile",
  //         "--no-check",
  //         "-A",
  //         "--config",
  //         "./deno.json",
  //         "--target",
  //         target,
  //         "--output",
  //         "../../gleative_out/" <> target <> "/out",
  //         "./compile.js",
  //       ],
  //       opt: [],
  //     )
  //   case result.is_error(res) {
  //     True -> io.println("Failed to execute deno for target " <> target)
  //     False -> Nil
  //   }
  // })
  // |> iterator.to_list
  // execute the iterator

  case targets {
    [first, ..rest] -> {
      let target =
        get_target_string(first)
        |> snag.context("Target is not a string, continuing with next target")
        |> result.map_error(snag.pretty_print)

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
            |> result.map_error(snag.pretty_print)
          compile_targets(spinner, rest)
        }
      }
    }
    [] -> Nil
  }
}

fn get_target_string(target) -> Result(String) {
  case target {
    tom.String(target) -> Ok(target)
    _ -> Error(snag.new("Target value is not a string"))
  }
}

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
