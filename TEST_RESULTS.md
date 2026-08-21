# FFL Smart Ride — Test Results
Run date: 2026-08-21
Branch/commit tested: main, 6ad2142

## Summary

Counts are of TEST_PLAN line items (the rows in the tables below), not of individual `flutter test`
assertions. The automated suite behind them is 152 passing tests.

| Metric | Count |
|---|---|
| Total tests run | 78 |
| Passed | 24 |
| Failed | 3 (all in §7, all fixed — see below) |
| Skipped/Blocked | 51 |
| P0 (release-blocking) failures | 3 found, 3 resolved in code; **7 P0 items unverified at runtime** |

**Release verdict: NOT SAFE** — the repository is in good order and all 152 automated tests pass,
but every P0 category (auth, authorization, RLS, ride integrity, duplicate booking, completion,
audit) is unverified at runtime because `DEPLOY_PENDING.sql` has not been applied, and two P0
defects are live in production right now.

**This is a code-level verdict only, not a runtime-verified one.** Full reasoning at the bottom.

The 51 BLOCKED items are not a testing shortfall — they are the direct consequence of the fixes
existing only in the repository. They become testable the moment the schema is deployed.

---

## Reading this document

**The single most important fact about this run:** none of the F1–F5 database changes have been
applied to the live Supabase instance. They exist only in `database/supabase_schema.sql` and
`database/DEPLOY_PENDING.sql`. There is no database connection available from this environment.

That means every test in TEST_PLAN.md whose real assertion is *"the database rejects this"*
cannot be verified now, no matter how carefully the SQL reads. Those are recorded as **BLOCKED**,
never as PASS. Marking them PASS on the strength of reading the schema would be exactly the kind
of false assurance this plan exists to prevent — the F2 RLS hole, for instance, reads as closed
in the repository while remaining wide open in production.

Result vocabulary used below:

| Result | Meaning |
|---|---|
| **PASS** | Genuinely executed and passed |
| **FAIL** | Genuinely executed and failed |
| **FIXED** | Failed on first execution, defect corrected, re-run passes |
| **BLOCKED** | Requires `DEPLOY_PENDING.sql` applied to live Supabase first — verified at code/schema level only, not runtime |

---

## Results by section

### 1. Authentication

| Test | Method | Result | Notes |
|---|---|---|---|
| Valid login | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. Needs a real Supabase auth session; no credentials or instance available. |
| Invalid login (wrong password / unknown email) | automated (partial) | **BLOCKED** | Error *translation* is genuinely tested (`auth_and_registration_test.dart` → `AppExceptions error message translation`, PASS). The actual rejection by GoTrue is not — that is a live-service behaviour. |
| Session persistence across app restart | — | **BLOCKED** | Requires a real session and app relaunch; see also §11. |
| Logout (session cleared, protected calls fail after) | — | **BLOCKED** | The second half — "protected calls fail afterward" — is a server-side assertion and is the part that matters. Unverifiable now. |
| Unauthorized access (no session → blocked) | automated (partial) | **BLOCKED** | Client-side guards exist (`auth_gate.dart`, and every repository method opens with a `currentUser == null` throw). Those are client checks; whether the *API* rejects an unauthenticated call is the real test and needs the live instance. |
| Login/registration UI renders and behaves | automated | **PASS** | `auth_ui_test.dart` — 15/15 including password toggle and vehicle switch. Genuinely executed. |

**Section note.** Nothing in §1 could be verified end-to-end. The client-side pieces pass, but a
client-side auth check is not authentication — it is a UI convenience. Recorded as BLOCKED rather
than PASS deliberately.

### 2. Role-based authorization

