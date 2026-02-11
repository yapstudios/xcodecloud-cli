# xcodecloud-cli

[![CI](https://github.com/yapstudios/xcodecloud-cli/actions/workflows/ci.yml/badge.svg)](https://github.com/yapstudios/xcodecloud-cli/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138.svg)](https://swift.org)
[![macOS 12+](https://img.shields.io/badge/macOS-12%2B-000000.svg)](https://developer.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Homebrew](https://img.shields.io/badge/Homebrew-yapstudios%2Ftap-FBB040.svg)](https://github.com/yapstudios/homebrew-tap)

A command-line interface for [Xcode Cloud](https://developer.apple.com/xcode-cloud/) via the App Store Connect API.

## Features

- **Interactive mode** — arrow-key navigation through products, workflows, builds, and artifacts
- **Direct commands** — scriptable CLI for automation and CI pipelines
- **Multiple output formats** — JSON (default), table, or CSV
- **Profile support** — manage multiple App Store Connect accounts, switch profiles in interactive mode
- **Build notifications** — macOS notification when a watched build completes
- **Zero dependencies** — pure Swift, no external libraries for terminal UI

## Commands

```
xcodecloud
├── (no args)                → Interactive mode (arrow-key navigation)
├── auth
│   ├── init                 → Set up credentials interactively
│   ├── check                → Verify credentials are valid
│   ├── profiles             → List configured profiles
│   └── use <profile>        → Set the default profile
├── products
│   ├── list                 → List all CI products
│   └── get <id>             → Get details for a CI product
├── workflows
│   ├── list <product-id>    → List workflows for a CI product
│   └── get <id>             → Get details for a workflow
├── builds
│   ├── list --workflow <id> → List build runs for a workflow
│   ├── find <commit-sha>    → Find a build by commit SHA
│   ├── running              → Show all running builds
│   ├── get <id>             → Get details for a build run
│   ├── start <workflow-id>  → Start a new build run
│   ├── watch <build-id>     → Watch a build until completion
│   ├── logs <build-id>      → List or download build logs
│   ├── actions <build-id>   → List actions for a build run
│   ├── errors <build-id>    → Show errors, issues, and test failures
│   ├── issues <action-id>   → List issues for a build action
│   ├── issue <id>           → Get details for a specific issue
│   ├── tests <build-id>     → Show test results for a build run
│   └── test-result <id>     → Get details for a specific test result
└── artifacts
    ├── list <action-id>     → List artifacts for a build action
    └── download <id>        → Download an artifact
```

## Installation

### Using Homebrew (recommended)

```bash
brew install yapstudios/tap/xcodecloud
```

To update later:

```bash
brew upgrade xcodecloud
```

This builds from source and automatically installs shell completions for zsh, bash, and fish.

### Using Mint

[Mint](https://github.com/yonaskolb/Mint) is a package manager for Swift CLI tools.

```bash
brew install mint
mint install yapstudios/xcodecloud-cli
```

Make sure `~/.mint/bin` is in your PATH:

```bash
echo 'export PATH="$HOME/.mint/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

To update later:

```bash
mint install yapstudios/xcodecloud-cli
```

### Building from source

Requires Xcode 16+ (Swift 6) to build. Runs on macOS 12 (Monterey) or later.

```bash
git clone https://github.com/yapstudios/xcodecloud-cli.git
cd xcodecloud-cli
swift build -c release
cp .build/release/xcodecloud /usr/local/bin/
```

### Shell completions

Enable tab-completion for all commands and flags:

**Zsh (default on macOS):**

```bash
xcodecloud --generate-completion-script zsh > ~/.zsh/completions/_xcodecloud
```

Then add this to your `~/.zshrc` (if not already present):

```bash
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```

**Bash:**

```bash
xcodecloud --generate-completion-script bash > ~/.bash_completions/xcodecloud.bash
echo 'source ~/.bash_completions/xcodecloud.bash' >> ~/.bash_profile
```

**Fish:**

```bash
xcodecloud --generate-completion-script fish > ~/.config/fish/completions/xcodecloud.fish
```

## Quick Start

```bash
# Launch interactive mode — prompts to set up credentials on first run
xcodecloud

# Or set up credentials directly
xcodecloud auth init
```

## Authentication

### Getting an API Key

You need an **App Store Connect API Team key** (not an Individual key):

1. Go to [App Store Connect](https://appstoreconnect.apple.com/access/integrations/api)
2. Navigate to **Users and Access > Integrations > App Store Connect API**
3. Under **Team Keys**, click "Generate API Key"
4. Select **Admin**, **App Manager**, or **Developer** role (all have CI access)
5. Download the `.p8` file — you can only download it once!
6. Note the **Key ID** (10 characters, e.g., `ABC123DEF4`) and **Issuer ID** (UUID format)

### Setting up credentials

**Option 1: Interactive setup (recommended)**

```bash
xcodecloud auth init
```

This prompts for your credentials, saves them to `~/.xcodecloud/config.json`, and verifies they work.

**Option 2: Manual config file**

Create `~/.xcodecloud/config.json`:

```json
{
  "keyId": "ABC123DEF4",
  "issuerId": "12345678-1234-1234-1234-123456789abc",
  "privateKeyPath": "~/AuthKey_ABC123DEF4.p8"
}
```

**Option 3: Environment variables**

```bash
export XCODE_CLOUD_KEY_ID="ABC123DEF4"
export XCODE_CLOUD_ISSUER_ID="12345678-1234-1234-1234-123456789abc"
export XCODE_CLOUD_PRIVATE_KEY_PATH="~/AuthKey_ABC123DEF4.p8"
```

Or pass the key content directly (useful in CI/CD where the key is stored as a secret):

```bash
export XCODE_CLOUD_PRIVATE_KEY="$(base64 < ~/AuthKey_ABC123DEF4.p8)"
```

**Option 4: Command-line flags**

```bash
xcodecloud --key-id ABC123DEF4 \
           --issuer-id 12345678-1234-1234-1234-123456789abc \
           --private-key-path ~/AuthKey_ABC123DEF4.p8 \
           products list
```

Use `--private-key` instead of `--private-key-path` to pass the key content directly (base64-encoded).

### Credential resolution order

Credentials are resolved in this order (first found wins):

1. Command-line flags
2. Environment variables
3. Project-local config (`.xcodecloud/config.json` in current directory)
4. Global config (`~/.xcodecloud/config.json`)

### Multiple profiles

You can configure multiple profiles for different teams or accounts:

```bash
# Create a profile named "work"
xcodecloud auth init --profile work

# Create a profile named "personal"
xcodecloud auth init --profile personal

# Use a specific profile
xcodecloud --profile work products list

# Set default profile
xcodecloud auth use work

# List all profiles
xcodecloud auth profiles
```

## Usage

### Interactive mode

```bash
xcodecloud
```

Navigate with arrow keys, select with Enter, go back or quit with `q`.

If no credentials are configured, interactive mode will offer to set them up on first launch.

Interactive mode provides a guided flow:
- **Products** → select an app or framework
- **Workflows** → select a CI workflow
- **Builds** → view build history, start new builds, watch with live status
- **Artifacts** → download build outputs
- **Auth** → switch profiles, check credentials, add new profiles

When multiple profiles are configured, the active profile name is shown on the prompt.

### Commands

#### Products

```bash
# List all CI products (apps and frameworks)
xcodecloud products list -o table

# Filter by name (case-insensitive substring match)
xcodecloud products list --name MyApp

# Filter by type
xcodecloud products list --type APP

# Fetch all pages of results
xcodecloud products list --all

# Get details for a specific product
xcodecloud products get <product-id>
```

#### Workflows

```bash
# List workflows for a product
xcodecloud workflows list <product-id>

# Filter by name
xcodecloud workflows list <product-id> --name Release

# Show only enabled workflows
xcodecloud workflows list <product-id> --enabled

# Fetch all pages of results
xcodecloud workflows list <product-id> --all

# Get workflow details
xcodecloud workflows get <workflow-id>
```

#### Builds

```bash
# List builds for a workflow (--workflow or --workflow-name is required)
xcodecloud builds list --workflow <workflow-id>

# List builds by workflow name (instead of ID)
xcodecloud builds list --product <product-id> --workflow-name "Release"

# Filter by status (SUCCEEDED, FAILED, ERRORED, CANCELED, SKIPPED)
xcodecloud builds list --workflow <workflow-id> --status failed

# Filter by commit SHA
xcodecloud builds list --workflow <workflow-id> --commit abc1234

# Show only running builds
xcodecloud builds list --workflow <workflow-id> --running

# Find a build by commit SHA (searches across all products and workflows)
xcodecloud builds find abc1234

# Narrow the search to a specific product
xcodecloud builds find abc1234 --product <product-id>

# Show all running builds across all products
xcodecloud builds running

# Show running builds for a specific product
xcodecloud builds running --product <product-id>

# Show running builds across all configured profiles
xcodecloud builds running --all-profiles

# Get build details
xcodecloud builds get <build-id>

# Start a new build
xcodecloud builds start <workflow-id>

# Start a build for a specific branch
xcodecloud builds start <workflow-id> --branch main

# Start a build for a specific tag
xcodecloud builds start <workflow-id> --tag v1.0.0

# Watch a build until completion (polls every 10s, notifies on completion)
xcodecloud builds watch <build-id>

# Watch with faster polling
xcodecloud builds watch <build-id> --interval 5

# Watch without macOS notification
xcodecloud builds watch <build-id> --no-notify

# List build logs
xcodecloud builds logs <build-id>

# Download build logs
xcodecloud builds logs <build-id> --download

# Download logs to a specific directory (-d is short for --dir)
xcodecloud builds logs <build-id> --download -d ./logs

# Show build errors (compiler issues + test failures)
xcodecloud builds errors <build-id>

# Show test results
xcodecloud builds tests <build-id>

# Show only test failures
xcodecloud builds tests <build-id> --failures
```

#### Artifacts

Artifacts are attached to build actions (e.g., "Build", "Test", "Archive").

```bash
# List actions for a build (to get action IDs)
xcodecloud builds actions <build-id>

# List artifacts for a build action
xcodecloud artifacts list <build-action-id>

# Download an artifact
xcodecloud artifacts download <artifact-id>

# Download to a specific directory (-d is short for --dir)
xcodecloud artifacts download <artifact-id> -d ~/Downloads
```

#### Auth

```bash
# Set up credentials interactively (auto-verifies after saving)
xcodecloud auth init

# Set up a named profile
xcodecloud auth init --profile work

# Overwrite an existing profile
xcodecloud auth init --profile work --force

# Re-verify credentials work
xcodecloud auth check

# List configured profiles
xcodecloud auth profiles

# Set default profile (global)
xcodecloud auth use <profile-name>

# Set default profile (local project config only)
xcodecloud auth use <profile-name> --local
```

### Output formats

All commands support multiple output formats:

```bash
# JSON (default) — best for scripting
xcodecloud products list -o json

# Pretty-printed JSON
xcodecloud products list -o json --pretty

# Table — best for human reading
xcodecloud products list -o table

# CSV — best for spreadsheets
xcodecloud products list -o csv
```

### Common flags

| Flag | Short | Description |
|------|-------|-------------|
| `--output` | `-o` | Output format: `json`, `table`, `csv` |
| `--pretty` | | Pretty-print JSON output |
| `--verbose` | `-v` | Show debug information |
| `--quiet` | `-q` | Suppress non-essential output |
| `--no-color` | | Disable colored output |
| `--profile` | | Use a specific auth profile |
| `--limit <n>` | | Maximum number of results per page (default: 25, for list commands) |
| `--all` | | Fetch all pages of results (for list commands) |
| `--no-notify` | | Disable macOS notification (for `builds watch`) |
| `--help` | `-h` | Show help for any command |

### Filtering

List commands support client-side filtering. Filters are applied after fetching results from the API.

| Command | Flag | Description |
|---------|------|-------------|
| `products list` | `--name <text>` | Filter by name (case-insensitive substring match) |
| `products list` | `--type <type>` | Filter by product type: `APP`, `FRAMEWORK` |
| `workflows list` | `--name <text>` | Filter by name (case-insensitive substring match) |
| `workflows list` | `--enabled` | Show only enabled workflows |
| `workflows list` | `--disabled` | Show only disabled workflows |
| `builds list` | `--workflow <id>` | Workflow to list builds for (required unless using `--workflow-name`) |
| `builds list` | `--workflow-name <name>` | Look up workflow by name (requires `--product`) |
| `builds list` | `--product <id>` | Product ID (required with `--workflow-name`) |
| `builds list` | `--status <status>` | Filter by completion status: `SUCCEEDED`, `FAILED`, `ERRORED`, `CANCELED`, `SKIPPED` |
| `builds list` | `--running` | Show only builds currently in progress |
| `builds list` | `--commit <sha>` | Filter by commit SHA prefix |
| `builds running` | `--product <id>` | Narrow to a specific product |
| `builds running` | `--all-profiles` | Check all configured profiles |

Filters can be combined:

```bash
xcodecloud builds list --workflow <id> --status failed
xcodecloud builds list --workflow <id> --commit abc1234
xcodecloud products list --name MyApp --type APP
```

## Examples

### Typical workflow

```bash
# 1. List your products
xcodecloud products list -o table

# 2. List workflows for a product (copy product ID from step 1)
xcodecloud workflows list abc123 -o table

# 3. List builds for a workflow (copy workflow ID from step 2)
xcodecloud builds list --workflow def456 -o table

# 4. Start a build
xcodecloud builds start def456

# 5. Check build status (copy build ID from step 4)
xcodecloud builds get ghi789 -o table

# 6. If build failed, see what went wrong
xcodecloud builds errors ghi789
```

### Quick build lookup

If you know the commit SHA, skip the product/workflow/build chain entirely:

```bash
# Find the build for a specific commit and see errors if it failed
xcodecloud builds find abc1234
```

### Scripting examples

**Get the latest build status:**

```bash
xcodecloud builds list --workflow <workflow-id> --limit 1 -o json | jq '.data[0].attributes'
```

**Start a build and watch until completion:**

```bash
BUILD_ID=$(xcodecloud builds start <workflow-id> -o json | jq -r '.data.id')
xcodecloud builds watch $BUILD_ID
```

**Download all artifacts from a build:**

```bash
# Get all action IDs
ACTIONS=$(xcodecloud builds actions <build-id> -o json | jq -r '.data[].id')

for ACTION_ID in $ACTIONS; do
  # Get artifact IDs for this action
  ARTIFACTS=$(xcodecloud artifacts list $ACTION_ID -o json | jq -r '.data[].id')

  for ARTIFACT_ID in $ARTIFACTS; do
    xcodecloud artifacts download $ARTIFACT_ID --dir ./artifacts
  done
done
```

## Troubleshooting

### "Missing credentials: No credentials configured"

Run `xcodecloud auth init` to set up credentials interactively. In interactive mode (`xcodecloud` with no arguments), you'll be prompted to set up credentials automatically.

You can also check that your config file exists at `~/.xcodecloud/config.json`.

### "Unauthorized: Check your API credentials"

- Verify your Key ID and Issuer ID are correct
- Make sure you're using a **Team key**, not an Individual key
- Check that your API key has the correct role (Admin, App Manager, or Developer)
- Ensure your `.p8` file path is correct and the file is readable

### "Forbidden" when listing builds

The App Store Connect API does not support listing builds across all workflows. Use `--workflow` to scope the request:

```bash
xcodecloud builds list --workflow <workflow-id>
```

To find workflow IDs, run `xcodecloud workflows list <product-id>`.

### "No products found"

Your API key may not have access to Xcode Cloud. Verify that:
- Your app has Xcode Cloud enabled in App Store Connect
- Your API key role has CI access

### Notifications not appearing

`builds watch` sends a macOS notification when the build completes. Notifications are enabled by default and use `osascript`, which routes through **Script Editor** in Notification Center.

If notifications don't appear:
- Check that **Do Not Disturb** / **Focus** mode is not active
- Open **System Settings > Notifications > Script Editor** and ensure notifications are allowed
- Make sure your terminal app has notification permissions

To disable notifications, use `--no-notify`:

```bash
xcodecloud builds watch <build-id> --no-notify
```

### Interactive mode not working

Interactive mode requires a TTY. It won't work when:
- Output is piped (`xcodecloud | grep ...`)
- Running in a non-interactive shell
- Running in some CI environments

Use direct commands with `-o table` or `-o json` instead.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes by version.

## License

[MIT](LICENSE)
