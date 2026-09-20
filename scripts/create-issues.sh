#!/usr/bin/env bash
# Create the initial maintainer issue backlog on GitHub.
#
# Usage:
#   ./scripts/create-issues.sh                  # dry run: print what would be created
#   ./scripts/create-issues.sh --apply          # create the issues (skips existing titles)
#   ./scripts/create-issues.sh --apply OWNER/REPO
#
# Safety:
#   - Dry run by default; nothing is created without --apply.
#   - Applies the `Stellar Wave` + `external-contributors` labels to the new
#     Wave issues (i14-i18): the repo was accepted into the Stellar Wave
#     Program on 2026-09-18, so the earlier no-Wave-label rule no longer
#     applies to newly created issues.
#   - Skips any title that already exists on the repository.
set -euo pipefail

APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true && shift
REPO="${1:-${GITHUB_REPOSITORY:-Meet-hybrid/soroban-forge}}"

if [[ "$APPLY" == true ]] && ! gh auth status >/dev/null 2>&1; then
  echo "error: gh is not authenticated" >&2
  exit 1
fi

existing_titles() {
  gh issue list --repo "$REPO" --state all --limit 200 --json title --jq '.[].title' 2>/dev/null || true
}

create_issue() {
  local title="$1"
  local labels="$2"
  local body_file="$3"

  if [[ "$APPLY" == false ]]; then
    echo "would create: $title"
    echo "  labels:     $labels"
    return
  fi

  if existing_titles | grep -Fxq "$title"; then
    echo "skip (exists): $title"
    return
  fi

  gh issue create --repo "$REPO" \
    --title "$title" \
    --label "$labels" \
    --body-file "$body_file"
}

BODY_DIR="$(mktemp -d)"
trap 'rm -rf "$BODY_DIR"' EXIT

echo "Target repository: $REPO"

# ---------------------------------------------------------------- Issue 11
cat > "$BODY_DIR/i11.md" <<'EOF'
### Description

Dependabot PRs #2 and #5 propose a six-major-version jump: soroban-sdk
21.5.1 → 27.0.4 (and soroban-sdk-macros with it). The workspace pins
`=21.5.1`, and a blind bump will not compile: contract macros, the XDR layer,
and error handling moved several majors. This is a platform migration, not a
routine bump, and it matters more here than in most projects: these contracts
are measured artifacts, and the upgrade must not silently change on-chain
behavior.

### What "done" looks like

- `cargo build --workspace --all-targets --locked` and
  `cargo test --workspace --all-targets --locked` pass against soroban-sdk 27.x.
- All six contract crates compile for `wasm32-unknown-unknown` and the WASM
  Size Check stays green; before/after sizes are stated in the PR.
- Any public interface or storage-format changes are documented in
  `CHANGELOG.md` and `docs/contracts/`.
- The dependency bump is done as one deliberate PR, not via the raw dependabot
  branches.

### Implementation guidelines

- Fork the repository, then in your fork create a branch:
  `git checkout -b chore/migrate-soroban-sdk-27`.
- Reproduce the failures first: merge `main` into one of the dependabot
  branches and run `cargo clippy --workspace --all-targets --locked`.
- Verify rather than assume: after re-pointing imports, confirm the storage
  and error types still serialize identically before trusting a green build.
