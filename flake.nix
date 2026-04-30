{
  description = "GitWidget — macOS Tahoe GitHub PR widget";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }: {
    # Add to your home-manager flake:
    #   inputs.git-widget.url = "github:albe2669/git-widget";
    #   imports = [ inputs.git-widget.homeManagerModules.default ];
    homeManagerModules.default = import ./nix/darwin-module.nix;
  };
}