| Test | Method | Result | Notes |
|---|---|---|---|
| `user` / `admin` / `super_admin` role predicates | automated | **PASS** | `admin_test.dart` covers all three roles plus `isActive`, and genuinely executes. **This proves the client computes the role correctly — nothing more.** |
| Normal `user` cannot reach admin screens (UI) | automated | **PASS** | Covered by existing admin/UI tests. |
| Normal `user` cannot call admin-only RPCs directly | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. TEST_PLAN §2 explicitly requires *actually attempting the call*, "not just UI hiding". That is the assertion that matters here and it is unverifiable without the instance. |

**Section note.** The distinction TEST_PLAN draws in §2 is precisely the one that cannot be tested
right now. Passing role predicates and hidden UI are not authorization. **Treat §2 as unverified.**

### 3. Supabase security / RLS

**Every test in this section is BLOCKED. This is the section the release verdict turns on.**

| Test | Method | Result | Notes |
|---|---|---|---|
| User cannot read another user's `profiles` data | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. |
| User cannot read another user's `driver_availability` | — | **BLOCKED** | As above. Schema shows scoped policies (`auth.uid() = driver_id`); enforcement unverified. |
| User cannot read another user's `passenger_log` | — | **BLOCKED** | As above. |
| User cannot read another user's `notifications` | — | **BLOCKED** | As above. |
| **Cannot UPDATE another user's `ride_requests` (F2 regression)** | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. **This is the direct regression test for F2 and it is the most important single test in the plan.** |
| **Cannot DELETE another user's `ride_requests` (F2 regression)** | — | **BLOCKED** | As above. |
| Normal user cannot modify roles / admin data | — | **BLOCKED** | As above. |
| Normal user cannot modify `ride_completion_log` (audit) | — | **BLOCKED** | As above. Ties to §8. |
| Unauthorized ops return clear rejection, not silent no-op | — | **BLOCKED** | Requires live instance. Worth flagging: under PostgREST an RLS-denied UPDATE returns *success with zero rows affected*, not an error. Whether the app surfaces that correctly is unknown and untestable here. |
| Policy *shape* in the schema file | automated | **PASS** | `ride_requests_rls_test.dart` — 8/8. Asserts the blanket `FOR ALL ... USING (true)` policy is gone and four scoped per-command policies exist. **This is a static file assertion. It proves the repository is correct; it proves nothing about the running database.** |

**Section note — read this before deploying.** The live database still carries
`allow_all_authenticated_ride_requests` (`FOR ALL TO authenticated USING (true) WITH CHECK
(true)`). Until `DEPLOY_PENDING.sql` is applied, **any authenticated user can read, modify or
delete any other user's ride request through the REST API.** The F2 fix exists only in the
repository. The hole is open in production right now.

### 4. Ride integrity

| Test | Method | Result | Notes |
|---|---|---|---|
| Create ride request | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. |
| Join / accept a ride | — | **BLOCKED** | As above. Also depends on the F2 INSERT policy existing, which it does not yet in production. |
| Prevent joining a full ride (`seats_remaining` = 0) | — | **BLOCKED** | Requires live instance. See also §5 (negative seats under concurrency). |
| Prevent duplicate joining (F4 unique index regression) | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. The index does not exist in production yet. |
| Prevent unauthorized modification at ride-object level | — | **BLOCKED** | Ties to §3; same reason. |
| Driver/passenger relationships persist accept → confirm → complete | — | **BLOCKED** | Requires live instance for a real multi-step flow. |
| Status transitions move only through the legal machine | automated (static) | **PASS** | New: `ride_state_machine_test.dart` — 11/11. Each transition RPC guards its source status, each takes `FOR UPDATE` before deciding, and the guard provably precedes the UPDATE it protects. |
| Illegal transition `pending → completed` rejected | automated (static) | **PASS** | Same file, named test. Also asserts the `ride_completion_log` INSERT sits *behind* the guard, so a rejected completion cannot still write a CO2 record. |
| Status vocabulary consistent app ↔ database | automated (static) | **PASS** | Same file. All six statuses the app writes are permitted by the CHECK constraint — this is the F3 `'expired'` bug, now closed in the repo. |
| Model-level lifecycle state mapping | automated | **PASS** | Pre-existing `ride_flow_test.dart` (9 tests) and `cancellation_test.dart` (4 tests), all genuinely executed. |

