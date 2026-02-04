# xcodecloud-cli

A command-line interface for [Xcode Cloud](https://developer.apple.com/xcode-cloud/) via the App Store Connect API.

## Features

- **Interactive mode** — arrow-key navigation through products, workflows, builds, and artifacts
- **Direct commands** — scriptable CLI for automation and CI pipelines
- **Multiple output formats** — JSON (default), table, or CSV
- **Profile support** — manage multiple App Store Connect accounts
- **Zero dependencies** — pure Swift, no external libraries for terminal UI

## Commands

```
xcodecloud
├── (no args)              → Interactive mode (arrow-key navigation)
├── auth
│   ├── init               → Set up credentials interactively
│   ├── check              → Verify credentials are valid
│   ├── profiles           → List configured profiles
│   └── use <profile>      → Set the default profile
├── products
│   ├── list               → List all CI products
│   └── get <id>           → Get details for a CI product
├── workflows
│   ├── list <product-id>  → List workflows for a CI product
│   └── get <id>           → Get details for a workflow
├── builds
│   ├── list               → List build runs
│   ├── get <id>           → Get details for a build run
│   ├── start <workflow-id>→ Start a new build run
│   ├── watch <build-id>  → Watch a build until completion
│   ├── logs <build-id>   → List or download build logs
│   ├── actions <build-id> → List actions for a build run
│   ├── errors <build-id>  → Show errors, issues, and test failures
│   ├── issues <action-id> → List issues for a build action
│   ├── issue <id>         → Get details for a specific issue
│   ├── tests <build-id>   → Show test results for a build run
│   └── test-result <id>   → Get details for a specific test result
└── artifacts
    ├── list <action-id>   → List artifacts for a build action
    └── download <id>      → Download an artifact
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
# Set up credentials (interactive)
xcodecloud auth init

# Verify credentials work
xcodecloud auth check

# Launch interactive mode
xcodecloud
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

This prompts for your credentials and saves them to `~/.xcodecloud/config.json`.

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

**Option 4: Command-line flags**

```bash
xcodecloud --key-id ABC123DEF4 \
           --issuer-id 12345678-1234-1234-1234-123456789abc \
           --private-key-path ~/AuthKey_ABC123DEF4.p8 \
           products list
```

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

Interactive mode provides a guided flow:
- **Products** → select an app or framework
- **Workflows** → select a CI workflow
- **Builds** → view build history, start new builds
- **Artifacts** → download build outputs

### Commands

#### Products

```bash
# List all CI products (apps and frameworks)
xcodecloud products list

# List as table
xcodecloud products list -o table

# Get details for a specific product
xcodecloud products get <product-id>
```

#### Workflows

```bash
# List workflows for a product
xcodecloud workflows list <product-id>

# Get workflow details
xcodecloud workflows get <workflow-id>
```

#### Builds

```bash
# List recent builds across all workflows
xcodecloud builds list

# List builds for a specific workflow
xcodecloud builds list --workflow <workflow-id>

# Get build details
xcodecloud builds get <build-id>

# Start a new build
xcodecloud builds start <workflow-id>

# Start a build for a specific branch
xcodecloud builds start <workflow-id> --branch main

# Start a build for a specific tag
xcodecloud builds start <workflow-id> --tag v1.0.0

# Watch a build until completion (polls every 10s)
xcodecloud builds watch <build-id>

# Watch with faster polling
xcodecloud builds watch <build-id> --interval 5

# List build logs
xcodecloud builds logs <build-id>

# Download build logs
xcodecloud builds logs <build-id> --download

# Download logs to a specific directory
xcodecloud builds logs <build-id> --download --dir ./logs

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

# Download to a specific directory
xcodecloud artifacts download <artifact-id> --dir ~/Downloads
```

#### Auth

```bash
# Set up credentials interactively
xcodecloud auth init

# Verify credentials work
xcodecloud auth check

# List configured profiles
xcodecloud auth profiles

# Set default profile
xcodecloud auth use <profile-name>
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
| `--profile` | | Use a specific auth profile |
| `--help` | `-h` | Show help for any command |

## Examples

### Typical workflow

```bash
# 1. List your products
xcodecloud products list -o table

# 2. List workflows for a product (copy product ID from step 1)
xcodecloud workflows list abc123 -o table

# 3. Start a build (copy workflow ID from step 2)
xcodecloud builds start def456

# 4. Check build status (copy build ID from step 3)
xcodecloud builds get ghi789 -o table

# 5. If build failed, see what went wrong
xcodecloud builds errors ghi789
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

### "Credentials not found"

Run `xcodecloud auth init` to set up credentials, or check that your config file exists at `~/.xcodecloud/config.json`.

### "401 Unauthorized"

- Verify your Key ID and Issuer ID are correct
- Make sure you're using a **Team key**, not an Individual key
- Check that your API key has the correct role (Admin, App Manager, or Developer)
- Ensure your `.p8` file path is correct and the file is readable

### "No products found"

Your API key may not have access to Xcode Cloud. Verify that:
- Your app has Xcode Cloud enabled in App Store Connect
- Your API key role has CI access

### Interactive mode not working

Interactive mode requires a TTY. It won't work when:
- Output is piped (`xcodecloud | grep ...`)
- Running in a non-interactive shell
- Running in some CI environments

Use direct commands with `-o table` or `-o json` instead.

## License

[MIT](LICENSE)
