{
  description = "GitWidget — macOS Tahoe GitHub PR widget";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      version = "0.0.7"; # @release
      sha256  = "sha256-OlygXx7Dv/h8o1yIM3apogWR2pcAD1yrTfNtQdHB6IM="; # @release

      pkgs    = nixpkgs.legacyPackages.aarch64-darwin;
      package = pkgs.callPackage ./nix/package.nix { inherit version sha256; };
    in {
      packages.aarch64-darwin.default = package;

      # nixpkgs.overlays = [ inputs.git-widget.overlays.default ];
      overlays.default = final: _: {
        git-widget = self.packages.${final.system}.default;
      };

      # imports = [ inputs.git-widget.homeManagerModules.default ];
      homeManagerModules.default = import ./nix/darwin-module.nix { inherit package; };
    };
}