**Section note.** The static tests are real regression protection — they fail loudly if a guard is
deleted or moved after its UPDATE, which is how this class of bug returns. But they assert SQL
*text*. Whether Postgres actually rejects `pending → completed` is unverified until the RPC runs.

### 5. Concurrency — core regression suite for F1

**Every runtime assertion in this section is BLOCKED. This is the second section the verdict turns on.**

| Test | Method | Result | Notes |
|---|---|---|---|
| Two concurrent `acceptRide` on same `ride_id` → exactly one succeeds | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. The race is resolved by `SELECT ... FOR UPDATE` inside Postgres; proving it needs a live instance and two genuinely concurrent sessions. **This is the headline assertion of F1 and it has never been executed.** |
| Loser receives explicit "already accepted" error, not silent success | automated (static, partial) | **BLOCKED** | The client path that produced the silent success is provably gone (`ride_accept_race_test.dart`, 14/14 — `acceptRide` makes no direct write to `ride_requests`, no `catch (_)` fallback). The RPC raises `already been accepted`, and the caller matches that text. But that the *loser* of a real race receives it is untested. |
| Two concurrent `assign_passengers` on same waiting passenger → one match | — | **BLOCKED** | Requires live instance. F4's `uq_active_match_per_passenger` is the backstop and is not deployed. |
| Retried request with same `client_request_id` cannot duplicate (F5) | automated (partial) | **BLOCKED** | The key generator is genuinely tested (`request_idempotency_test.dart`, 10/10 — valid v4 UUIDs, correct version/variant bits, 5000 draws without collision). The *collision rejection* depends on a Postgres unique index that does not exist in production yet. |
| `seats_remaining` never goes negative under concurrent assignment | — | **BLOCKED** | Requires live instance. Note the schema has `CHECK (seats_remaining >= 0)` on the column, so the floor exists structurally — but whether concurrent assignment hits it cleanly or errors is unverified. |

**Section note.** F1's client-side defect is genuinely and durably fixed — that part is proven.
What is unproven is the database behaviour F1 now depends on entirely. The fix moved the
correctness burden from Dart into Postgres, which is the right direction, but it means **the
current verification story is weaker than before the fix until the SQL is deployed**: the old
unsafe client guard is gone, and the RPC guard replacing it is not live.

### 6. Ride completion

| Test | Method | Result | Notes |
|---|---|---|---|
| Complete a valid (confirmed) ride | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. |
| Reject completion when not yet confirmed (status guard) | automated (static) | **BLOCKED** | The guard is genuinely present and correctly ordered (`ride_state_machine_test.dart`, `ride_accept_race_test.dart`). **But it lives only in `complete_ride_request`, which is not deployed — and F1 removed the Dart-side guard that used to enforce it.** So in production this rule is currently enforced *nowhere*. See the note below. |
| Prevent completing the same ride twice | — | **BLOCKED** | Requires live instance. Structurally the second attempt should fail the `<> 'confirmed'` guard (status is already `completed`), but this is unexecuted. |
| Exactly one `ride_completion_log` record per completion | — | **BLOCKED** | Requires live instance. Static check confirms the INSERT sits behind the status guard, so a rejected completion writes nothing; the "exactly one, not two" half needs runtime. |

**Section note — this is the most dangerous single gap in the current state.** F1 deliberately
moved the must-be-confirmed rule out of Dart and into the RPC, which is correct design. Until
`DEPLOY_PENDING.sql` is applied, the deployed `complete_ride_request` still has *no status check*,
and the Dart client no longer has one either. **Right now a completion call on an unconfirmed ride
would succeed and write a CO2 record for a trip nobody agreed to.** This is a regression window
created by shipping the app change ahead of the schema change, and it closes the moment the SQL
is applied. The app build and the schema must go out together.