- Update `Cargo.lock` intentionally; keep `--locked` CI working.

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.
- State the before/after WASM sizes and any behavior changes explicitly.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --all-targets --locked
```
EOF
create_issue \
  "chore: migrate to soroban-sdk 27 and stellar-xdr 27" \
  "chore,dependencies,complexity: high" \
  "$BODY_DIR/i11.md"

# ------------------------------------------------------------------ Issue 1
cat > "$BODY_DIR/i01.md" <<'EOF'
### Description

The escrow contract was implemented (`create_escrow`, `deposit`, `release`,
`refund`, `cancel`, `get_status`) with 16 in-crate tests. This issue is an
**independent audit and hardening pass**: verify the implementation against
the documented specification, add the edge cases that are not yet covered,
and document the storage schema. Treat the existing implementation as the
baseline — seek out what is missing rather than rewriting it.

### What "done" looks like

- An independent review of the state machine
  (`Pending → Funded → Completed | Refunded | Cancelled`) and the
  deadline-based refund authorization (seller before the deadline, buyer
  after) with any defects found fixed and tested.
- Edge cases beyond the current 16 tests, for example: refund exactly at the
  deadline boundary, the invalid-transition matrix (deposit/release/refund/
  cancel from every wrong state), timestamps near `u64::MAX` (overflow
  paths), and repeated operations after terminal states.
- The negative-authorization gap (host abort on soroban-sdk 21.x) documented
  explicitly in the test module, with each invariant covered by a reachable
  error path where possible.
- The storage schema (`DataKey::Escrow(u64)` and `Count`) documented in
  `docs/contracts/escrow.md`, including an upgrade-compatibility note.
- `cargo test -p soroban-forge-escrow --all-targets --locked` and
  `make lint` pass.

### Implementation guidelines

- Read `crates/escrow/src/lib.rs` and its tests first. Do **not** change the
  public interface (`create_escrow`/`deposit`/`release`/`refund`/`cancel`/
  `get_status`) — that is a breaking change and out of scope.
- Reuse `crates/test-utils` rather than duplicating helpers.
- Follow the house test style (`setup!` macro, `try_<method>` client
  variants, `.unwrap_err().unwrap()`).

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test -p soroban-forge-escrow --all-targets --locked
```
EOF
create_issue \
  "test(escrow): audit and harden the escrow implementation" \
  "test,complexity: medium" \
  "$BODY_DIR/i01.md"

# ------------------------------------------------------------------ Issue 2
cat > "$BODY_DIR/i02.md" <<'EOF'
### Description

The vesting contract was implemented (`create_schedule`, `claim`, `claimable`,
`get_status`) with 21 in-crate tests. This issue is an **independent audit
and hardening pass**: verify the implementation against the documented
specification, add the edge cases that are not yet covered, and document the
storage schema. Treat the existing implementation as the baseline — seek out
what is missing rather than rewriting it.

### What "done" looks like

- An independent review of the release math (floor division, cliff/duration
  boundaries, `cliff == duration`, the never-overpay guarantee) with any
  defects found fixed and tested.
- Edge cases beyond the current 21 tests, for example: timestamps/amounts
  near `u64::MAX` / `i128::MAX` (overflow paths), many interleaved partial
  claims, and repeated `claimable` calls between claims.
- The negative-authorization gap (host abort on soroban-sdk 21.x) documented
  explicitly in the test module, with each invariant covered by a reachable
  error path where possible.
- The storage schema (`DataKey::Schedule(u64)` and `Count`) documented in
  `docs/contracts/vesting.md`, including an upgrade-compatibility note.
- `cargo test -p soroban-forge-vesting --all-targets --locked` and
  `make lint` pass.

### Implementation guidelines

- Read `crates/vesting/src/lib.rs` and its tests first. Do **not** change the
  public interface (`create_schedule`/`claim`/`claimable`/`get_status`) —
  that is a breaking change and out of scope.
- Reuse `crates/test-utils` rather than duplicating helpers.
- Follow the house test style (`setup!` macro, `try_<method>` client
  variants, `.unwrap_err().unwrap()`).

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test -p soroban-forge-vesting --all-targets --locked
```
EOF
create_issue \
  "test(vesting): audit and harden the vesting implementation" \
  "test,complexity: medium" \
  "$BODY_DIR/i02.md"

# ------------------------------------------------------------------ Issue 3
cat > "$BODY_DIR/i03.md" <<'EOF'
### Description

Implement `submit`, `confirm`, and `execute` so a transaction only executes
once the configured owner threshold is met. Owner-set and threshold storage,
duplicate-confirmation rejection, and execute-once semantics are the core
invariants to get right.

### What "done" looks like

- Confirmation below threshold keeps the transaction `Pending`.
- Executing before the threshold, or twice, returns the documented error.
- Duplicate confirmations and non-owner confirmations are rejected.
- Unit tests cover the threshold boundary; `make lint` and `make test` pass.

### Implementation guidelines

- The payload is opaque `Bytes`; no external-call dispatch in this iteration.
- Match the escrow test style (`env.register_contract` + generated client).

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test -p soroban-forge-multi-sig-wallet --all-targets --locked
```
EOF
create_issue \
  "feat(multi-sig-wallet): implement authorization and execution" \
  "enhancement,complexity: medium" \
  "$BODY_DIR/i03.md"

