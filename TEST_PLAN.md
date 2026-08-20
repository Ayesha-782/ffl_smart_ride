# FFL Smart Ride — Critical Pre-Release Test Suite
**For: Claude Code**
**Run this only after `progress/SUMMARY.md` shows F1–F5 in FIX_PLAN.md are DONE.**

---

## Ground rules

- Inspect the entire repo first (`lib/`, `database/`, `supabase/functions/`, existing `test/`) before writing anything. Reuse and extend existing tests rather than duplicating them.
- Clearly separate: **unit**, **widget**, **integration**, and **security/database (RLS)** tests, in the file/folder structure.
- Mock external/network dependencies where appropriate; for RLS/security tests, test actual database authorization behavior against the real (test) Supabase project where the project configuration permits it.
- Do not weaken production security rules or change application behavior just to make a test pass. If a test fails, the fix is in the app or database — not in loosening the test.
- Do not delete existing tests.
- Prefer deterministic tests. Every failing test must be investigated, not skipped or ignored.
- Test **one item at a time**, in the order below. After each numbered item, immediately append its result to `TEST_RESULTS.md` using the template at the bottom of this file — do not batch results up and write them all at the end.
- After all items are done, run `flutter test` (and any other relevant command, e.g. targeted integration test runners) one final time as a whole-suite sanity pass, and record that separately too.

---

## 1. Authentication
- Valid login
- Invalid login (wrong password, unknown email)
- Session persistence across app restart
- Logout (session actually cleared, protected calls fail afterward)
- Unauthorized access (no session → protected screens/calls are blocked)

## 2. Role-based authorization
- `user`, `admin`, `super_admin` — each role can access only its permitted functionality
- A normal `user` cannot reach admin screens or admin-only RPCs via direct navigation or a direct API/RPC call (not just UI hiding — actually attempt the call)

## 3. Supabase security / RLS
- A user cannot read another user's protected data they're not entitled to (check `profiles`, `driver_availability`, `passenger_log`, `notifications` scoping specifically)
- A user cannot modify another user's `ride_requests` row directly via the API — **this is the direct regression test for FIX_PLAN F2**. Explicitly attempt: another user's request UPDATE, another user's request DELETE, and confirm both are rejected by RLS, not just by client-side checks.
- A normal user cannot modify roles, admin data, or `ride_completion_log` (audit) records
- Unauthorized database operations return a clear rejection, not a silent no-op

## 4. Ride integrity
- Create ride request
- Join / accept a ride
- Prevent joining a full ride (driver's `seats_remaining` = 0)
- Prevent duplicate joining (same passenger matched twice in one session — regression test for FIX_PLAN F4's unique index)
- Prevent unauthorized modification (covered further in §3, but re-verify at the ride-object level)
- Verify correct driver/passenger relationships persist through accept → confirm → complete
- Verify ride status transitions only move forward through the legal state machine (`pending → accepted → confirmed → completed`, and cancellation paths) — attempt illegal transitions (e.g. `pending → completed` directly) and confirm rejection

## 5. Concurrency — **this is the core regression suite for FIX_PLAN F1**
- Simulate two users calling `acceptRide` on the same `ride_id` at effectively the same time. Assert: exactly one succeeds, the other receives an explicit "already accepted" error (not a silent success with no DB effect).
- Simulate two drivers' `assign_passengers` calls both targeting the same waiting passenger in the same session concurrently. Assert only one match is created.
- Verify duplicate/retried requests (same `client_request_id` per FIX_PLAN F5) cannot create duplicate `ride_requests` rows.
- Verify the database never allows `seats_remaining` to go negative under concurrent assignment.

## 6. Ride completion
- Complete a valid (confirmed) ride
- Reject invalid completion (ride not yet confirmed — status guard)
- Prevent completing the same ride twice
- Verify exactly one `ride_completion_log` record is created per completed ride, not zero and not more than one

## 7. Environmental calculations
- Verify CO2 and fuel-saving calculations for a normal ride (one passenger)
- Test multiple passengers in one completion
- Test zero/invalid distance input handling
- Test boundary values (very small / very large distance, zero seats, etc.)
- Verify duplicate completion attempts cannot double-count environmental savings (ties to §6)

## 8. Audit trail
- Verify ride completion creates the correct immutable `ride_completion_log` record with accurate driver/passenger/distance/CO2 fields
- Verify unauthorized users cannot alter or delete audit history (ties to §3 RLS test on `ride_completion_log`)
- Verify historical records remain consistent after later, unrelated ride or profile changes (e.g. driver later edits their profile — old completion records shouldn't silently change)

## 9. Account deactivation
- Deactivate a user
- Verify a deactivated account cannot perform operations requiring an active account (create request, accept ride, etc.)
- Test both a deactivated driver and a deactivated passenger specifically (different code paths)
- Test reactivation restores normal access

## 10. Failure handling
- Simulate a Supabase/network failure during: login, ride creation, joining/accepting, completion, cancellation
- Confirm the UI never reports success when the underlying database operation actually failed
- Verify retry behavior after a failure does not create duplicate records (ties directly to FIX_PLAN F5)

## 11. Mobile lifecycle
- Kill/restart the app mid-operation (during accept, during confirm, during completion)
- Verify the database remains the source of truth on relaunch — app state reflects DB, not stale local state
- Verify session and ride state recover correctly after relaunch

## 12. (Added) Server-side expiry — regression test for FIX_PLAN F3
- Create an "accepted" ride request, let its 5-minute confirmation deadline pass **without any client calling the app** (simulate this at the database/RPC level directly, not by keeping a Flutter app open), and confirm the scheduled job (or the RPC if a cron test harness isn't feasible) correctly reverts it to `pending` on its own.

## 13. (Added) Vehicle capacity constraint — regression test for FIX_PLAN F4
- Attempt to set `seats_offered` greater than the driver's registered vehicle capacity and confirm it's rejected.
- Confirm a driver with no registered vehicle (e.g. admin test account) is not incorrectly blocked.

---

## `TEST_RESULTS.md` — required output format

Create this file and append one entry per test **as you complete it**, using this exact structure so the final file is easy to read:

```markdown
# FFL Smart Ride — Test Results
Run date: <date>
Branch/commit tested: <branch>, <commit hash>

## Summary
| Metric | Count |
|---|---|
| Total tests run | |
| Passed | |
| Failed | |
| Skipped/Blocked | |
| P0 (release-blocking) failures | |

**Release verdict: SAFE / NOT SAFE** — one sentence justification.
(A failure in auth, authorization, RLS, ride integrity, duplicate booking, ride completion, CO2/fuel calculation, or audit integrity is automatically a P0 and automatically makes the verdict NOT SAFE, regardless of how many other tests passed.)

---

## Results by section

### 1. Authentication
| Test | Method | Result | Notes |
|---|---|---|---|
| Valid login | automated | PASS | |
| Invalid login | automated | PASS | |
| ... | | | |

(repeat this table format for each of the 13 sections above, in the same order)

---

## Existing tests found insufficient
(list any pre-existing tests in test/ that looked like they covered something but didn't actually assert the right thing, and what you changed/added instead)

## Coverage gaps
(anything in this plan you could not test — e.g. no pg_cron test harness available — and why, clearly separate from a real failure)
```

Do not claim the app is release-ready merely because `flutter test` exits with 0 failures — the verdict must be based on the P0 criteria above, stated explicitly.