### 7. Environmental calculations

This is the one section that could be substantially verified for real — the calculation is pure
Dart (`RideCompletionLog.calculateCo2Saved` / `calculateFuelSaved`).

| Test | Method | Result | Notes |
|---|---|---|---|
| CO2 for a normal ride (one passenger) | automated | **PASS** | 2.5 km × 0.12 × 1 = 0.30 kg. Pre-existing `reports_test.dart` plus new `environmental_boundaries_test.dart`. |
| Multiple passengers in one completion | automated | **PASS** | Scales linearly; verified at 3 and 4 passengers, and as an explicit ×4 relationship. |
| Zero distance | automated | **PASS** | Returns 0.0. |
| Zero passengers | automated | **PASS** | Returns 0.0 — correct: the driver drove anyway, nothing was saved. |
| Very large distance (1e6 km) | automated | **PASS** | Stays finite, no overflow. |
| Very small distance (0.001 km) | automated | **PASS** | Does not underflow to zero. |
| **Negative distance → negative CO2 saving** | automated | **FIXED** | **Failed on first execution: returned −0.3 kg.** See below. |
| **Negative passenger count → negative CO2 saving** | automated | **FIXED** | **Failed on first execution: returned −0.8999… kg.** |
| **Negative distance → negative fuel saving** | automated | **FIXED** | **Failed on first execution: returned −0.2 L.** |
| `fromJson` defaulting (distance, passenger count, fuel) | automated | **PASS** | Defaults of 2.5 km / 0.12 apply; `passenger_count` derives from `passenger_ids`; `liters_fuel_saved` computes when the column is absent. |
| Duplicate completion cannot double-count savings | — | **BLOCKED** | Ties to §6; requires live instance. |

**Defect found and fixed during this run.** `calculateCo2Saved` and `calculateFuelSaved` were
straight multiplications with no input validation, so a negative distance, emission factor, or
passenger count produced a **negative "saving"**. That is not cosmetic: these values feed
`ride_completion_log` (the audit trail) and the public leaderboard, so a negative figure silently
*subtracts* from a driver's lifetime total rather than failing visibly. `distance_km` and
`emission_factor_kg_per_km` are admin-editable through `app_config`, so a negative value is
reachable by configuration, not only by a bug.

Per TEST_PLAN's rule — *"If a test fails, the fix is in the app or database, not in loosening the
test"* — the fix was applied to `lib/core/models/ride_completion_log.dart`: non-positive inputs now
return `0.0`. All three tests pass on re-run, and every pre-existing CO2/fuel test still passes.

**The equivalent SQL path was deliberately NOT changed.** `complete_ride_request` computes
`v_co2 := (v_dist * v_emiss * 1.0)` with the same absence of validation, and that is the path that
actually writes the persisted audit record. It is left alone for two reasons: `DEPLOY_PENDING.sql`
is about to be applied and changing it underneath that review would be reckless, and the SQL change
cannot be tested from here. **This is an open defect, recorded in Coverage gaps below.**

### 8. Audit trail

| Test | Method | Result | Notes |
|---|---|---|---|
| Completion creates correct immutable `ride_completion_log` record | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. |
| Record has accurate driver / passenger / distance / CO2 fields | automated (model only) | **BLOCKED** | `RideCompletionLog` serialisation round-trips correctly (`admin_test.dart`, `reports_test.dart`, and new boundary tests — all PASS). That the *database* writes those values correctly is unverified. See the §7 note: the SQL CO2 computation still lacks the input validation the Dart side just gained. |
| Unauthorized users cannot alter/delete audit history | — | **BLOCKED** | Ties to §3. Requires live instance. |
| Historical records stay consistent after later profile/ride changes | — | **BLOCKED** | Requires live instance and time-separated operations. Structurally `ride_completion_log` stores denormalised values (`distance_km`, `emission_factor_kg_per_km`, `kg_co2_saved`, `passenger_ids`) rather than recomputing from joins, which is the right shape for immutability — but "immutable by construction" is a reading, not a test. |

