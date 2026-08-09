# Contracts Overview

| Contract | Path | Status |
|----------|------|--------|
| Escrow | crates/escrow | Implemented · 16 tests |
| Vesting | crates/vesting | Implemented · 21 tests |
| Multi-Sig Wallet | crates/multi-sig-wallet | Implemented · 18 tests |
| DAO Governance | crates/dao-governance | Implemented · 16 tests |
| Subscription Payments | crates/subscription-payments | Implemented · 12 tests |
| Marketplace Royalties | crates/marketplace-royalties | Implemented · 10 tests |

## Adding a New Contract

1. Add a new crate under `crates/`.
2. Register it in workspace `Cargo.toml`.
3. Add a document in `docs/contracts/`.
4. Add CI checks.
5. Tag a release.
