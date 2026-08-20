# Fix 1: Close the ad-hoc ride-request double-booking race

## What was wrong

`acceptRide()` accepted a ride by reading the row, checking `status`/`driver_id` in Dart, then
issuing a separate `UPDATE` — instead of calling the `accept_ride_request` RPC that already
existed for exactly this purpose. Two drivers could pass the check in the gap between read and
write. The `UPDATE` was guarded by `.eq('status', 'pending')` so only one actually landed, but
the code never inspected how many rows it affected, so the losing driver's call returned
normally and their UI showed "Lift offered!". Two drivers each believed they had the ride while
the database recorded one.

Three sibling methods — `confirmRide()`, `completeRide()`, `cancelRideOffer()` — called the
correct RPC but wrapped it in `try { rpc } catch (_) { client-side write }`. Any RPC failure
silently degraded to the unsafe path. In `confirmRide()` that fallback was worse than a
duplicate: it wrote `status = 'confirmed'` directly, skipping the 5-minute deadline check the
RPC enforces, so an expired offer could still be confirmed whenever the RPC errored.

## What changed

- **File: `lib/features/rides/data/ride_repository.dart`** — `acceptRide()` now calls
  `accept_ride_request` as its only path; the read-check-write and the duplicate notification
  insert are gone (the RPC inserts that notification itself, so keeping it would have sent two
  per accept). `confirmRide()`, `completeRide()` and `cancelRideOffer()` lost their `catch (_)`
  fallbacks and their now-redundant client-side pre-checks; RPC errors surface to the caller.
  Net −142 lines. `cancelRideOffer()` previously did `if (user == null) return;` — a silent
  no-op on a logged-out call — and now throws, consistent with the other three.

- **File: `database/supabase_schema.sql`** — two genuine bugs in the RPCs this change now
  depends on, both found by reading the functions rather than trusting the plan's claim that
  they were usable as-is:
  - `complete_ride_request` never checked status. The "ride must be confirmed" rule existed
    *only* in the Dart client, so removing the client path would have dropped the guard
    entirely — and a direct API call could already complete an unconfirmed ride *and* write a
    CO2 saving row for a trip nobody agreed to. Added the status guard plus `FOR UPDATE`.
  - `cancel_ride_offer` returned a row to `pending` without clearing `confirmation_deadline`,
    leaving the previous driver's expiry timestamp attached to an offer that no longer exists.
    The Dart fallback had cleared it; the RPC did not. Added, plus `FOR UPDATE`.

- **File: `test/unit/ride_accept_race_test.dart`** (new) — 14 regression tests.

## How it was verified

`flutter analyze` — 70 issues, identical to the pre-change baseline; 0 errors. Every remaining
issue is a pre-existing `withOpacity` deprecation, `prefer_const`, or unused import in
`test/unit/admin_test.dart`. None are mine and none were introduced by this change.

`flutter test` — 88/88 pass (74 pre-existing + 14 new). Baseline before this fix was 74/74, so
nothing regressed.

**The regression tests were verified to actually fail.** A guard test that cannot fail is
worthless, so I restored the pre-fix versions of both files from `HEAD`, re-ran the new suite,
and confirmed **12 of the 14 fail** against the old code before restoring the fixes. The two
that pass on both are legitimate: old `acceptRide` had no `catch (_)` (its bug was a different
shape), and `accept_ride_request` already had `FOR UPDATE`.

Callers were checked for breakage. All four methods kept their existing named parameters, so
`available_requests_screen.dart` and `home_screen.dart` compile unchanged. `_acceptRide` in
`available_requests_screen.dart:138` branches on the error text containing
`already been accepted`; the RPC raises `This ride request has already been accepted by another
colleague`, so the conflict dialog still fires.

## Risk / side effects

**The actual race is not covered by an automated test, and cannot be from here.** It is resolved
inside Postgres by `SELECT ... FOR UPDATE`; proving it needs a live database and two concurrent
sessions. This project has no mocking library (`dev_dependencies` is just `flutter_test` and
`flutter_lints`) and I have no Supabase credentials, and I did not add a dependency for it. The
new tests therefore guard the thing that actually regressed — the *shape* of the client, i.e.
that no code path bypasses the locking RPC — not the lock itself. **A true two-driver concurrent
accept against a real instance belongs in the integration pass; it is the single most valuable
check still missing on this fix.**

`p_ride_id` is the only argument these RPCs take, so `passengerId` and `driverId` are no longer
read by `confirmRide`/`completeRide`/`cancelRideOffer`. They are retained in the signatures for
source compatibility rather than churning every call site; they are documented as such.

Notification wording shifts slightly. The Dart code had richer fallbacks for a driver whose
`full_name` was empty or literally `"colleague"` (it would fall back to `employee_id`); the RPC
just does `COALESCE(full_name, 'A colleague')`, which does not catch an empty string. Cosmetic
only, and the plan says not to rewrite SQL without a genuine bug — this is not one, so I left it.

The `complete_ride_request` status guard is **stricter than production behaviour was**. Any
existing flow relying on completing a non-`confirmed` ride will now fail loudly. That is the
intent, but it is a behaviour change worth knowing before deploying the schema.

**The SQL changes are not yet applied to any live database.** They are edits to
`database/supabase_schema.sql` only. Someone with dashboard access must run them, and until
then the deployed `complete_ride_request` still lacks the status guard while the Dart client no
longer enforces it — so this fix is only half in force until the schema is deployed.

## Status: DONE
