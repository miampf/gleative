import gleam/result
import gleam/io

import shellout
import simplifile.{write}

pub fn main() {
  // build the js build
  let res = shellout.command(run: "gleam", in: ".", with: ["build", "--target", "javascript"], opt: [])

  case result.is_error(res) {
    True -> io.debug("Failed to execute gleam")
    False -> io.debug("Executed gleam")
  }

  // write the compile.js file
  let compile_content = "import {main} from \"./gleanative/gleanative.mjs\";main();"
  let res = compile_content
            |> write(to: "./build/dev/javascript/compile.js")
  case result.is_error(res) {
    True -> io.debug("Failed to write file")
    False -> io.debug("Wrote file")
  }

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

  // compile to native with deno
  let res = shellout.command(run: "deno", in: "./build/dev/javascript", with: ["compile", "./compile.js", "--no-check", "-A", "--config", "./deno.json"], opt: [])
  
  case result.is_error(res) {
    True -> io.debug("Failed to execute deno")
    False -> io.debug("Executed deno")
  }
}
