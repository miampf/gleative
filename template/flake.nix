{
  description = "Gleative flake setup.";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      with pkgs;
      {
        packages.gleative-build = pkgs.writeScriptBin "gleative-build" ''
        gleam run -m gleative
        '';

        apps.build = {
          type = "app";
          buildInputs = [ gleam deno ];
          program = "${self.packages.${system}.gleative-build}/bin/gleative-build";
        };
      }
    );
}
