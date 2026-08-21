# Fix Progress Summary
Last updated: 2026-08-21 — **F1–F5 complete, F6 proposal-only, full test pass executed**

Branch: `main` (gate 3 of FIX_PLAN.md overridden by the user in-session; auto-push to
`origin main` after each fix authorized by the user directly).
Baseline commit: `4193035`. Latest: `31a5072`. All work is committed and pushed.

---

## Read this first

**Everything is done in the repository. Nothing is deployed to the database.**

The code is in good order: 152 automated tests pass, `flutter analyze` reports 0 errors, and every
fix is committed and pushed. But **two P0 defects are live in production right now**, and they stay
live until `database/DEPLOY_PENDING.sql` is applied:

1. **The F2 RLS hole is open.** The live policy is still `allow_all_authenticated_ride_requests`
   (`FOR ALL ... USING (true) WITH CHECK (true)`). Any authenticated user can read, modify or
   delete **any other user's ride request** through the REST API.
2. **The must-be-confirmed guard is enforced nowhere.** F1 correctly moved it out of Dart and into
   `complete_ride_request` — but the app change is committed and the schema change is not deployed.
   In this intermediate state, a completion call on an unconfirmed ride would succeed and write a
   CO2 record for a trip nobody agreed to. **For this one rule the current state is worse than
   before F1**, and stays that way until the SQL lands.

**Do the deployment before anything else.** Steps are at the top of `DEPLOY_PENDING.sql` and in
`03_server_side_expiry.md`.

---

## Fix status

| # | Fix | Status | Commit | Pushed |
|---|-----|--------|--------|--------|
| F1 | Double-booking race condition | DONE | `aa6dfb4` | YES |
| F2 | RLS policy hole on `ride_requests` | DONE | `336c09c` | YES |
| F3 | Server-side expiry scheduling | **NEEDS_DECISION** — migration written, needs `pg_cron` | `4f65de2` | YES |
| F4 | Defense-in-depth constraints | DONE | `2fc9913` | YES |
| F5 | Idempotency on ride-request creation | DONE (narrower than it sounds — see below) | `945a2cd` | YES |
| F6 | Broader hardening | **NEEDS_DECISION** — proposal only, no code written | `6ad2142` | YES |
| — | TEST_PLAN.md execution | DONE — verdict **NOT SAFE** (code-level only) | `31a5072` | YES |

"DONE" means written, reviewed and covered by regression tests. It does **not** mean verified at
runtime — see below.

---

## Testing

Full TEST_PLAN.md pass executed. Results in **`TEST_RESULTS.md`**.

| Metric | Count |
|---|---|
| TEST_PLAN line items | 78 |
| Passed | 24 |
| Failed | 3 (all §7, all fixed) |
| Blocked | 51 |

**Release verdict: NOT SAFE** — explicitly a *code-level* verdict, not a runtime-verified one.

The 51 BLOCKED items are not a testing shortfall. They follow directly from the fixes existing only
in the repository: every test whose real assertion is *"the database rejects this"* is unverifiable
without a live instance. They were recorded BLOCKED rather than PASS deliberately — marking them
passed on the strength of reading the schema is the exact false assurance the plan exists to
prevent.

### Automated suite growth

| Stage | analyze | tests |
|-------|---------|-------|
| baseline (pre-fix) | 70 issues, 0 errors | 74/74 |
| F1 | 70 issues, 0 errors | 88/88 |
| F2 | 70 issues, 0 errors | 96/96 |
| F3 | 70 issues, 0 errors | 108/108 |
| F4 | 70 issues, 0 errors | 117/117 |
| F5 | 70 issues, 0 errors | 127/127 |
| test pass | 70 issues, 0 errors | **152/152** |

The 70 analyze issues are unchanged from baseline and none are errors. Nothing in this work
introduced one.

### Defect found by the test pass

`calculateCo2Saved` / `calculateFuelSaved` had no input validation, so a negative distance,
emission factor or passenger count produced a **negative "saving"** (−0.3 kg CO2 for −2.5 km).
These feed `ride_completion_log` and the leaderboard, so a negative figure silently *subtracts*
from a driver's lifetime total. `distance_km` and `emission_factor_kg_per_km` are admin-editable
via `app_config`, so it is reachable by configuration, not only by a bug. **Fixed in Dart**
(`31a5072`); non-positive inputs return `0.0`.

