# Escrow Contract

Secure fund custody for buyer-seller transactions with optional arbiter dispute resolution.

## Interface

```rust
fn create_escrow(buyer, seller, arbiter, amount, timeout) -> Result<u64, ForgeError>
fn deposit(escrow_id) -> Result<(), ForgeError>
fn release(escrow_id) -> Result<(), ForgeError>
fn refund(escrow_id) -> Result<(), ForgeError>
fn refund_expired(escrow_id) -> Result<(), ForgeError>
fn cancel(escrow_id) -> Result<(), ForgeError>
fn get_status(escrow_id) -> Result<EscrowStatus, ForgeError>
```

## Permissionless expiry refunds

After `created_at + timeout`, any account can call `refund_expired` to transfer
the full escrow amount to the buyer. The boundary is strict: the ledger
timestamp must be greater than the deadline. At the exact deadline, only the
existing party-authorized `refund` path is available; that path's behavior is
unchanged. `refund_expired` accepts only `Funded` escrows, so a recorded
`Disputed` state remains frozen. The token transfer happens before the state
update, and the separate `RefundExpired` event identifies keeper-triggered
settlements to indexers.

The caller pays the transaction fee and receives no bounty; the call cannot
redirect funds or produce repeated state changes. Its only successful effect
is the same terminal refund to the buyer as the existing refund path. An
already-recorded dispute or terminal state is rejected without moving funds.

## States

- `Pending` — Created but not funded
- `Funded` — Funds deposited
- `Completed` — Released to seller
- `Refunded` — Returned to buyer
- `Disputed` — Under arbitration
- `Cancelled` — Cancelled before funding

`RefundExpired` is emitted for permissionless keeper refunds, separately from
the party-triggered `Refunded` event.

## WASM Budget

Target: < 100KB

## Feature Flags

- `test-utils` — enables test-only helpers
