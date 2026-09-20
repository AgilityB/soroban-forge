# Development Guide

This guide covers the development workflow for Soroban Forge. All commands documented here are tested and work in the current repository.

## Prerequisites

### Rust and Toolchain

The project requires **stable Rust** and the `wasm32v1-none` target for Soroban contracts.

```bash
# Install or update Rust
rustup update stable

# Install required components
rustup component add rustfmt clippy

# Add WASM target required by soroban-sdk
rustup target add wasm32v1-none
```

### Soroban CLI (Optional)

For deployment and contract interaction:

```bash
cargo install soroban-cli
```

### soroban-sdk Version

The project uses soroban-sdk 27.x. See `rust-toolchain.toml` for the exact pinned version.

## Clone and Setup

```bash
# Clone the repository
git clone https://github.com/Meet-hybrid/soroban-forge.git
cd soroban-forge

# Verify workspace loads
cargo metadata --locked --no-deps --format-version 1 > /dev/null
```

## Build Commands

### Full Workspace Build

```bash
make build
# or: cargo build --workspace --all-targets
```

### Release Build (WASM Artifacts)

```bash
cargo build --release --target wasm32v1-none -p soroban-forge-escrow
# Builds: target/wasm32v1-none/release/soroban_forge_escrow.wasm
```

### Build All Contracts for Release

```bash
cargo build --locked --release --target wasm32v1-none \
  --package soroban-forge-escrow \
  --package soroban-forge-vesting \
  --package soroban-forge-multi-sig-wallet \
  --package soroban-forge-dao-governance \
  --package soroban-forge-subscription-payments \
  --package soroban-forge-marketplace-royalties
```

## Test Commands

### Full Test Suite

```bash
make test
# or: cargo test --workspace --all-targets --locked
```

### Test Individual Contract

```bash
# Escrow
cargo test --workspace --package soroban-forge-escrow

# Vesting
cargo test --workspace --package soroban-forge-vesting

# Multi-Sig Wallet
cargo test --workspace --package soroban-forge-multi-sig-wallet

# DAO Governance
cargo test --workspace --package soroban-forge-dao-governance

# Subscription Payments
cargo test --workspace --package soroban-forge-subscription-payments

# Marketplace Royalties
cargo test --workspace --package soroban-forge-marketplace-royalties
```

## Lint and Format

### Code Formatting

```bash
make format
# or: cargo fmt --all
```

### Format Check (CI)

```bash
make format-check
# or: cargo fmt --all -- --check
```

### Linting

```bash
make lint
# or: cargo clippy --workspace --all-targets -- -D warnings
```

### Security Audit

```bash
make audit
# or: cargo audit
```

## Documentation

### Generate Rust Documentation

```bash
make doc
# or: cargo doc --workspace --no-deps --locked --document-private-items
```

### Run Full Release Checks

```bash
make release
# Runs: format, lint, audit, test, build-release
```

## Repository Commands Reference

| Command | Purpose |
|---------|---------|
| `make build` | Build workspace |
| `make test` | Run all tests |
| `make format` | Format code |
| `make lint` | Run clippy |
| `make audit` | Check dependencies |
| `make doc` | Generate docs |
| `make clean` | Clean build artifacts |
| `make release` | Full pre-release checks |

## Contract Testing Notes

- Tests use Soroban SDK's `Env` test harness
- Mock authentication (`mock_all_auths`) for positive tests
- Integration tests use Stellar Asset Contract (SAC) fixtures
- Escrow includes property testing for conservation invariant

## CI Pipeline

The CI workflow (`.github/workflows/ci.yml`) runs:

1. **rustfmt** - Code formatting check
2. **clippy** - Linting with strict warnings
3. **build** - Full workspace build + docs
4. **test** - Test suite execution
5. **audit** - Dependency vulnerability scan
6. **wasm-size** - Contract size budget enforcement
7. **provenance** - Build reproducibility verification

## Common Issues

### WASM Build Fails

Ensure `wasm32v1-none` target is installed:
```bash
rustup target add wasm32v1-none
```

### Lock File Conflicts

Use `--locked` flag to ensure reproducible builds:
```bash
cargo build --locked
```

### Clippy Failures

The project uses `-D warnings` (fail on warnings). Fix issues reported by clippy or document intentional deviations.

## WASM Size Budget

Contracts have a maximum size of 150,000 bytes. This is enforced in CI.