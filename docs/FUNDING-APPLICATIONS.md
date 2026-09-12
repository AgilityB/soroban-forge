# Funding applications — GrantFox & Drips

Everything needed to apply to both funding sources. Part A is
paste-ready text for the GrantFox application form. Part B is the
step-by-step Drips claim checklist (Drips has no application form —
every GitHub repo is listable; you claim it).

---

## Part A — GrantFox application (paste-ready)

> **Where to submit:** the GrantFox campaign form. Fill it from this
> section; keep the tranche ask exactly as written below.
> Full-length narrative with the claims-vs-evidence table:
> [GRANT-APPLICATION.md](GRANT-APPLICATION.md).

**Project:** Soroban Forge — escrow primitive for the Stellar ecosystem

**Repo:** https://github.com/Meet-hybrid/soroban-forge

**One-liner:** An open-source Stellar foundations project shipping one
production-grade escrow primitive — real SEP-41 token custody, arbiter
disputes, lifecycle events, TTL-safe persistent storage — on
soroban-sdk 27, with five more contracts queued as follow-up tranches.

**What exists today (every claim links evidence):**

- Escrow contract **live on Stellar testnet**:
  `CC227UDF6WBLRTOKKVRIJN7BGSBK67ZGV6IDARJ2AMATGSQ7UZNBZHSB` — contract
  ID, WASM sha256, and transaction links in the README "Proof at a
  glance" table.
- **Three complete receipt rounds with real token movement**: create →
  deposit → release, and both dispute outcomes (arbiter rules for
  seller; arbiter refunds buyer). On-chain conservation verified:
  1500 credit minted = 500 + 1000 paid out, contract holds zero.
  Reproducible: `bash scripts/demo-testnet.sh`.
- **107 tests** including a randomized proptest suite (funds
  conservation over random terminal paths, tamper-resilient pool
  conservation, fund safety over arbitrary call sequences). Clippy
  `-D warnings`, rustfmt, cargo audit, and a WASM size budget enforced
  in CI — all seven checks green on `main`.
- **Generated TypeScript client** (`@soroban-forge/escrow-client`) built
  from the deployed contract ID, network config embedded.
- Honest status docs: [KNOWN-LIMITATIONS.md](KNOWN-LIMITATIONS.md) and
  [FEATURE-STATUS.md](FEATURE-STATUS.md).

**Note on the previous submission:** v0.1.0 was rejected — correctly —
for state-only contracts with no token settlement, an outdated SDK
(soroban-sdk 21), and nothing deployed. All three root causes are fixed
in v0.2.0 with on-chain proof; the full rejection → resolution mapping
is in [GRANT-APPLICATION.md](GRANT-APPLICATION.md).

**The ask (tranche 1 — scope-capped):**

- **Scope:** hardening and completion of the escrow primitive only —
  negative authorization test coverage (`set_auths` fixtures per
  entrypoint), a multi-escrow indexer service consuming the event
  stream, and the generated TypeScript client shipped as a versioned
  package with its own test suite.
- **Success criteria:** any Stellar developer can run the demo script
  against the deployed contract and reproduce the receipt round
  end-to-end; the indexer serves "show me my escrows" from events alone;
  coverage and CI gates stay green.
- **Timeline:** 4 weeks from award.
- **Roadmap after (not part of this ask):** tranche 2 — vesting
  settlement + TTL keeper; tranche 3 — multi-sig execution dispatch.

**Design partner:** outreach to campaign-cohort projects whose products
embed escrow (bounty, freelance/milestone, batch-payment) is underway;
template and tracking in
[DESIGN-PARTNER-OUTREACH.md](DESIGN-PARTNER-OUTREACH.md). *(Update this
paragraph to name the partner before submitting if a commitment lands —
it is the single strongest line in the application.)*

**Honest limitations:** testnet only, no external audit (planned before
any mainnet use), single maintainer, five of six contracts are state
machines awaiting settlement in later tranches.

---

## Part B — Drips Open Source (claim checklist)

Drips is not competitive — there is no form, no review, no rejection.
Every GitHub repository is already fundable on Drips as "unclaimed";
claiming gives you control of the project page and of how incoming
funds split. Source: [Drips claim docs](https://docs.drips.network/get-support/claim-your-repository/).

**How it works:** funds flow through Drip Lists into a global dependency
tree and are split to projects monthly (Ethereum) or daily (OP Mainnet,
Filecoin). Claiming proves ownership via a `FUNDING.json` file on the
repo's **default branch** containing your Ethereum address.

### Steps

1. **Set up an Ethereum wallet** (e.g. Rabby or MetaMask). Solo
   maintainer → a personal wallet is fine; a Safe multisig is only
   needed for multi-maintainer projects.
2. **Pick the network:**
   - *Ethereum mainnet* — the default; monthly settlement; higher gas.
   - *OP Mainnet* — daily settlement; much cheaper gas. Recommended
     unless you specifically want mainnet.
3. **Fund the wallet** with a small amount of ETH for gas (claim is one
   transaction; on OP Mainnet cents, on mainnet a few dollars
   depending on gas prices).
4. **Add `FUNDING.json` to the repo default branch.** The Drips app
   generates it during the claim flow, but it can also be committed in
   advance — give the wallet address to your agent and it will be
   committed and pushed. Format:
   ```json
   {
     "drips": {
       "optimism": {
         "ownedBy": "<YOUR_ETHEREUM_ADDRESS>"
       }
     }
   }
   ```
   *(key = the chain you chose in step 2: `ethereum`, `optimism`, or
   `filecoin`)*
5. **Claim:** open the Drips app → connect wallet → **Projects → Claim
   project** → paste `https://github.com/Meet-hybrid/soroban-forge` →
   it verifies the `FUNDING.json` proof on-chain → confirm the
   transaction.
6. **Configure splits:** 100% maintainer (you), or split a percentage to
   dependencies the project builds on (e.g. `rs-soroban-sdk` if
   listed) — splits are editable at any time.
7. **Customize the project page** (name, description, emoji) so it
   matches the GrantFox narrative — one consistent story everywhere.

### Notes

- The repo is already *fundable* while unclaimed — anyone can add it to
  a Drip List today; unclaimed earnings become collectible after you
  claim. So there is no downside to doing this early.
- `FUNDING.json` is public by design (that is how ownership proof
  works); it contains only the owner address.
- Drips complements GrantFox rather than competing: GrantFox pays
  tranches for scoped deliverables; Drips is passive recurring funding
  from anyone who lists the repo. List the repo in both.

---

## What only the human can do

| Item | Owner |
|---|---|
| Fill and submit the GrantFox form (paste from Part A) | you |
| Send the design-partner outreach to 2–3 projects | you |
| Create + fund the Ethereum wallet, run the claim transaction | you |
| Choose the Drips network and split configuration | you |
| Provide the wallet address for `FUNDING.json` (then it gets committed) | you → agent |
