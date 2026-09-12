# GrantFox Application — Soroban Forge

> Application narrative for the GrantFox campaign, drawn from
> [RESUBMISSION.md](RESUBMISSION.md) and the live testnet proof. Written to
> be pasted into the application form or linked directly.

## One-liner

**Soroban Forge** is an open-source foundations library for Stellar payments:
a deployed, receipt-verified three-party escrow primitive holding real
SEP-41 tokens, with five more payment-contract foundations (vesting, multi-sig,
DAO governance, subscriptions, royalties) scoped behind it.

## What is proven today (not promised)

The escrow contract is **live on Stellar testnet** with a public receipt
round. Every claim below has an on-chain artifact or a repository test
behind it — the README "proof at a glance" table links them all:
https://github.com/Meet-hybrid/soroban-forge#proof-at-a-glance

| Claim | Evidence |
|---|---|
| Contract deployed and verified | Escrow `CC227UDF6WBLRTOKKVRIJN7BGSBK67ZGV6IDARJ2AMATGSQ7UZNBZHSB`, WASM sha256 `ccbb6603…e48b9`, 18,054 bytes |
| Real token movement | SEP-41 transfers buyer → contract → seller visible in the SAC `transfer` events of round 1 ([create tx](https://stellar.expert/explorer/testnet/tx/817950c8ad95ecad9636783e5e8e8b8e515f94e3364b63c2c02328ff3b675bb9)) |
| Arbiter dispute flow works | Round 2: buyer disputed, arbiter resolved for seller. Round 3: seller disputed, arbiter refunded buyer |
| Funds conservation on a live network | After 3 rounds: buyer 500 + seller 1000 = 1500 minted; contract holds 0 — matching the in-repo property test (`deposited == paid out` on every terminal path) |
| On-chain observability | 7 lifecycle events (`EscrowCreated`…`Cancelled`) with the escrow id as topic, publishing on testnet |
| Failure-mode discipline | A missing seller trustline surfaced as the typed `TokenTransferFailed` with root cause in diagnostic events — the documented error-bucketing behavior, demonstrated live |
| Reproducibility | `bash scripts/demo-testnet.sh` reruns the full round idempotently |
| Randomized invariant testing | proptest suite over the escrow: funds conservation across random terminal paths, tamper-resilient pool conservation, fund safety over arbitrary call sequences |
| Engineering gates | 107/107 tests, clippy `-D warnings`, rustfmt, cargo audit, WASM size budget enforced in CI |

## What changed since the last application

The previous application proposed six contracts whose entrypoints mostly
tracked state without settling anything, on an SDK two major versions
behind. Reviewer-visible gaps and their resolutions:

1. **No token settlement** → escrow now custodies and moves real SEP-41
   tokens with transfer-before-state ordering (a failed transfer can
   never corrupt accounting).
2. **Outdated stack** → soroban-sdk **27.0.6** on **stable Rust**, building
   for `wasm32v1-none`.
3. **Unreachable flagship features** → the arbiter is live: `dispute` /
   `resolve` are implemented, tested, and exercised on testnet.
4. **No honesty artifact** → [FEATURE-STATUS.md](FEATURE-STATUS.md) labels
   every entrypoint across all six contracts;
   [KNOWN-LIMITATIONS.md](KNOWN-LIMITATIONS.md) states what does not work
   yet, including the five contracts still awaiting settlement.
5. **Nothing deployed** → testnet deployment + receipts + runnable demo.
   Two live failures during the receipt round (two-signature creation
   breaking standard signing paths; missing-trustline diagnostics) were
   turned into documented design decisions rather than hidden.

## Architecture in one paragraph

A virtual Cargo workspace. `shared-utils` carries the shared error space
(`ForgeError`, including the `TokenTransferFailed` bucket);
`test-utils` carries the env/mock-account harness. The flagship escrow
crate uses per-record **persistent** storage (only the id counter remains
in instance storage), bumps entry TTL on every write, and exposes a
permissionless `touch_ttl` keeper entrypoint so escrows never archive
mid-flight. Every state change emits an event; every payout path
transfers tokens before mutating state. The other five contract crates
share the same patterns and are queued for settlement one tranche at a
time.

## The ask (tranche 1)

- **Scope:** hardening and completion of the escrow primitive — negative
  authorization test coverage (`set_auths` fixtures per entrypoint),
  a multi-escrow indexer service consuming the event stream, and a
  generated TypeScript client (already started) shipped as a versioned
  package.
- **Success criteria:** any Stellar developer can run the demo script
  against the deployed contract and reproduce the receipt round
  end-to-end; the indexer serves "show me my escrows" from events alone;
  coverage and CI gates stay green. (Randomized invariant testing is
  already done and in-repo, not part of this ask.)
- **Deliverable timeline:** 4 weeks from award.
- **Roadmap after:** tranche 2 — vesting settlement + TTL keeper; tranche
  3 — multi-sig execution dispatch. Each scoped identically: one
  primitive, proof artifacts, honest limitations.

## Design partner

We are seeking one Stellar-ecosystem team (payments, bounty, or
marketplace project) to integrate the escrow primitive in a pilot: one
create→deposit→payout round against their product flow, with public
feedback. The escrow event stream and typed error space are designed for
exactly this kind of embedding.

## Honest limitations (short form)

Testnet only — no mainnet deployment and no external audit (planned
before any mainnet use). Single maintainer. Five of six contracts are
state machines awaiting settlement. Full detail:
[KNOWN-LIMITATIONS.md](KNOWN-LIMITATIONS.md).
