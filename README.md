# gleative

[![Package Version](https://img.shields.io/hexpm/v/gleative)](https://hex.pm/packages/gleative)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleative/)

Easily compile your gleam projects to native executables using [deno](https://deno.com/).

## Installation and usage

First of all, install [deno](https://docs.deno.com/runtime/manual/#install-deno).

Afterwards add `gleative` to your gleam project by running

```sh
gleam add gleative
```

Now you have to create a file called `gleative.toml` in your projects root directory.
Currently, this file is only used to define your compilation targets. Add the following to your
`gleative.toml`.

```toml
targets = [
  "x86_64-unknown-linux-gnu"
]
```

This adds linux to your compilation targets. `gleative` should support all targets
[deno supports](https://docs.deno.com/runtime/manual/tools/compiler#cross-compilation).

Now, you can simply run:

```sh
gleam run -m gleative
```

This should be executed in your projects root directory. All compiled targets can be found in
`./build/gleative_out`.

### Using nix

If you want to make your builds more reproducible, `gleative` provides a flake template for
[nix](https://nixos.org/). To initialize it, simply run

```sh
nix flake init -t github:miampf/gleative
```

This will create a new `flake.nix` as well as a `gleative.toml` file. Now, you can run

```sh
nix run ".#build"
```

to build your project.

## How it works

`gleative` works relatively simple. First, it builds your gleam project for javascript and generates
some light glue code. After that, it compiles the generated javascript code using 
[deno as a compiler](https://docs.deno.com/runtime/manual/tools/compiler).
