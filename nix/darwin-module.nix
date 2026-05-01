# Called as: import ./nix/darwin-module.nix { inherit package; }
# `package` is the pre-built GitWidget package fetched from GitHub releases.
{ package }:

{ config, lib, ... }:

let
  cfg = config.programs.git-widget;

  bool = b: if b then "true" else "false";

  filterToml = filters:
    if builtins.length filters == 1
    then "\"${builtins.head filters}\""
    else "[${lib.concatMapStringsSep ", " (f: "\"${f}\"") filters}]";

  repoToml = repo: ''
    [[repositories]]
    owner = "${repo.owner}"
    name = "${repo.name}"
    filter = ${filterToml repo.filter}
    ${lib.optionalString (repo.assignedGroup != null && repo.assignedGroup != "") "assigned_group = \"${repo.assignedGroup}\""}

      [repositories.notifications]
      new_pr = ${bool repo.notifications.newPR}
      assigned = ${bool repo.notifications.assigned}
      review_requested = ${bool repo.notifications.reviewRequested}
      ci_failed = ${bool repo.notifications.ciFailed}
  '';

  tokenLine =
    if cfg.github.tokenFile != null then ''token_file = "${cfg.github.tokenFile}"''
    else if cfg.github.token != null then ''token = "${cfg.github.token}"''
    else "";

  configContent = ''
    [github]
    ${tokenLine}
    ${lib.optionalString (cfg.github.username != null) "username = \"${cfg.github.username}\""}
    update_interval = ${toString cfg.github.updateInterval}

    ${lib.concatMapStrings repoToml cfg.repositories}
  '';

in {
  options.programs.git-widget = {
    enable = lib.mkEnableOption "GitWidget GitHub PR menu-bar app";

    github = {
      token = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "GitHub personal access token (plain text). Prefer tokenFile for secrets.";
      };
      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to a file containing the GitHub token (use with sops-nix).";
        example = "config.sops.secrets.github-token.path";
      };
      username = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "GitHub username (optional; defaults to the token's owner).";
      };
      updateInterval = lib.mkOption {
        type = lib.types.int;
        default = 900;
        description = "Fetch interval in seconds.";
      };
    };

    repositories = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          owner = lib.mkOption { type = lib.types.str; };
          name  = lib.mkOption { type = lib.types.str; };
          filter = lib.mkOption {
            type = lib.types.listOf (lib.types.enum [ "all" "opened" "assigned" "assigned-direct" "assigned-group" "none" ]);
            default = [ "assigned" ];
            description = "One or more filter modes — results are unioned.";
          };
          assignedGroup = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Team slug for 'assigned-group' filter (case-insensitive match).";
          };
          notifications = {
            newPR           = lib.mkOption { type = lib.types.bool; default = true; };
            assigned        = lib.mkOption { type = lib.types.bool; default = true; };
            reviewRequested = lib.mkOption { type = lib.types.bool; default = true; };
            ciFailed        = lib.mkOption { type = lib.types.bool; default = false; };
          };
        };
      });
      default = [];
      description = "Repositories to monitor.";
    };

    signingIdentity = lib.mkOption {
      type = lib.types.str;
      default = "Apple Development";
      description = "codesign identity from your login Keychain used to sign the app after install. App Groups (required for the widget) need a real identity. Run: security find-identity -v -p codesigning";
    };
  };

  config = lib.mkIf cfg.enable {
    # Write config to ~/.config/git-widget/config.toml
    home.file.".config/git-widget/config.toml".text = configContent;

    # Copy the pre-built app from the Nix store to ~/Applications and sign it.
    # Nix content-addresses the store path, so this only re-runs when the
    # package version actually changes.
    home.activation.installGitWidget = lib.hm.dag.entryAfter ["writeBoundary"] ''
      _pkg="${package}"
      _dest="${config.home.homeDirectory}/Applications/GitWidget.app"
      _state="${config.home.homeDirectory}/.local/state/git-widget"
      _record="$_state/installed-pkg"

      _needs_install=0
      if [ ! -d "$_dest" ]; then
        _needs_install=1
      elif [ "$(cat "$_record" 2>/dev/null)" != "$_pkg" ]; then
        _needs_install=1
      fi

      if [ "$_needs_install" -eq 1 ]; then
        echo "GitWidget: installing from $_pkg"
        $DRY_RUN_CMD chmod -R u+w "$_dest" 2>/dev/null || true
        $DRY_RUN_CMD rm -rf "$_dest"
        $DRY_RUN_CMD cp -r "$_pkg/Applications/GitWidget.app" "$_dest"
        $DRY_RUN_CMD chmod -R u+w "$_dest"

        # The binary ships unsigned (CODE_SIGNING_ALLOWED=NO in CI).
        # We must supply entitlements explicitly — --deep alone cannot assign
        # per-bundle entitlements, and omitting them drops entitlements entirely.
        # The extension must be sandboxed (pluginkit requirement) but the main
        # app must NOT be sandboxed — it reads ~/.config and makes network calls.
        _ext_ent=$(mktemp /tmp/git-widget-ext-ent.XXXX.plist)
        _app_ent=$(mktemp /tmp/git-widget-app-ent.XXXX.plist)
        cat > "$_ext_ent" <<'ENTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.maliciousgoose.git-widget.shared</string>
  </array>
</dict>
</plist>
ENTEOF
        cat > "$_app_ent" <<'ENTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.maliciousgoose.git-widget.shared</string>
  </array>
</dict>
</plist>
ENTEOF

        # Sign inside-out: framework first, then extension, then the app.
        $DRY_RUN_CMD /usr/bin/codesign --force \
          --sign "${cfg.signingIdentity}" \
          "$_dest/Contents/Frameworks/core.framework"
        $DRY_RUN_CMD /usr/bin/codesign --force \
          --sign "${cfg.signingIdentity}" \
          --entitlements "$_ext_ent" \
          "$_dest/Contents/PlugIns/extensionExtension.appex"
        $DRY_RUN_CMD /usr/bin/codesign --force \
          --sign "${cfg.signingIdentity}" \
          --entitlements "$_app_ent" \
          "$_dest"
        rm -f "$_ext_ent" "$_app_ent"

        if [ -z "''${DRY_RUN_CMD-}" ]; then
          mkdir -p "$_state"
          printf '%s' "$_pkg" > "$_record"
        fi
      fi
    '';

    # Start the app automatically on login
    launchd.agents.git-widget = {
      enable = true;
      config = {
        Label = "com.gitwidget.app";
        ProgramArguments = [ "${config.home.homeDirectory}/Applications/GitWidget.app/Contents/MacOS/GitWidget" ];
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "/tmp/git-widget.log";
        StandardErrorPath = "/tmp/git-widget-error.log";
      };
    };
  };
}