### 9. Account deactivation

| Test | Method | Result | Notes |
|---|---|---|---|
| Deactivate a user | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. |
| Deactivated account cannot create request / accept ride | — | **BLOCKED** | Requires live instance. Enforcement is real but indirect — see the section note. |
| Deactivated **driver** path specifically | — | **BLOCKED** | As above. The two paths are not distinguished by the deactivation mechanism, which acts at the session level, so both are covered by the same control. |
| Deactivated **passenger** path specifically | — | **BLOCKED** | As above. |
| Reactivation restores access | — | **BLOCKED** | Requires live instance. `admin_set_user_active` clears both `is_active` and `banned_until`, so the mechanism is symmetric. |
| `isActive` model parsing | automated | **PASS** | `admin_test.dart` covers active and inactive profiles. |
| Deactivation privilege rules | automated (static) | **PASS** | Verified by reading `admin_migration.sql`: super admins cannot be deactivated, and only a super admin may deactivate another admin. Both guards precede the UPDATE. |

**Section note — correcting an earlier reading.** My first pass through `lib/` and
`supabase_schema.sql` found no enforcement of `is_active` and I nearly recorded §9 as an
unimplemented requirement. That was wrong, and checking rather than asserting is what caught it:
`is_active` is added to `profiles` by **`database/admin_migration.sql`**, not by the main schema
file, which is why it did not appear in the first search. Deactivation is properly implemented
there.

Enforcement does not work the way §9 implies, though, and the difference matters. No RPC or policy
consults `is_active` — instead `admin_set_user_active` also sets
`auth.users.banned_until = '2099-01-01'`, and GoTrue refuses to issue a session for a banned user.
So a deactivated account is blocked at authentication, before any ride code runs. That is a sound
design and stronger than per-RPC checks would be.

**One real gap it implies, which no test in §9 as written would catch:** banning prevents *new*
sessions, but an already-issued JWT stays valid until it expires. A user deactivated mid-session
can keep acting until their token lifetime runs out. Whether that window is acceptable is a
product decision; it is worth knowing before someone assumes deactivation is instant.

### 10. Failure handling

| Test | Method | Result | Notes |
|---|---|---|---|
| Simulated network failure during login | — | **BLOCKED** | No mocking library in `dev_dependencies` (only `flutter_test`, `flutter_lints`), and no injection seam — `RideRepository` reaches `SupabaseService.instance.client` directly, so no fake client can be substituted without a production refactor. |
| …during ride creation / accept / completion / cancellation | — | **BLOCKED** | Same reason. |
| UI never reports success when the DB operation failed | automated (partial) | **PASS** | Genuinely improved by F1 and directly asserted: `ride_accept_race_test.dart` proves none of the four mutation methods retains a `catch (_)` swallow-and-degrade fallback, which was precisely the "UI says success, database disagrees" mechanism. The general case across all screens is untested. |
| Retry does not create duplicates (ties to F5) | automated (partial) | **BLOCKED** | Key generation genuinely tested; collision rejection requires the live index. |

**Section note.** §10 is blocked by test *infrastructure*, not only by the missing database. Adding
a mocking library and an injection seam for the Supabase client would make most of this section
genuinely testable without any live instance. That is a real, self-contained piece of work and it
belongs in the F6 hardening discussion (it overlaps H1/H3 in `progress/06_hardening_proposal.md`).

### 11. Mobile lifecycle

