# git-widget

A macOS 26 (Tahoe) menu-bar app and desktop widget that shows your GitHub pull requests, grouped by repository, with review status, CI status, and comment counts.

![Widget showing PRs grouped by org/repo with status icons](docs/screenshot.png)

## Features

- PRs grouped by `owner/repo` with review decision, CI status, Copilot review indicator, and resolved/total thread count
- Supports draft and open PRs
- Per-repository filter modes: show all, only yours, only assigned to you (directly or via a team)
- Desktop notifications for new PRs, assignments, review requests, and CI failures
- All GitHub data fetched in a single batched GraphQL request
- Configurable poll interval (default 15 min)
- Click any PR row to open it in your browser

---

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26+ (from the App Store) for building
- An [Apple Developer account](https://developer.apple.com) (free tier works) — required for the App Group entitlement that lets the menu-bar app share data with the widget
- A GitHub [personal access token](https://github.com/settings/tokens) with **`repo`** and **`read:org`** scopes

---

## Installation

### From a pre-built release (no Xcode, no Nix)

**Prerequisites:** Xcode Command Line Tools (`xcode-select --install`) and a free [Apple Developer account](https://developer.apple.com) — required so the menu-bar app and widget extension can share data via a signed App Group.

**1. Download and extract**

Download `GitWidget.tar.gz` from the [latest release](../../releases/latest) and extract it to `~/Applications/`:

```sh
mkdir -p ~/Applications
tar -xzf GitWidget.tar.gz -C ~/Applications/
```

**2. Find your signing identity**

```sh
security find-identity -v -p codesigning
```

Copy the identity string you want to use, e.g. `Apple Development: Your Name (TEAMID)`.

**3. Sign the app**

The release binary is unsigned. You must sign it with your own certificate, providing explicit entitlements for each bundle component:

```sh
# Extension entitlements (sandboxed — required by WidgetKit)
cat > /tmp/gw-ext-ent.plist << 'EOF'
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
EOF

# App entitlements (not sandboxed — needs file system and network access)
cat > /tmp/gw-app-ent.plist << 'EOF'
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
EOF

IDENTITY="Apple Development"  # replace with your identity string from step 2

# Sign inside-out: framework → extension → app
codesign --force --sign "$IDENTITY" \
  ~/Applications/GitWidget.app/Contents/Frameworks/core.framework
codesign --force --sign "$IDENTITY" --entitlements /tmp/gw-ext-ent.plist \
  ~/Applications/GitWidget.app/Contents/PlugIns/extensionExtension.appex
codesign --force --sign "$IDENTITY" --entitlements /tmp/gw-app-ent.plist \
  ~/Applications/GitWidget.app
```

**4. Create your config**

```sh
mkdir -p ~/.config/git-widget
cp /path/to/config.example.toml ~/.config/git-widget/config.toml
# Edit with your token and repositories — see the Configuration section below
```

**5. Launch**

```sh
open ~/Applications/GitWidget.app
```

The app lives in the menu bar (no Dock icon). To start it automatically at login, add it in *System Settings → General → Login Items*.

**6. Add the widget to your desktop**

Right-click the desktop → *Edit Widgets* → search for "GitHub PRs" → drag to the desktop.

---

### Build from source (no Nix)

**1. Clone and open the project**

```sh
git clone https://github.com/albe2669/git-widget
cd git-widget
open git-widget.xcodeproj
```

**2. Set your development team**

In Xcode, select each target (`core`, `app`, `extensionExtension`) → *Signing & Capabilities* → set *Team* to your Apple Developer account. Xcode will handle provisioning automatically.

**3. Build and install**

```sh
just build-release
just install
# or manually: just install
```

This copies `GitWidget.app` to `~/Applications/`. Launch it from there — the app lives in the menu bar (no Dock icon).

**4. Create your config**

```sh
mkdir -p ~/.config/git-widget
cp config.example.toml ~/.config/git-widget/config.toml
# Edit the file with your token and repositories
```

**5. Add the widget to your desktop**

Right-click the desktop → *Edit Widgets* → search for "GitHub PRs" → drag to the desktop.

---

### With Nix (home-manager)

The flake exports a home-manager module that:
- downloads the pre-built `GitWidget.app` from GitHub Releases via Nix (no local Xcode needed)
- signs it locally with your development certificate (required for App Groups)
- writes `~/.config/git-widget/config.toml`
- installs a LaunchAgent to start the app at login

The binary is content-addressed in the Nix store — reinstalls only happen when the version changes.

**1. Add the flake input**

```nix
# flake.nix
inputs = {
  git-widget.url = "github:albe2669/git-widget";
};
```

**2. Import the module**

```nix
# home.nix or equivalent
{ inputs, ... }: {
  imports = [ inputs.git-widget.homeManagerModules.default ];
}
```

**3. Configure**

```nix
programs.git-widget = {
  enable = true;

  # Code signing identity from your login Keychain.
  # App Groups (required for the widget to display data) need a real identity.
  # Run: security find-identity -v -p codesigning
  signingIdentity = "Apple Development";  # or "Apple Development: Name (TEAMID)"

  github = {
    # Use tokenFile for secrets (recommended with sops-nix):
    tokenFile = config.sops.secrets.github-token.path;
    # Or plain token (stored in the Nix store — not recommended for secrets):
    # token = "ghp_...";
    updateInterval = 900;
  };

  repositories = [
    {
      owner = "myorg";
      name = "backend";
      filter = [ "opened" "assigned" ];  # union: PRs you opened OR are assigned to
      notifications = {
        newPR = true;
        assigned = true;
        reviewRequested = true;
        ciFailed = false;
      };
    }
    {
      owner = "myorg";
      name = "agents-service";
      filter = [ "assigned-group" ];
      assignedGroup = "agents";
      notifications = {
        newPR = false;
        assigned = true;
        reviewRequested = true;
        ciFailed = true;
      };
    }
  ];
};
```

**4. Apply**

```sh
home-manager switch --flake .
```

`home-manager switch` downloads the pre-built binary from the pinned GitHub release, copies it to `~/Applications/GitWidget.app`, signs it with your certificate, writes the config, and registers the LaunchAgent.

**Signing requirement**

App Groups (used to share data between the menu-bar app and the widget extension) require a real code signing identity. Run `security find-identity -v -p codesigning` to list available identities and pick the right one for `signingIdentity`.

---

## Configuration

The config file is TOML, read from `~/.config/git-widget/config.toml` (or `/etc/git-widget/config.toml` as a fallback).

### Full example

```toml
[github]
# Either 'token' or 'token_file' (token_file takes precedence).
# token_file is recommended when using a secret manager like sops-nix.
token_file = "/run/secrets/github-token"
# token = "ghp_YOUR_TOKEN"

# Optional: override the authenticated username.
# Defaults to the account that owns the token.
# username = "myusername"

# Poll interval in seconds. The WidgetKit refresh budget is ~40–70/day,
# so values below 900 have diminishing returns for the widget display.
# The background app polls at this interval regardless.
update_interval = 900

# ── Repositories ──────────────────────────────────────────────────────────────

[[repositories]]
owner = "myorg"
name = "backend"
filter = "assigned"          # see filter options below

  [repositories.notifications]
  new_pr = true              # fire when any new PR is opened
  assigned = true            # fire when you are assigned / review requested
  review_requested = true    # fire when review is explicitly requested from you
  ci_failed = false          # fire when CI changes to failure

[[repositories]]
owner = "myorg"
name = "agents-service"
filter = "assigned-group"
assigned_group = "agents"    # required when filter = "assigned-group"

  [repositories.notifications]
  new_pr = false
  assigned = true
  review_requested = true
  ci_failed = true
```

### Filter options

`filter` accepts a single mode or a list of modes. When multiple modes are given, their results are **unioned** — a PR matching any mode is included.

```toml
filter = "assigned"                      # single mode
filter = ["opened", "assigned"]          # union: PRs you opened OR are assigned to
filter = ["assigned-direct", "assigned-group"]
```

| Mode | Shows |
|---|---|
| `all` | All open PRs |
| `opened` | PRs you authored |
| `assigned` | PRs where you are an assignee **or** review was requested from you |
| `assigned-direct` | PRs where review was explicitly requested from you (not via a team) |
| `assigned-group` | PRs where review was requested from the named team (`assigned_group`) |
| `none` | Nothing — suppress this repo (no-op when combined with other modes) |

### Token permissions

The token needs:
- `repo` — to read pull requests and their status
- `read:org` — to see team membership (required for `assigned-group` filter)

Create one at <https://github.com/settings/tokens>.

### Token from a file (sops-nix)

```toml
token_file = "/run/secrets/github-token"
```

The file should contain only the token, with an optional trailing newline. This is the recommended approach when using [sops-nix](https://github.com/Mic92/sops-nix):

```nix
sops.secrets.github-token = {};

programs.git-widget.github.tokenFile = config.sops.secrets.github-token.path;
```

---

## Releasing

Releasing is fully automated via GitHub Actions:

```sh
git tag v1.0.0
git push origin v1.0.0
```

The [release workflow](.github/workflows/release.yml) will:
1. Build an unsigned `GitWidget.app` (arm64) on a `macos-15` runner
2. Package it as `GitWidget.tar.gz` and create a GitHub Release
3. Compute the Nix SRI hash and commit an updated `flake.nix` back to `main`

After the workflow completes, users on the home-manager module get the new version automatically the next time they run `nix flake update && home-manager switch`.

You can also trigger a release manually from the [Actions tab](../../actions/workflows/release.yml) without creating a tag.

---

## Development

### Environment

The Nix dev shell provides SwiftLint, SwiftFormat, xcbeautify, jq, and just:

```sh
devenv shell
```

Xcode (system installation) provides the Swift toolchain — devenv does not manage it.

### Common commands

```sh
just open          # open git-widget.xcodeproj in Xcode
just build         # Debug build
just build-release # Release build
just install       # Release build + copy to ~/Applications/
just lint          # SwiftLint (strict)
just lint-fix      # auto-fix lint + run SwiftFormat
just format        # SwiftFormat only
just clean         # clean derived data
just test-graphql myorg myrepo  # smoke-test a GraphQL query against GitHub
```

### Project structure

```
git-widget/
├── git-widget.xcodeproj/
├── app/                    # App target — menu-bar app
│   ├── appApp.swift        # @main, MenuBarExtra
│   ├── AppDelegate.swift   # notification permissions, start poller
│   ├── BackgroundPoller.swift  # timer loop: fetch → filter → save → reload widget
│   ├── NotificationManager.swift
│   └── MenuBarView.swift
├── core/                   # Framework target — shared by app and extension
│   ├── Models.swift        # PRData, WidgetSnapshot, AppConfig, etc.
│   ├── Config.swift        # TOML parser, ConfigLoader
│   ├── AppGroupStorage.swift  # shared JSON via App Group
│   └── GitHubGraphQL.swift    # batched GraphQL client + PRFilter
├── extension/              # Widget extension target
│   ├── extensionBundle.swift  # @main WidgetBundle
│   ├── PRTimelineProvider.swift
│   └── extension.swift     # GitPRWidget + all SwiftUI views
├── nix/
│   └── darwin-module.nix   # nix-darwin module
├── flake.nix
├── devenv.nix
├── justfile
└── config.example.toml
```

### Architecture

```
app (menu-bar, no sandbox)
 └─ BackgroundPoller ──→ GitHub GraphQL API
         │
         ▼
   App Group container        ←── extensionExtension (sandboxed)
   widget-snapshot.json             PRTimelineProvider reads this
         │
         └── WidgetCenter.reloadAllTimelines()
```

The app fetches, filters, and caches data; the extension only reads and renders. There is no network access in the extension.

### Signing

1. Open `git-widget.xcodeproj` in Xcode
2. Select each target (`core`, `app`, `extensionExtension`) in the sidebar
3. *Signing & Capabilities* → set *Team* to your Apple Developer account
4. Xcode will automatically create provisioning profiles and register the App Group

The App Group (`group.maliciousgoose.git-widget.shared`) is what allows the app and the widget to share the cached snapshot. Without valid signing, `AppGroupStorage` will return `nil` and the widget will show the placeholder view.

### Concurrency notes

- The `app` target has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all app-target types are implicitly `@MainActor`
- `core` types are `Sendable` and actor-agnostic
- `GitHubGraphQLClient` is `@unchecked Sendable` (URLSession is thread-safe, client is stateless per-request)
- `WidgetCenter.shared.reloadAllTimelines()` is safe to call from any context

---

## Troubleshooting

**Widget shows "Waiting for data…"**
The app hasn't written a snapshot yet. Make sure `GitWidget.app` is running (check the menu bar for the arrow icon). Check `/tmp/git-widget.log` for errors.

**App Group container is unavailable**
Signing is not set up correctly. Open Xcode → set your development team on all three targets → rebuild.

**"Config not found" in log**
Create `~/.config/git-widget/config.toml`. See `config.example.toml` for the format.

**Token file is empty**
If using `token_file`, ensure the file exists and contains the token before the app starts. With sops-nix, the secret is decrypted at login — make sure the launchd agent starts after decryption completes (add a `RunAfterLoad` dependency if needed).

**No PRs shown with `assigned-group`**
The `assigned_group` value is matched against the team's **name** (case-insensitive) from GitHub's `requestedReviewers` field. Check the exact team name in your org's settings.
