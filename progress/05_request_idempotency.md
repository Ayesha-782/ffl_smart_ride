# Fix 5: Idempotency on ride-request creation

## What was wrong

`createRideRequest()` had no idempotency key. A retried insert on a flaky connection created a
second identical open request. Both then sat in the queue, and a different driver could accept
each — producing two drivers en route to one passenger, which is the same end state F1 was about
preventing, reached by a different path.

## What changed

**File: `database/supabase_schema.sql`** — new section 21:

- `client_request_id UUID` added to `ride_requests`, **nullable**. A `NOT NULL` column would fail
  to apply against existing rows.
- `uq_ride_requests_client_request_id`, a unique index **partial on
  `WHERE client_request_id IS NOT NULL`**. Rows predating the column, and any client too old to
  send a key, must still be insertable.

**File: `lib/features/rides/data/ride_repository.dart`**

- `generateClientRequestId()` — an RFC 4122 v4 UUID generator built on `Random.secure()`. Written
  out rather than adding the `uuid` package: it is not in the lockfile, this is the only place
  the project needs one, and adding a dependency is a bigger change than the fix. Version and
  variant bits are set correctly, which matters because Postgres will reject a malformed value
  for a `UUID` column.
- `createRideRequest()` takes an optional `clientRequestId` and sends it in the payload.
- On collision the existing row is fetched and returned, so a retry gets back the request that
  was in fact created rather than an error.

**File: `database/DEPLOY_PENDING.sql`** — F5 section, plus post-conditions 9 and 10.

**File: `test/unit/request_idempotency_test.dart`** (new) — 10 tests. The generator is real Dart,
so it is genuinely tested: shape across 200 samples, version/variant nibbles, and 5000 draws
without collision.

## An honest limit on what this actually protects against

**The key only helps if the same key is reused across the retry.** Passing no key generates a
fresh one per call, which covers a retry *inside* `createRideRequest`, but not the caller
invoking it twice — a double-tapped "Create Request" button sends two different keys and still
creates two requests. That is the most likely duplicate in a mobile app, and this fix does not
close it on its own.

So `clientRequestId` is exposed as a parameter and documented: generate one with
`generateClientRequestId()` when the compose screen opens, and pass the same value on every
attempt. **No caller does this yet.** Wiring the compose screen to hold a stable key is a UI
change, and F5 is explicitly scoped to ride-request creation in the repository — the plan says
not to over-build here. Until a caller passes a stable key, the protection is narrower than the
`SUMMARY.md` line "Idempotency on ride-request creation" might suggest.

The duplicate check is deliberately narrow — SQLSTATE `23505` **and** the detail mentioning
`client_request_id`. Swallowing any unique violation would hide unrelated constraint failures,
including F4's `uq_active_match_per_passenger`, by reporting them as successful retries.

## How it was verified

`flutter analyze` — 70 issues, 0 errors, identical to baseline. `flutter test` — 127/127
(117 before this fix + 10 new).

The UUID tests are behavioural rather than shape assertions, so they are meaningful on their own.
I did not run the pre-fix comparison for this file: `generateClientRequestId` did not exist
before, so the tests fail to compile against the old code rather than failing usefully.

## Risk / side effects

**Collision behaviour is untested.** It depends on a Postgres unique index. Post-condition 10 in
`DEPLOY_PENDING.sql` gives the deliberate-duplicate check to run once deployed.

**Deployment ordering matters, but degrades safely.** If the app ships before the column exists,
the insert fails on the unknown column and hits the pre-existing fallback path, which builds a
payload without it. Requests are still created — just without idempotency. Verified by reading;
the fallback triggers on `errStr.contains('column')` and `'schema cache'`, which is what
PostgREST returns for an unknown column. Noted in `DEPLOY_PENDING.sql`.

**One inherited behaviour I did not change:** that same fallback also silently drops
`pickup_stop_order` and all four coordinate fields. It predates this work and is out of scope,
but it means a schema mismatch degrades more than it appears to — worth revisiting in the F6
hardening pass.

## Status: DONE