| Test | Method | Result | Notes |
|---|---|---|---|
| Kill/restart mid-accept | — | **BLOCKED** | Requires a device or emulator plus a live backend. No integration test harness exists in this project (`integration_test/` is absent, and the package is not a dependency). |
| Kill/restart mid-confirm | — | **BLOCKED** | As above. |
| Kill/restart mid-completion | — | **BLOCKED** | As above. |
| DB is source of truth on relaunch (not stale local state) | — | **BLOCKED** | As above. |
| Session and ride state recover after relaunch | — | **BLOCKED** | As above. |

**Section note.** §11 is the only section blocked by *two* independent missing pieces: no live
database and no integration-test infrastructure. Even with Supabase deployed, none of §11 could run
tonight without adding `integration_test` and a device target.

### 12. Server-side expiry — regression test for F3

| Test | Method | Result | Notes |
|---|---|---|---|
| Accepted request past its 5-min deadline reverts to `pending` with no client running | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. **Blocked twice over:** the expiry job does not exist in production, and `pg_cron` is not known to be enabled at all (F3 is `NEEDS_DECISION` for exactly this reason). |
| Expiry wrapper calls both expiry RPCs | automated (static) | **PASS** | `expiry_scheduling_test.dart` — 12/12. `run_ride_request_expiry()` invokes both `expire_unconfirmed_ride_requests()` and `expire_past_slot_ride_requests()`. |
| A cron job is registered, idempotently, guarded on `pg_cron` | automated (static) | **PASS** | Same file. Schedule is guarded so a missing extension raises a NOTICE instead of aborting the migration. |
| Expiry entry point is not client-callable | automated (static) | **PASS** | `REVOKE ALL ... FROM authenticated` asserted. |
| Status vocabulary permits `'expired'` | automated (static) | **PASS** | The F3 constraint bug — `expire_past_slot_ride_requests()` has raised on **every call it has ever received** because the CHECK constraint forbade the status it writes. Fixed in the repo; **still broken in production**. |

**Section note.** TEST_PLAN §12 asks to simulate the deadline passing "at the database/RPC level
directly". That is precisely what cannot be done without the database. Also worth stating plainly:
even after `DEPLOY_PENDING.sql` is applied, **F3 may still silently not work** — the scheduling
block is deliberately non-fatal, so it succeeds while scheduling nothing if `pg_cron` is absent.
Post-condition 3 in the deploy script is the only way to tell.

### 13. Vehicle capacity constraint — regression test for F4

| Test | Method | Result | Notes |
|---|---|---|---|
| `seats_offered` > vehicle capacity is rejected | — | **BLOCKED** | Requires DEPLOY_PENDING.sql to be applied to live Supabase first — verified at code/schema level only, not runtime. The trigger does not exist in production. |
| Driver with no registered vehicle is not blocked | — | **BLOCKED** | As above. This is the negative case most likely to be wrong in a way that locks real accounts out, and it is unverified. Smoke test is written out as post-condition 8. |
| Trigger shape, timing and ordering | automated (static) | **PASS** | `defense_in_depth_test.dart` — 9/9. `BEFORE INSERT OR UPDATE OF seats_offered`, compares against `vehicles.capacity`, and the missing-vehicle escape provably precedes the capacity check. |
| Unique active-match index is partial | automated (static) | **PASS** | Same file. `WHERE status = 'active'`, so cancelled/completed history does not block re-matching. |

---

## Whole-suite sanity pass

Run after all sections, per TEST_PLAN's closing instruction.

| Command | Result |
|---|---|
| `flutter test` | **152/152 passing**, 0 failures |
| `flutter analyze` | 70 issues, **0 errors** |

Suite growth across this work: 74 (baseline, before any fix) → 127 (after F1–F5) → **152** (after
this test pass added §4 state machine and §7 environmental boundaries).

The 70 analyze issues are unchanged from the pre-fix baseline and none are errors — they are
`withOpacity` deprecations, `prefer_const` lint suggestions, and two unused imports in the
pre-existing `test/unit/admin_test.dart`. No issue was introduced by any fix or test in this work.