**Still open:** the SQL path in `complete_ride_request` has the same flaw and is the path that
writes the persisted audit record. Deliberately not changed — `DEPLOY_PENDING.sql` is queued for
review and altering it underneath that would be reckless. Suggested guard is in `TEST_RESULTS.md`
→ Coverage gaps → Gap 5.

---

## Open decisions

**F3 — `pg_cron`.** Confirm the extension can be enabled on this plan tier and enable it
(Database → Extensions). If it cannot, choose a fallback scheduler for an Edge Function
(GitHub Actions / QStash / other) — an infrastructure and cost decision. **The scheduling block is
deliberately non-fatal, so applying the script succeeds even when it schedules nothing.** Verify:

```sql
SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'ride_request_expiry';
```

An empty result means F3 is not in force. Details in `03_server_side_expiry.md`.

**F6 — hardening scope.** Proposal in `06_hardening_proposal.md`, no code written. Recommendation:
approve H1 (audit the 33 swallowed `catch (_)` — two real bugs hid there for the project's
lifetime) and H2 (structured logging) as one small pass; treat H3 (offline/retry) as follow-up;
defer H4 (screen decomposition) and H5 (state management) until there is coverage worth refactoring
against.

---

## Deployment

**`database/DEPLOY_PENDING.sql` is the single script to run.** Covers F0 prerequisites and F1–F5 in
apply order, guarded for re-runs, ending with eleven post-conditions.

Before running, two data pre-checks — the only things that can fail on real data rather than on a
mistake:

```sql
-- 1. duplicate active matches would abort F4's unique index
SELECT session_id, passenger_id, count(*) FROM public.ride_matches
WHERE status = 'active' GROUP BY session_id, passenger_id HAVING count(*) > 1;

-- 2. any status outside the allowed vocabulary would abort the F3 constraint
SELECT DISTINCT status FROM public.ride_requests;
```

Then: apply → **read all eleven post-conditions** (a clean run does not prove the fixes are in
force) → ship the app build *with* the schema, not before it.

**Found during the deployment review:** `confirmation_deadline` is referenced 13 times across
`supabase_schema.sql` but defined by no file in this repo. If the live database has it, it was
added out of band. `DEPLOY_PENDING.sql` section F0 now adds it guarded.

---

## Carried-forward notes

- **All SQL is unexecuted.** No statement in this work has run anywhere. Reviewed by reading only;
  the tests assert SQL *text*, not behaviour.
- **F5 protects less than its name implies.** The idempotency key only helps when the *same* key is
  reused across a retry. No caller passes a stable key yet, so a double-tapped Create Request still
  creates two requests. `createRideRequest` exposes `clientRequestId` ready for it; wiring the UI
  was outside F5's stated scope.
- **F2 narrows two client sweeps and F3 is the replacement.** `autoExpirePastRequests()` and the
  expiry loop in `expireUnconfirmedMatches()` currently touch other users' rows; after F2 they only
  touch the caller's. Both sit inside `catch (_) {}`, so the narrowing will not surface as an error
  — it will just silently do less. This makes the F3 `pg_cron` decision more load-bearing than it
  looks.
- **F4's unique index is the one statement that can fail on real data.** Pre-check above.
  Remediation is in the script but left commented out — it picks a winner between two matches, and
  the losing driver may already have collected the passenger.
- **No F4 constraint has had its rejection behaviour tested.** Deliberate-violation smoke tests are
  written out as post-conditions 7–8.
- **Deactivation has a revocation window.** It bans the account so no *new* session issues, but an
  already-issued JWT stays valid until expiry. A design characteristic, not a bug — worth a product
  decision.
- **`test/audit_supabase_test.dart` asserts nothing.** It checks a hardcoded list against itself and
  would pass if every table were dropped. Left in place (TEST_PLAN forbids deleting tests); real
  schema assertions now live in the four schema-shape test files.
- **§10 is blocked by test infrastructure, not just the database.** No mocking library and no
  injection seam for the Supabase client. Fixable entirely in-repo, and would unblock most of §10
  without any live instance.

---

## What to do first, in order

1. Run the two data pre-checks above.
2. Apply `database/DEPLOY_PENDING.sql`.
3. Read all eleven post-conditions, especially #3 (`pg_cron`) — the one that silently no-ops.
4. Ship the app build together with the schema.
5. Re-run TEST_PLAN §3, §5, §6, §12, §13 against the live instance. **Those five sections are the
   actual verification of F1–F5.** Everything done so far is preparation for them.
6. Decide F6 scope.
