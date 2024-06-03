{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      {
        packages.default = rec {
          buildInputs = [ gleam deno ];

          buildPhase = ''
          gleam run -m gleative
          '';
        }
      }
    );
}