# ------------------------------------------------------------------ Issue 4
cat > "$BODY_DIR/i04.md" <<'EOF'
### Description

Implement `propose`, `vote`, and `execute` with the
`Active → Succeeded | Defeated` lifecycle and vote tallying: id assignment,
single-vote-per-address enforcement, deadline enforcement, and execute-only-
after-deadline semantics.

### What "done" looks like

- Votes cast after the voting deadline are rejected.
- Double voting by the same address is rejected.
- State transitions are exactly `Active → Succeeded | Defeated`.
- Unit tests cover deadline, double-vote, and tally correctness; `make lint`
  and `make test` pass.

### Implementation guidelines

- The action payload is opaque `Bytes`; execution just finalizes state.
- Reuse the escrow storage/error pattern.

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test -p soroban-forge-dao-governance --all-targets --locked
```
EOF
create_issue \
  "feat(dao-governance): implement proposal/voting state transitions" \
  "enhancement,complexity: medium" \
  "$BODY_DIR/i04.md"

# ------------------------------------------------------------------ Issue 5
cat > "$BODY_DIR/i05.md" <<'EOF'
### Description

Add Soroban `Env`-based in-crate test modules (the standard
`env.register_contract` + generated `*Client` pattern) exercising every public
method of every contract — happy paths, error paths, and state-machine
transitions. The escrow crate shows the house style; extend it to the other
five contracts.

### What "done" looks like

- `cargo test --workspace --all-targets --locked` runs a growing, nonzero
  suite with every public method invoked at least once.
- Shared helpers are reused from `crates/test-utils`, not duplicated.
- CI `Test` job output shows the suite executing.

### Implementation guidelines

- Use `try_<method>` client variants to assert exact `ForgeError` codes.
- Note: negative authorization tests are not runnable in-process on
  soroban-sdk 21.x (host panics abort); document any gaps in the test module
  rather than leaving silent holes.

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --all-targets --locked
```
EOF
create_issue \
  "test: add in-process integration tests for every public contract method" \
  "test,complexity: medium" \
  "$BODY_DIR/i05.md"

# ------------------------------------------------------------------ Issue 6
cat > "$BODY_DIR/i06.md" <<'EOF'
### Description

The CLI is already wired into the workspace and builds
(`soroban-forge --help` runs; clippy-clean). This issue adds the missing
regression coverage: unit tests for argument parsing and command dispatch, a
smoke test that executes the built binary, and an explicit CI step that runs
`soroban-forge --help`.

### What "done" looks like

- `cargo test -p soroban-forge-cli --all-targets --locked` runs arg-parsing
  and smoke tests.
- A CI step runs `soroban-forge --help` and fails on a nonzero exit.
- `make lint` and `make test` pass.

### Implementation guidelines

- Test through `std::process::Command` (or `assert_cmd`) against the built
  binary; assert the subcommand list is present.
- Add the CI step to the existing `test` job.

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test -p soroban-forge-cli --all-targets --locked
```
EOF
create_issue \
  "test(cli): add smoke tests and CI coverage" \
  "test,complexity: medium" \
  "$BODY_DIR/i06.md"

# ------------------------------------------------------------------ Issue 7
cat > "$BODY_DIR/i07.md" <<'EOF'
### Description

Add a shared security-test suite asserting invariants across escrow, vesting,
multisig, and governance: authorization enforcement, no double-spend or
over-claim, integer overflow resistance, and timestamp edge cases.

### What "done" looks like

- Each contract has at least three security-focused tests.
- Tests fail loudly when an authorization or overflow check is removed.
- `make test` passes with the full suite enabled.

### Implementation guidelines

- Parameterize with `Env` auths; where the SDK's non-unwinding panics prevent
  in-process negative-auth tests, document the gap and cover the invariant by
  a reachable error path instead.
- Cover `checked_add`-style overflow paths that the implementation relies on.

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --all-targets --locked
```
EOF
create_issue \
  "test: add security invariant tests across contracts" \
  "test,complexity: high" \
  "$BODY_DIR/i07.md"

# ------------------------------------------------------------------ Issue 8
cat > "$BODY_DIR/i08.md" <<'EOF'
### Description

