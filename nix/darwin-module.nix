{ config, lib, pkgs, ... }:

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

    appPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Applications/app.app";
      description = "Path to the installed GitWidget .app bundle.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Write config to ~/.config/git-widget/config.toml
    home.file.".config/git-widget/config.toml".text = configContent;

    # Start the app automatically on login via a user LaunchAgent
    launchd.agents.git-widget = {
      enable = true;
      config = {
        Label = "com.gitwidget.app";
        ProgramArguments = [ "${cfg.appPath}/Contents/MacOS/app" ];
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "/tmp/git-widget.log";
        StandardErrorPath = "/tmp/git-widget-error.log";
      };
    };
  };
}
