{
  description = "GitWidget — macOS Tahoe GitHub PR widget";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      version = "0.0.13"; # @release
      sha256  = "sha256-cycVB9pIKUWaVRet6M9B0Us6wyJ3obaeahkfcie7HUE="; # @release

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
