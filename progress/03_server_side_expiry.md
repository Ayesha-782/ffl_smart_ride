# Fix 3: Server-side expiry

## What was wrong

`expire_unconfirmed_ride_requests()` and `expire_past_slot_ride_requests()` existed as RPCs but
nothing ever called them on a schedule. Expiry happened only as a side effect of a user opening
a screen that called `getAvailableRequests()`. If nobody opened that screen, an unconfirmed
`accepted` ride stayed stuck indefinitely — holding a request out of the open queue, with a
driver attached who never confirmed, and no path back without human traffic.

**A second, worse problem surfaced while implementing this.**
`expire_past_slot_ride_requests()` writes `status = 'expired'`, but the table's CHECK constraint
permitted only `('pending', 'accepted', 'confirmed', 'completed', 'cancelled')`. The RPC has
therefore **raised on every call it has ever received** — it has never successfully expired
anything. Scheduling it as the plan describes, without touching the constraint, would have
produced a cron job that failed every single minute, forever, while appearing "done".

The same constraint violation is why `RideRepository.autoExpirePastRequests()` has never worked
either; its error is swallowed by an empty `catch (_) {}`. I flagged that one during F2 and it
turns out to be the same root cause.

## What changed

**File: `database/supabase_schema.sql`**

- Widened the `ride_requests_status_check` constraint to include `'expired'`. This is the right
  direction rather than changing the RPC to write some other status: the application has always
  treated `'expired'` as real — `RideRequest.isExpired` tests `status == 'expired'`
  (`lib/core/models/ride_request.dart:122`) and the UI renders a dedicated `'expired'` status
  chip (`available_requests_screen.dart:514`). The constraint was simply never updated when the
  feature landed.
- Added `run_ride_request_expiry()`, a `SECURITY DEFINER` wrapper calling both expiry RPCs and
  returning the counts, so there is one cron job and one place to add future sweeps. `REVOKE`d
  from `PUBLIC` and `authenticated` — it is a maintenance entry point, not client API.
- Added a `pg_cron` schedule, `ride_request_expiry`, running every minute.

**File: `database/DEPLOY_PENDING.sql`** (new, as requested) — consolidates every database change
from F1, F2 and F3 into one runnable script, ordered so the status constraint is widened before
the F2 DELETE policy that references `status`, with `DROP ... IF EXISTS` / `CREATE OR REPLACE`
guards throughout so it is safe to re-run. Ends with post-condition queries, because a clean run
does not by itself prove the fixes are in force (see below).

**File: `test/unit/expiry_scheduling_test.dart`** (new) — 12 tests, 6 of which guard
`DEPLOY_PENDING.sql` against drifting out of sync with the schema. That file is the only artefact
anyone will actually run, so drift is the most likely way these fixes get half-deployed.

## ACTION REQUIRED — what must be checked in the Supabase dashboard

Written under the assumption that **pg_cron is not enabled**, per your instruction. Nothing here
has been verified against a live instance.

1. **Check whether pg_cron exists:**
   ```sql
   SELECT * FROM pg_extension WHERE extname = 'pg_cron';
   ```
2. **If that returns no rows, enable it:** Supabase dashboard → **Database → Extensions** →
   search `pg_cron` → enable. On some plan tiers `CREATE EXTENSION pg_cron;` also works from the
   SQL editor.
3. **Apply `database/DEPLOY_PENDING.sql`** (SQL Editor → paste → Run).
4. **Confirm the job actually exists** — this is the step that is easy to skip and the one that
   matters:
   ```sql
   SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'ride_request_expiry';
   ```
   **An empty result means expiry is still client-triggered only and F3 is not in force**, even
   though the script reported success. The scheduling block is deliberately conditional and
   non-fatal — if `pg_cron` is missing it raises a `NOTICE` and continues, rather than aborting
   the migration and taking the F1 and F2 fixes down with it. The cost of that choice is that a
   silent no-op looks identical to success unless you run this query.
5. **Confirm it is running without error**, after a minute or two:
   ```sql
   SELECT status, return_message, start_time FROM cron.job_run_details
   WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'ride_request_expiry')
   ORDER BY start_time DESC LIMIT 5;
   ```

**If pg_cron is not available on this project's plan tier**, the fallback is a Supabase Edge
Function calling `run_ride_request_expiry()`, triggered by an external scheduler (GitHub Actions
`schedule:`, Upstash QStash, or any cron host). The `supabase/functions/` directory already
exists, so the shape is in place. I have not written that function, because which scheduler to
use is a decision about infrastructure and cost that is not mine to make — that is the
`NEEDS_DECISION` recorded in `SUMMARY.md`.

## Interval note

The plan asks for every 30–60 seconds. The schedule is `* * * * *` — every 60 seconds, the
shortest interval standard five-field cron syntax can express, supported on every `pg_cron`
version. `pg_cron >= 1.5` also accepts `'30 seconds'` as a schedule string. I did not use it
because I cannot check the installed version. To move to 30s, confirm with
`SELECT extversion FROM pg_extension WHERE extname = 'pg_cron';` and change the one schedule
string. 60s satisfies the plan's stated range either way.

## How it was verified

`flutter analyze` — 70 issues, 0 errors, identical to baseline. `flutter test` — 108/108
(96 before this fix + 12 new).

The new tests were confirmed to fail against the pre-F3 schema: **6 of 12 fail**. The other 6
cover `DEPLOY_PENDING.sql`, which is new in this commit, so they have no pre-F3 state to fail
against.

## Risk / side effects

**Nothing here has been executed.** No SQL in this pass has run anywhere. The cron schedule, the
wrapper function and the constraint change are all reviewed-by-reading only. The tests assert
the *shape* of the SQL text, not that any of it works.

**The constraint widening is the first change in this pass that alters existing data
semantics.** Once applied, rows can hold `status = 'expired'`, which was previously impossible.
Any code that switches exhaustively on status and does not handle `'expired'` will start seeing
it. The Dart model and the UI both already handle it — that is why widening is the correct fix —
but any reports, exports or dashboards querying this table should be checked, and I have not
audited those.

**Client-side expiry is left in place.** `autoExpirePastRequests()` will begin working once the
constraint is applied, but under F2's scoped RLS it now only affects the caller's own rows.
Removing it is not in F3's scope, and leaving it is harmless once the cron job is doing the real
work — it just becomes a redundant local sweep. Worth deleting in a later pass.

**Deployment is a prerequisite for correctness now, not just an improvement.** F1 moved the
must-be-confirmed guard into an RPC, F2's hole stays open until its policies are applied, and F3
does nothing at all until pg_cron is enabled. The gap between this repository and the live
database is widening with each fix, and everything in `DEPLOY_PENDING.sql` needs to land
together.

## Status: NEEDS_DECISION

The migration is written and ready. Two things are needed from someone with Supabase access:

1. **Confirm `pg_cron` can be enabled on this project's plan tier**, and enable it. Without it
   the schedule silently does not exist and expiry remains client-triggered.
2. **If it cannot be enabled, decide on the fallback scheduler** for an Edge Function
   (GitHub Actions / QStash / other). That is an infrastructure and cost decision, not a code
   one.