Cut `v0.1.0`: complete `CHANGELOG.md` from existing history, verify the
release workflow tags and drafts a GitHub release, and document the release
checklist for maintainers.

### What "done" looks like

- `CHANGELOG.md` covers all merged user-facing changes.
- `cargo metadata --no-deps --format-version 1` shows one consistent `0.1.0`
  across all workspace members.
- Release workflow runs green on a dry-run tag.

### Implementation guidelines

- Follow the Keep a Changelog format already started in `CHANGELOG.md`.
- Do not push tags during the PR; the workflow handles tagging on merge.

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --all-targets --locked
```
EOF
create_issue \
  "chore: cut the v0.1.0 release and changelog" \
  "chore,complexity: trivial,good first issue" \
  "$BODY_DIR/i08.md"

# ------------------------------------------------------------------ Issue 9
cat > "$BODY_DIR/i09.md" <<'EOF'
### Description

Harden CI: keep the WASM Size Check failing when no artifacts are produced,
add per-contract size budgets, and add a dependency policy (`cargo-deny` or
`cargo audit` config) with explicit allow/deny rules.

### What "done" looks like

- WASM Size Check fails if no `.wasm` files are produced.
- The chosen audit tool passes with a pinned, documented policy.
- Size budgets and audit commands are documented in `docs/`.

### Implementation guidelines

- Baseline: the size job already builds the six contract crates with
  `--target wasm32-unknown-unknown`; extend, don't rewrite.
- Keep the new contract-crate list in sync with workspace members (see the
  comment in `ci.yml`).

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --all-targets --locked
```
EOF
create_issue \
  "chore: harden WASM-size and dependency audit checks" \
  "chore,complexity: medium" \
  "$BODY_DIR/i09.md"

# ----------------------------------------------------------------- Issue 10
cat > "$BODY_DIR/i10.md" <<'EOF'
### Description

Write deployment guidance (testnet → mainnet, account/key setup, verifying
deployed WASM) and document each contract's storage schema plus what a
storage-breaking upgrade looks like.

### What "done" looks like

- Every contract links to its storage layout and deploy commands.
- A short "upgrade compatibility" section explains when storage changes break
  upgrades.
- No dead links in the edited docs.

### Implementation guidelines

- Use the actual `stellar contract` commands that work with the current
  contract set; verify, don't copy from memory.
- Cross-link the storage keys defined in each contract crate.

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --all-targets --locked
```
EOF
create_issue \
  "docs: document deployment and storage compatibility" \
  "documentation,complexity: trivial,good first issue" \
  "$BODY_DIR/i10.md"

# NOTE: a previous draft here proposed "feat(vesting): add SEP-41 settlement,
# persistent storage, and events". That scope is already covered by the open
# GitHub issues #50 (vesting SEP-41 settlement) and #55 (vesting persistent
# storage + TTL), so it was removed to avoid a duplicate. Replaced with the
# DAO execution tranche, which no open issue covers.

# ----------------------------------------------------------------- Issue 12
cat > "$BODY_DIR/i12.md" <<'EOF'
### Description

`propose` and `vote` work, but `execute` only finalises state — the stored
action payload is never dispatched (deferred in #18: "execution just
finalizes state"). Governance that records a decision but cannot enact it is
incomplete. Make `execute` perform a real cross-contract call to a target
address with the approved payload, and guarantee a reverting target never
marks the proposal executed. This is high-complexity: it introduces
cross-contract invocation, extends the proposal lifecycle, and needs real
failure-ordering tests.

### Scope

- `propose` accepts a target contract address plus the action `Bytes` payload.
- Once a proposal is `Succeeded` and past its deadline, `execute` performs a
  real cross-contract invocation; **execution is permissionless** (the
  outcome was already decided by voters).
- Extend the lifecycle with a terminal `Executed` state reached only from
  `Succeeded`; `Active → Succeeded | Defeated` is unchanged.
- Failure ordering: a target revert surfaces as a documented `ForgeError` and
  leaves the proposal `Succeeded` (not `Executed`).
- Emit `ProposalCreated`, `VoteCast`, and `Executed` events.
- Update `docs/FEATURE-STATUS.md` and the DAO docs.

### Non-goals

- Weighted voting, quorum redesign, or delegation.
- Timelock / execution queue.
- Persistent storage + TTL migration (separate task).
- Typed action enums — the payload stays opaque `Bytes`.

### What "done" looks like

- `execute` performs a real invocation for a `Succeeded`, past-deadline
  proposal; a second call is rejected (`Executed` is terminal).
- `Defeated` or still-`Active` proposals cannot be executed.
- A target revert returns a documented error and leaves the proposal not
  `Executed`; a test asserts the target state is unchanged.
- An integration test dispatches to a registered mock target and asserts its
  state changed exactly once.
- Events are emitted; docs match behavior; `make lint` and the DAO test
  target pass; the WASM size budget is respected.

### Implementation guidelines

- Read `crates/dao-governance/src/lib.rs` (state machine) and
  `crates/escrow/src/lib.rs` (real inter-contract pattern).
- Prefer `env.try_invoke_contract` so a target revert is a testable `Result`,
  not an unwinding host panic.
- Verify, don't assume, whether the DAO—as caller—satisfies a target's own
  `require_auth`; document the verified behaviour as `crates/escrow/src/authz.rs`
  does. Commit `Executed` only after a successful invocation.
- Keep the public entrypoint names.

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.
- Explain the lifecycle/interface change and the failure-ordering test.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test -p soroban-forge-dao-governance --all-targets --locked
```
EOF
create_issue \
  "feat(dao-governance): execute passed proposals on-chain" \
  "enhancement,complexity: high" \
  "$BODY_DIR/i12.md"

