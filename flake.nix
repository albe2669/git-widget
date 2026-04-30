{
  description = "GitWidget — macOS Tahoe GitHub PR widget";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, devenv, nix-darwin, ... }@inputs: {
    devShells.aarch64-darwin.default = devenv.lib.mkShell {
      inherit inputs;
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      modules = [ ./devenv.nix ];
    };

    # Add to your nix-darwin flake:
    #   inputs.git-widget.url = "path:/path/to/git-widget";
    #   darwinModules = [ inputs.git-widget.darwinModules.default ];
    darwinModules.default = import ./nix/darwin-module.nix;
  };
}
