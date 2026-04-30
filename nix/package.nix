{ stdenv, fetchurl, version, sha256 }:

stdenv.mkDerivation {
  pname = "git-widget";
  inherit version;

  src = fetchurl {
    url = "https://github.com/albe2669/git-widget/releases/download/v${version}/GitWidget.tar.gz";
    hash = sha256;
  };

  # Pre-built binary — nothing to compile
  dontBuild = true;

  installPhase = ''
    mkdir -p "$out/Applications"
    tar -xzf "$src" -C "$out/Applications/"
  '';

  meta.platforms = [ "aarch64-darwin" ];
}