# NOTE: a previous draft here (i13, "feat(multi-sig-wallet): execute real
# cross-contract payloads") is already covered by open issue #57
# ("feat(multi-sig-wallet): dispatch approved payloads to a target contract").
# It was removed to keep the Wave backlog free of near-duplicates.

# --------------------------------------------------------------- Issue 14
# Medium: single well-scoped feature on one crate (subscription-payments).
# Targets a gap the code itself documents: PastDue is reserved but unreachable.
cat > "$BODY_DIR/i14.md" <<'EOF'
### Description

The subscription-payments contract (`subscribe`, `charge`, `cancel`,
`get_subscription`) implements pull-based recurring billing, but it has no
arrears handling: the `PastDue` status exists in `SubscriptionStatus` yet is
explicitly "reserved for a failed-payment retry model that lands in a
follow-up" (see the crate docs) and is unreachable today. In practice a
provider simply cannot pull when a subscriber defaults, and the subscription
stays `Active` forever. This issue adds the retry model that makes `PastDue`
real.

### What "done" looks like

- `charge` on a subscription whose subscriber cannot pay (no balance / no
  trustline, surfaced as `ForgeError::TokenTransferFailed` once real SAC
  settlement is wired) transitions the subscription to `PastDue` and records
  the failed billing point without advancing `last_charged` past a period that
  was not successfully paid.
- A `retry` (or `charge` re-invocation) path that lets a `PastDue`
  subscription return to `Active` on a successful payment, with at most one
  period billed per successful call (catch-up semantics unchanged).
- A bounded retry window: after `max_retries` consecutive failed attempts, the
  subscription transitions to `Cancelled` (or an explicitly documented terminal
  state) — no subscription can sit in `PastDue` forever.
- `PastDue` subscriptions reject `charge` unless it is a documented retry;
  `cancel` still works from `PastDue`.
- Unit tests cover: first failure → `PastDue`; successful retry → `Active`;
  retry exceeding the bound → terminal state; `cancel` from `PastDue`;
  idempotent retry rejection for non-`PastDue` states.
- `cargo test -p soroban-forge-subscription-payments --all-targets --locked`
  and `make lint` pass; WASM size budget respected.

### Implementation guidelines

- Read `crates/subscription-payments/src/lib.rs` end to end first — the module
  docs describe the intended lifecycle and the reserved `PastDue` status.
- Real balance settlement against a SEP-41 token is **out of scope** (it is a
  separate, larger task). Simulate the failure with a registered mock token
  contract in `crates/test-utils`, or model the failure as an explicit
  `mark_failed` provider entrypoint — pick one, document the choice.
- Do **not** change the existing public entrypoint signatures
  (`subscribe`/`charge`/`cancel`/`get_subscription`); additive changes only.
