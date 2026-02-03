# xcodecloud-cli

A command-line interface for [Xcode Cloud](https://developer.apple.com/xcode-cloud/) via the App Store Connect API.

Run `xcodecloud` with no arguments to launch interactive mode with arrow-key navigation, or use subcommands directly for scripting and automation.

## Build

Requires Swift 6.0+ and macOS 13+.

```
swift build -c release
```

The binary is at `.build/release/xcodecloud`. Copy it somewhere on your `$PATH`:

```
cp .build/release/xcodecloud /usr/local/bin/
```

## Authentication

Credentials are resolved in order:

1. Command-line flags (`--key-id`, `--issuer-id`, `--private-key-path`)
2. Environment variables (`XCODE_CLOUD_KEY_ID`, `XCODE_CLOUD_ISSUER_ID`, `XCODE_CLOUD_PRIVATE_KEY_PATH`)
3. Global config (`~/.xcodecloud/config.json`)
4. Project-local config (`.xcodecloud/config.json`)

Create a config file:

```json
{
  "keyId": "YOUR_KEY_ID",
  "issuerId": "YOUR_ISSUER_ID",
  "privateKeyPath": "/path/to/AuthKey.p8"
}
```

Or run `xcodecloud auth init` to set up credentials interactively.

### Getting an API Key

You need a **Team key** (not an Individual key) with CI access:

1. Go to [App Store Connect](https://appstoreconnect.apple.com/access/integrations/api) > Users and Access > Integrations > App Store Connect API
2. Under **Team Keys**, click "Generate API Key"
3. Select Admin, App Manager, or Developer role (all have CI access)
4. Download the `.p8` file — you can only download it once
5. Note the Key ID and Issuer ID shown on the page

## Usage

### Interactive mode

```
xcodecloud
```

Navigate with arrow keys through products, workflows, builds, and artifacts. Select with Enter, quit with `q` or Ctrl+C.

### Direct commands

```
# Check credentials
xcodecloud auth check

# List products
xcodecloud products list

# List workflows for a product
xcodecloud workflows list <product-id>

# Start a build
xcodecloud builds start <workflow-id>

# Get build details
xcodecloud builds get <build-id>

# List build errors
xcodecloud builds errors <build-id>

# List and download artifacts
xcodecloud artifacts list <build-id>
xcodecloud artifacts download <artifact-id>
```

Use `-o table` for formatted table output or `-o json` for JSON (default).

Run `xcodecloud help <subcommand>` for details on any command.

## License

[MIT](LICENSE)