**`flutter test` exiting 0 is not the verdict.** TEST_PLAN says so explicitly, and in this run it
would be actively misleading: 152 passing tests coexist with an RLS hole that is open in
production right now.

---

## Existing tests found insufficient

Per TEST_PLAN's required section — pre-existing tests that looked like coverage but did not assert
the right thing.

**1. `test/audit_supabase_test.dart` — asserts nothing about the schema.** Despite the name, it
declares a hardcoded list of twelve table-name strings and asserts that list contains what it was
just written to contain (`expect(tables.length, equals(12))`). It never reads
`database/supabase_schema.sql` and would pass unchanged if every table were dropped. Left in place
(TEST_PLAN forbids deleting tests), but it provides no audit coverage. The real schema assertions
now live in `ride_requests_rls_test.dart`, `expiry_scheduling_test.dart`,
`defense_in_depth_test.dart` and `ride_state_machine_test.dart`, all of which parse the actual file.

**2. CO2/fuel tests covered only the happy path.** `reports_test.dart` and `admin_test.dart` test
normal distances and passenger counts thoroughly, but never zero, negative, or extreme inputs —
which is why the negative-savings defect in §7 survived until now. Added
`environmental_boundaries_test.dart`; the gap it closed was a real defect, not a theoretical one.

**3. No test asserted the ride state machine.** `ride_flow_test.dart` and `cancellation_test.dart`
test model-level status *mapping* (does `isConfirmed` return true for `'confirmed'`), which is not
the same as testing that illegal *transitions* are rejected. TEST_PLAN §4 asks specifically about
`pending → completed`. Added `ride_state_machine_test.dart`, including that the guard provably
precedes the UPDATE it protects and that the CO2 log write sits behind it.

**4. A near-miss worth recording about my own tests.** The first version of
`ride_requests_rls_test.dart` reported the F2 hole as still open. The schema documents the removed
policy in a `--` comment so future readers know what was taken out, and the assertions were
matching that prose rather than executable SQL. All schema-shape tests now strip `--` comments
first. A security test that reads comments as policy would pass happily against a schema where the
hole had been re-added in a commented-out block.

---

## Coverage gaps

Things in TEST_PLAN that could not be tested, kept strictly separate from real failures.

**Gap 1 — no live database (the dominant cause).** Blocks all of §3, §5, §6, §11, §12, §13 and most
of §1, §2, §4, §8, §9, §10. The F1–F5 changes exist only in the repository. Everything whose real
assertion is *"the database rejects this"* is unverifiable. **Resolved by applying
`database/DEPLOY_PENDING.sql` and running its eleven post-conditions**, which include the
deliberate-violation smoke tests for F1's status guard, F2's RLS scoping, F4's two constraints and
F5's idempotency index. Those post-conditions are the runtime half of this test plan.

**Gap 2 — `pg_cron` state unknown (§12).** Blocked independently of Gap 1. F3 remains
`NEEDS_DECISION`: nobody has confirmed the extension can be enabled on this plan tier. Applying the
deploy script will *appear* to succeed either way.

**Gap 3 — no mocking library or injection seam (§10).** `dev_dependencies` has only `flutter_test`
and `flutter_lints`, and `RideRepository` reaches `SupabaseService.instance.client` directly, so no
fake client can be substituted. This blocks network-failure simulation *even with a live database*.
Unlike Gaps 1 and 2, this is fixable entirely in the repo and would make a large part of §10
genuinely testable. Overlaps H1/H3 in `progress/06_hardening_proposal.md`.

**Gap 4 — no integration-test harness (§11).** `integration_test/` does not exist and the package
is not a dependency. All of §11 needs a device or emulator plus a live backend.