- Reuse `crates/test-utils` and the house test style (`setup!` macro,
  `try_<method>` client variants, `.unwrap_err().unwrap()`).

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.
- State explicitly whether failures are modeled via mock token or a new
  entrypoint, and why.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test -p soroban-forge-subscription-payments --all-targets --locked
```
EOF
create_issue \
  "feat(subscription-payments): implement PastDue retry and arrears model" \
  "enhancement,complexity: medium,Stellar Wave,external-contributors" \
  "$BODY_DIR/i14.md"

# --------------------------------------------------------------- Issue 15
# High: royalty split precision and multi-recipient accounting.
cat > "$BODY_DIR/i15.md" <<'EOF'
### Description

The marketplace-royalties contract supports exactly **one recipient per
collection** with a single `bps` rate (see `crates/marketplace-royalties/src/
lib.rs` module docs: "Multiple recipients per collection, per-token royalties,
and actual token settlement are intentionally out of scope"). Real marketplaces
need splits like 60/30/10 across creator/collaborator/platform. This issue
implements multi-recipient splits with the rounding, dust, and invariant
properties that make them safe on-chain.

### What "done" looks like

- `set_royalty` (or an additive `set_royalty_splits`) accepts up to a small,
  documented maximum of recipients per collection (e.g. 5), each with its own
  bps, and **rejects a total exceeding 10_000 bps**.
- `distribute` computes every recipient's share as `amount * bps / 10_000`
  with floor division and returns the exact net owed to the seller; the sum of
  all shares plus the net always equals `amount` (dust goes to the seller, and
  a test pins that property).
- The never-negative and never-overpay guarantees from the single-recipient
  version are preserved and re-asserted by tests (including `bps == 10_000`
  and amount values near `i128::MAX`).
- `Disabled` configurations settle in full to the seller, unchanged.
- Backward compatibility: existing single-recipient configs keep working
  (either migrated internally to a one-element split or served by the
  unchanged `set_royalty` path); `get_royalty` behavior for existing configs
  is documented either way.
- Unit tests cover: multi-recipient split sums exactly; over-10_000 total
  rejected; max-recipient bound enforced; zero-bps recipients allowed;
  re-registration replaces all splits atomically (no partial state on error);
  `distribute` on an unregistered collection is still `NotFound`.
- `cargo test -p soroban-forge-marketplace-royalties --all-targets --locked`
  and `make lint` pass; WASM size budget respected.

### Implementation guidelines

- Read `crates/marketplace-royalties/src/lib.rs` first; the single-recipient
  implementation and its rounding comments are the baseline.
- Storage: a `Vec<Split>` per collection in instance storage is acceptable at
  this scale; document the schema in the crate docs, including what a
  storage-breaking upgrade would look like.
- Keep `set_royalty`'s existing signature and semantics; add rather than
  mutate where possible, and update all callers/tests.
- Reuse `crates/test-utils` and the house test style (`setup!` macro,
  `try_<method>` client variants, `.unwrap_err().unwrap()`).

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.
- Include a worked example (e.g. 3 recipients over a 1_000-unit sale) showing
  each share and the dust destination.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test -p soroban-forge-marketplace-royalties --all-targets --locked
```
EOF
create_issue \
  "feat(marketplace-royalties): multi-recipient splits with exact accounting" \
  "enhancement,complexity: high,Stellar Wave,external-contributors" \
  "$BODY_DIR/i15.md"

# --------------------------------------------------------------- Issue 16
# High: reachability for the vesting contract's reserved Revoked status.
cat > "$BODY_DIR/i16.md" <<'EOF'
### Description

The vesting contract (`create_schedule`, `claim`, `claimable`, `get_status`)
carries a `Revoked` status that is explicitly "reserved for a revocation
method that lands in a follow-up; it is not reachable through the current
public interface" (see `crates/vesting/src/lib.rs`). A vesting feature that
can never be revoked cannot model real grant programs: when a grant is
terminated, unvested tokens must stop accruing. This issue implements the
revocation path that makes `Revoked` real.

### What "done" looks like

- A `revoke(schedule_id)` entrypoint that transitions a schedule
  `Locked | Vesting → Revoked` and permanently stops further vesting.
- The revoking party is explicit: extend `create_schedule` with a funder (or
  `admin`) argument recorded on the schedule — revocation belongs to the
  party that funds the grant, not the beneficiary. Changing
  `create_schedule`'s signature is in scope; update all callers and tests
  and call it out in the PR.
