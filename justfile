set dotenv-load

project  := "git-widget.xcodeproj"
scheme   := "app"
apps_dir := env_var_or_default("INSTALL_DIR", env_var("HOME") + "/Applications")

default:
    @just --list

# Build (Debug)
build: _check-xcode
    xcodebuild -project {{project}} -scheme {{scheme}} \
        -configuration Debug \
        -destination 'platform=macOS' \
        build | xcbeautify

# Build (Release)
build-release: _check-xcode
    xcodebuild -project {{project}} -scheme {{scheme}} \
        -configuration Release \
        -destination 'platform=macOS' \
        build | xcbeautify

# Build and copy to ~/Applications
install: build-release
    #!/usr/bin/env bash
    set -euo pipefail
    BUILD_DIR=$(xcodebuild -project {{project}} -scheme {{scheme}} \
        -configuration Release -destination 'platform=macOS' \
        -showBuildSettings 2>/dev/null | grep '^\s*BUILT_PRODUCTS_DIR' | awk '{print $3}')
    mkdir -p "{{apps_dir}}"
    cp -Rf "$BUILD_DIR/GitWidget.app" "{{apps_dir}}/"
    echo "Installed to {{apps_dir}}/GitWidget.app"

# Lint with SwiftLint
lint:
    swiftlint lint --strict app/ core/ extension/

# Auto-fix lint issues
lint-fix:
    swiftlint --fix app/ core/ extension/
    swiftformat app/ core/ extension/

# Format with SwiftFormat
format:
    swiftformat app/ core/ extension/

# Clean derived data
clean: _check-xcode
    xcodebuild -project {{project}} -scheme {{scheme}} clean | xcbeautify

# Open project in Xcode
open:
    open {{project}}

# Smoke-test a GraphQL query against GitHub (requires GH_TOKEN or gh CLI login)
test-graphql owner repo:
    #!/usr/bin/env bash
    set -euo pipefail
    TOKEN="${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}"
    if [ -z "$TOKEN" ]; then
        echo "Set GH_TOKEN or authenticate with: gh auth login"
        exit 1
    fi
    curl -s \
        -H "Authorization: bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -X POST https://api.github.com/graphql \
        -d "{\"query\": \"{ viewer { login } repository(owner: \\\"{{owner}}\\\", name: \\\"{{repo}}\\\") { name openGraphImageUrl } }\"}" \
        | jq .

_check-xcode:
    #!/usr/bin/env bash
    if ! xcodebuild -version &>/dev/null; then
        echo "ERROR: Xcode not found."
        echo "Install from the App Store, then run:"
        echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        echo "  sudo xcodebuild -license accept"
        exit 1
    fi
