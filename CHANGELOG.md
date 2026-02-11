# Changelog

## 1.2.3

- Add `builds running` command to show in-progress builds with `--product` and `--all-profiles` flags
- Add "Running Builds" option to interactive mode

## 1.2.2

- Align command tree arrows in README

## 1.2.1

- Add `builds find <sha>` to search across all products/workflows for a build matching a commit SHA
- Add `builds list --commit <sha>` to filter by commit SHA prefix
- Add `builds list --workflow-name <name>` to resolve workflow by name instead of ID

## 1.2.0

- Add integration tests and credential resolver unit tests
- Improve error message when `builds list` is called without `--workflow`

## 1.1.1

- Add macOS notification on `builds watch` completion via osascript
- Add `--no-notify` flag to opt out of notifications

## 1.1.0

- Add profile switching in interactive mode
- Improve first-time setup experience with clearer error messages
- Auto-verify credentials after `auth init`
- Add documentation URLs to help and interactive mode

## 1.0.9

- Fix interactive mode showing wrong version

## 1.0.8

- Add filtering flags to list commands: `--name`, `--type`, `--status`, `--running`, `--enabled`, `--disabled`

## 1.0.7

- Add `builds logs` command to list and download build log bundles
- Add actions drill-down in interactive mode with issues and test results
- Add pagination support with `--all` flag and interactive "Load more"
- Fix cursor position after "Load more" in interactive mode

## 1.0.6

- Sort builds by newest first in API requests
- Add ESC key as back navigation in interactive mode

## 1.0.5

- Add `builds watch` command with live status updates and elapsed time
- Show bundle ID for products, sorted alphabetically
- Add Homebrew installation instructions

## 1.0.4

- Add shell completion instructions

## 1.0.3

- Ctrl+C exits immediately, q goes back one menu

## 1.0.2

- Add command tree to README
- Add config file format to auth help

## 1.0.1

- Fix Mint install instructions

## 1.0.0

- Initial release
- Multi-source authentication (CLI flags, env vars, config files)
- Profile support for multiple App Store Connect accounts
- Commands: auth, products, workflows, builds, artifacts
- Output formats: JSON (default), table, CSV
- Interactive mode with arrow-key navigation
- Build error and test result reporting
- Comprehensive test suite and CI workflow