- The pre-revocation vested amount is frozen at the revocation ledger
  timestamp: `claim` after revocation succeeds only up to that amount, and
  `claimable` returns `0` for a `Revoked` schedule once it is claimed.
- Revoking an already-`Completed` or already-`Revoked` schedule is rejected
  with a documented error; double-revoke is impossible.
- Unit tests cover: revoke while `Locked`; revoke mid-vesting (partial claim
  still possible up to the frozen amount); revoke after completion is
  rejected; double revoke rejected; non-admin revoke rejected; `claimable`
  before and after revocation.
- `cargo test -p soroban-forge-vesting --all-targets --locked` and
  `make lint` pass; the WASM size budget is respected.

### Implementation guidelines

- Read `crates/vesting/src/lib.rs` end to end first: the vesting math
  (floor division in the vested computation), the `DataKey::Schedule(u64)`
  storage, and the module docs noting the status is unreachable.
- Adding a field to the stored schedule is a storage-breaking upgrade —
  document it in the crate docs following the upgrade-compatibility pattern
  used in `docs/contracts/`.
- Coordination: open issues cover SEP-41 claim settlement (#50) and the
  persistent-storage/TTL migration (#55). Keep this change compatible with
  both — revocation is state-machine logic and must not depend on transfer
  mechanics or storage layout choices.
- Keep `claim`/`claimable`/`get_status` signatures unchanged.
- Reuse `crates/test-utils` and the house test style (`setup!` macro,
  `try_<method>` client variants, `.unwrap_err().unwrap()`).

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.
- State the `create_schedule` signature change and the storage compatibility
  note explicitly.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test -p soroban-forge-vesting --all-targets --locked
```
EOF
create_issue \
  "feat(vesting): make the reserved Revoked status reachable" \
  "enhancement,complexity: high,Stellar Wave,external-contributors" \
  "$BODY_DIR/i16.md"

# --------------------------------------------------------------- Issue 17
# High: per-token royalty overrides on top of the collection-level config.
cat > "$BODY_DIR/i17.md" <<'EOF'
### Description

The marketplace-royalties contract stores one royalty configuration per
collection, and the crate docs explicitly list "per-token royalties" among
the out-of-scope features (see `crates/marketplace-royalties/src/lib.rs`).
Real marketplaces need token-level exceptions — a specific edition or 1/1
piece carries a different rate than its collection default. This issue adds
per-token overrides that take precedence over the collection configuration,
with the same validation and rounding guarantees.

### What "done" looks like

- `set_token_royalty(collection, token_id, recipient, bps)` (name flexible)
  registers an override for a single token within a collection, with the
  same `bps <= 10_000` validation as the collection-level config, and a
  `clear_token_royalty(collection, token_id)` that falls back to the
  collection config.
- `distribute` uses the token override when one exists, otherwise the
  collection config, otherwise `NotFound` — precedence documented and
  tested.
- A `get_token_royalty` read-only view distinguishes "no override" from
  "override set" (documented return convention).
- Rounding and safety guarantees preserved and pinned by tests: floor
  division, shares + net == amount, never-negative net, `bps == 10_000` and
  `0` bps edges, amounts near `i128::MAX`.
- Re-registering or updating a collection config does not corrupt or erase
  token overrides (tested).
- Unit tests cover: override precedence, fallback after clear, override on
  an unregistered collection (allowed or `NotFound` — pick one, document it,
  test it), update-in-place, and the `Disabled`-collection interaction
  (document whether `Disabled` skips overrides; test the chosen behavior).
- `cargo test -p soroban-forge-marketplace-royalties --all-targets --locked`
  and `make lint` pass; WASM size budget respected.

### Implementation guidelines

- Read `crates/marketplace-royalties/src/lib.rs` first; the `DataKey::Royalty`
  layout, `bps` validation, and the compute-only `distribute` are the
  baseline.
- Storage: add a `DataKey::TokenRoyalty(collection, token_id)` key rather
  than nesting overrides inside the collection struct, so per-token entries
  scale independently. Document the schema in the crate docs.
- Choose and document a token-id representation (`u64`/`u256`/`Bytes`) that
  matches how the repo's collection contracts mint ids — verify rather than
  assume, and state the choice in the PR.
- Coordination: sibling issues cover multi-recipient splits and tests for
  this crate. Keep this change additive and orthogonal — it changes *which
  rate applies*, not how many recipients exist.
- Keep `set_royalty`/`distribute`/`get_royalty` behavior backward-compatible
  for collections without overrides.
- Reuse `crates/test-utils` and the house test style (`setup!` macro,
  `try_<method>` client variants, `.unwrap_err().unwrap()`).

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.
- State the token-id representation choice and the override-precedence rules.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test -p soroban-forge-marketplace-royalties --all-targets --locked
```
EOF
create_issue \
  "feat(marketplace-royalties): per-token royalty overrides" \
  "enhancement,complexity: high,Stellar Wave,external-contributors" \
  "$BODY_DIR/i17.md"

# --------------------------------------------------------------- Issue 18
# High: token-balance custody model for the multisig wallet.
cat > "$BODY_DIR/i18.md" <<'EOF'
### Description

The multi-sig wallet stores `Owners`, `Threshold`, and `Tx` records in
instance storage, and `execute` flips the status without dispatching anything
(real payload dispatch is covered by a separate issue). Before payloads can be
executed against the chain, the wallet needs a **custody model**: which assets
it holds, where they live in storage, and how balances survive Soroban's
storage TTL system. Instance storage is the wrong home for anything the
wallet custodies long-term — this issue designs and implements the balance
layer.

### What "done" looks like

- A documented custody design covering: SEP-41 token balances held by the
  wallet contract, per-token accounting keys in **persistent** storage (not
  instance), and the TTL/bump strategy for each key class — with the
  rationale written into the crate docs next to the existing storage-keys
  comment.
- `deposit(env, token, amount)` pulling tokens into the wallet (owner or
  third-party deposits: pick one, document it) and a read-only
  `balance(env, token)` view.
- A `withdraw` flow gated by the existing multisig machinery: a withdrawal is
  a `Pending` tx like any other, executed only past threshold, moving real
  tokens to a destination recorded in the tx.
- Failure ordering: transfer first, state second; a failed transfer leaves
  balances and tx state untouched (tested).
- Overflow-safe accounting (`checked_add`/`checked_sub` mapping to
  `ForgeError::ArithmeticOverflow`), and a test that a withdrawal exceeding
  the balance fails with the documented error and changes nothing.
- Integration tests with a registered token: deposit → balance reflects it;
  threshold-approved withdraw → destination balance increases, wallet balance
  decreases, exactly once; a below-threshold withdraw cannot execute.
- `cargo test -p soroban-forge-multi-sig-wallet --all-targets --locked` and
  `make lint` pass; WASM size budget respected.

### Implementation guidelines

- Read `crates/multi-sig-wallet/src/lib.rs` (state machine and storage keys)
  and `crates/escrow/src/lib.rs` `transfer_to_contract` /
  `transfer_from_contract` / `bump_entry` for the house storage-bumping and
  transfer pattern.
- Study the escrow crate's persistent-vs-instance storage rationale (see its
  `DataKey` docs) and mirror that reasoning for the wallet's balance keys.
- Keep the existing entrypoints (`initialize`/`submit`/`confirm`/`execute`)
  and their semantics; the new flows are additive. If `execute` gains any
  balance-affecting behavior for withdrawal txs, document it in the PR.
- The payload stays opaque `Bytes` for arbitrary txs; withdrawals may use a
  typed record instead — pick one approach, document the tradeoff.
- Reuse `crates/test-utils` and the house test style.

### PR guidelines

- Get assigned before starting.
- PR description must include: `Closes #<this issue>`.
- Summarize the custody design (key classes, TTL strategy) in the PR body.

### 📋 Before you start

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test -p soroban-forge-multi-sig-wallet --all-targets --locked
```
EOF
create_issue \
  "feat(multi-sig-wallet): token custody with TTL-safe persistent balances" \
  "enhancement,complexity: high,Stellar Wave,external-contributors" \
  "$BODY_DIR/i18.md"

if [[ "$APPLY" == false ]]; then
  echo
  echo "Dry run complete. Re-run with --apply to create the issues."
  echo "Target repository: $REPO"
else
  echo
  echo "Done. Verify with: gh issue list --repo $REPO"
fi
