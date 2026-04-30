{ pkgs, ... }: {
  packages = with pkgs; [
    swiftlint
    swiftformat
    xcbeautify
    jq
    just
  ];

  enterShell = ''
    echo "GitWidget dev environment"
    XCODE_VER=$(xcodebuild -version 2>/dev/null | head -1 || echo "NOT INSTALLED — install from App Store")
    echo "Xcode: $XCODE_VER"
  '';
}
