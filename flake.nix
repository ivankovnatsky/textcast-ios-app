{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/a16efe5d2fc7455d7328a01f4692bfec152965b3";
    flake-utils.url = "github:numtide/flake-utils/b1d9ab70662946ef0850d488da1c9019f3a9752a";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixfmt-rfc-style
          nodePackages.prettier
          pre-commit
          swiftformat
          treefmt
        ];

        shellHook = ''
          echo "Run 'treefmt' to format all files"
        '';
      };
    });
}