**Gap 5 — open defect: the SQL CO2 calculation still lacks input validation.** The Dart side was
fixed during this run (§7). `complete_ride_request` computes
`v_co2 := (v_dist * v_emiss * 1.0)` with no validation, and **that is the path that writes the
persisted audit record** — so the defect found in §7 is only half fixed. Deliberately not changed:
`DEPLOY_PENDING.sql` is queued for review and altering it underneath that would be reckless, and
the change could not be tested from here. **This should be fixed before or alongside the next
schema deployment.** Suggested guard, for review rather than blind application:

```sql
IF v_dist <= 0 OR v_emiss <= 0 THEN
    v_co2 := 0;
ELSE
    v_co2 := (v_dist * v_emiss * 1.0)::NUMERIC(10, 4);
END IF;
```

**Gap 6 — deactivation revocation window (§9).** Deactivation bans the account so no *new* session
can be issued, but an already-issued JWT remains valid until expiry. Not a test failure; a design
characteristic that §9 as written would not surface. Flagged for a product decision.

**Gap 7 — F2 will narrow two client sweeps, untested.** `autoExpirePastRequests()` and the expiry
loop in `expireUnconfirmedMatches()` currently update other users' rows. After F2 they will only
affect the caller's own. Both are wrapped in `catch (_) {}`, so the narrowing will not surface as
an error — it will simply do less, silently. F3's cron job is the intended replacement, which makes
the F3 `pg_cron` decision more load-bearing than it first appears.

---

## Final verdict

### Release verdict: **NOT SAFE**

**This is a code-level verdict only. It is NOT a runtime-verified verdict, and it must not be read
as a release-ready confirmation.** The live database deployment (`database/DEPLOY_PENDING.sql`) has
not happened. No test in this run touched a running Postgres instance.

**Justification in one sentence,** as the template requires: the repository is in good order and
all 152 automated tests pass, but every P0 category in TEST_PLAN — authentication, authorization,
RLS, ride integrity, duplicate booking, ride completion and audit integrity — is **unverified at
runtime**, and two P0 defects are live in production right now.

**Why NOT SAFE, specifically.** TEST_PLAN's P0 rule concerns *failures*. Strictly read, this run
produced one genuine failure (§7 negative savings, now FIXED) and no others — every remaining P0
item is BLOCKED rather than FAILED. It would be technically defensible to record SAFE on that
reading. **That would be wrong, and here is the concrete reason rather than an abstract one:**

1. **The F2 RLS hole is open in production.** `allow_all_authenticated_ride_requests`
   (`FOR ALL ... USING (true) WITH CHECK (true)`) is still the live policy. Any authenticated user
   can read, modify or delete any other user's ride request through the REST API. This is a live
   P0 security defect, not a pending improvement.

2. **The must-be-confirmed guard is currently enforced nowhere.** F1 correctly moved it out of Dart
   and into `complete_ride_request` — but the app change is committed while the schema change is
   not deployed. In this exact intermediate state a completion call on an unconfirmed ride would
   succeed and write a CO2 record for a trip nobody agreed to. **The current state is worse than
   before F1 for this one rule**, and it stays that way until the SQL lands.

A verdict of SAFE while both of those are true would be exactly the false assurance this plan was
written to prevent.

### What would change the verdict

1. Apply `database/DEPLOY_PENDING.sql` — after running the two pre-checks it documents (duplicate
   active matches; any `ride_requests.status` outside the allowed vocabulary).
2. Run all eleven post-conditions and **read the output** — particularly post-condition 3, since
   the `pg_cron` block succeeds while scheduling nothing.
3. Ship the app build together with the schema, not before it (see point 2 above).
4. Re-run TEST_PLAN §3, §5, §6, §12 and §13 against the live instance. **Those five sections are
   the actual verification of F1–F5**; everything in this document is preparation for them.
5. Fix Gap 5 (SQL CO2 validation) before or with the next schema deployment.

Until at least steps 1, 2, 3 and 4 are complete, **F1–F5 should be treated as written and reviewed
but not proven.**
