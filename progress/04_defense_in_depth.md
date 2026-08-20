# Fix 4: Defense-in-depth constraints

## What was wrong

Two invariants the application relies on had no enforcement below the application layer. Both
were correct in `assign_passengers()` and in the UI, and both would have stayed correct right
up until any second code path, retry, or direct API call touched the same tables.

1. **A passenger could hold two active matches in the same session.** `assign_passengers()` is
   supposed to prevent it, but nothing outside that function did.
2. **A driver could offer more seats than their vehicle holds.** `driver_availability.seats_offered`
   was validated only in the UI. A stale client or a direct API call could offer more seats than
   exist — which then over-fills the priority queue and strands passengers who were told they
   had a seat.

## What changed

**File: `database/supabase_schema.sql`** — new section 20:

- **`uq_active_match_per_passenger`** — a partial unique index on
  `ride_matches (session_id, passenger_id) WHERE status = 'active'`. Partial matters: cancelled
  and completed rows stay in the table as history, so a total unique index would forbid a
  passenger from ever being re-matched in a session after a cancellation.
- **`trg_validate_seats_offered()` + `trg_driver_availability_seats`** — a
  `BEFORE INSERT OR UPDATE OF seats_offered` trigger rejecting `seats_offered > vehicles.capacity`.
  A trigger rather than a CHECK constraint because the limit lives in another table, which CHECK
  cannot reference. **A driver with no vehicle row passes**, per the plan — the missing-vehicle
  escape returns before the capacity check, so the README's test admin account is not locked out
  of creating availability. There is a test asserting that ordering specifically, because
  reversing it would fail closed and silently break those accounts.

**File: `database/DEPLOY_PENDING.sql`** — F4 section added, plus a pre-check (below) and two new
post-conditions covering the index, the trigger, and deliberate-violation smoke tests.

**File: `test/unit/defense_in_depth_test.dart`** (new) — 9 tests.

## The one statement here that can fail on real data

`CREATE UNIQUE INDEX` fails outright if existing rows already violate it. Every other statement
in `DEPLOY_PENDING.sql` fails only on a mistake; this one fails on history. If any passenger
already holds two active matches in one session — which is exactly the bug this index prevents,
so it is not unlikely — the index will not create, and if the script was wrapped in
`BEGIN/COMMIT` the whole migration aborts with it.

`DEPLOY_PENDING.sql` therefore carries a detection query before the index, and a *commented-out*
remediation that keeps the earliest active match per `(session, passenger)`. I deliberately did
not automate that: it silently picks a winner, and the losing driver may already have collected
the passenger. Which match is real is a judgement call about physical events, not something to
resolve in a migration script.

## How it was verified

`flutter analyze` — 70 issues, 0 errors, identical to baseline. `flutter test` — 117/117
(108 before this fix + 9 new).

The new tests were confirmed to fail against the pre-F4 schema: **all 9 fail**, restored from
`HEAD` and re-run before putting the fix back.

## Risk / side effects

**The plan asks for these to be tested by deliberately violating them, and that has not been
done.** Step 3 of F4 says to confirm both constraints reject correctly using an SQL client or a
Dart test. Neither is possible from here: no live database, and a Dart test cannot exercise a
Postgres index. The Dart tests assert SQL shape only. **The actual rejection behaviour of both
constraints is unverified.** The deliberate-violation statements are written out ready to run as
post-conditions 7 and 8 in `DEPLOY_PENDING.sql` — including the negative case that a driver with
no vehicle is *not* blocked, which is the one most likely to be wrong in a way that matters.

**Existing `driver_availability` rows are not retroactively validated.** The trigger fires on
INSERT and on `UPDATE OF seats_offered`, so a row already over capacity survives untouched until
it is next written. A query to find them is included in `DEPLOY_PENDING.sql`. Retroactively
correcting them would mean silently reducing seat offers that passengers may already have been
matched against, so it is left as a deliberate manual step.

**The seats trigger is `SECURITY DEFINER`.** It has to read `public.vehicles` for a driver who
may not own the row being read, and RLS on `vehicles` would otherwise hide it and make the
trigger silently pass everything. That is the correct choice here, but it means the function
runs with elevated privilege — it only reads one column and raises, so the exposure is minimal.

**Not deployed**, like everything before it. `DEPLOY_PENDING.sql` now covers F1 through F4.

## Status: DONE
