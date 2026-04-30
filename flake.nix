{
  description = "GitWidget — macOS Tahoe GitHub PR widget";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      version = "0.0.6"; # @release
      sha256  = "sha256-kAKd+xedobjai/Ntr3u6qOfHChQdW/40b2U/w+rDAR8="; # @release

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
