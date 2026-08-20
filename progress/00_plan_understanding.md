# 00 — Plan Understanding

Comprehension check written before any code changes, per FIX_PLAN.md "Before you start" step 5.

## Preconditions

| Gate | Required | Actual | Result |
|------|----------|--------|--------|
| 2 | `progress/` exists | created | OK |
| 3 | on branch `claude-code-fixes` | on `main` | **OVERRIDDEN BY USER** |
| 4 | baseline commit exists | `4193035 baseline before Claude Code fixes` | OK |

**Gate 3 override:** the user directed, in-session and explicitly, to work directly on `main`
and not to create `claude-code-fixes`. They also authorized `git push origin main` after every
fix commit for the remainder of the session. That authorization comes from the user directly,
not from the FIX_PLAN.md text — the plan document alone would not be sufficient authority for a
standing push permission, and the plan's own push instruction contradicts its gate 3 by naming
`main` as the target.

## Verification performed before writing this file

Read `lib/features/rides/data/ride_repository.dart` (1269 lines) and the relevant regions of
`database/supabase_schema.sql` (71480 bytes). Every factual claim the plan makes was confirmed
against the source; nothing below is taken on the plan's word alone.

- `acceptRide()` at line 797 does read-then-write from the client, exactly as described.
- `confirmRide()` (866), `completeRide()` (959), `cancelRideOffer()` (1008) each use a
  `try { rpc } catch (_) { manual client write }` fallback, exactly as described.
- All six named RPCs exist: `accept_ride_request` (443), `confirm_ride_request` (506),
  `expire_unconfirmed_ride_requests` (576), `expire_past_slot_ride_requests` (606),
  `complete_ride_request` (632), `cancel_ride_offer` (764).
- `accept_ride_request` is `SECURITY DEFINER` and does `SELECT ... FOR UPDATE` (line 462).
- The permissive RLS policy `allow_all_authenticated_ride_requests` exists at line 434 with
  `USING (true) WITH CHECK (true)`.

## F1 — Double-booking race condition

`acceptRide()` reads the row, checks `status`/`driver_id` in Dart, then issues a separate
`UPDATE`. Between the read and the write, a second driver can pass the same check. The write is
guarded by `.eq('status', 'pending')`, so only one UPDATE actually lands — but the code never
inspects how many rows were affected, so the losing driver's call returns normally and their UI
reports success. The result is two drivers each believing they hold the ride while the database
records one.

The fix is to delete the client-side path and call `accept_ride_request` as the only route. That
RPC already serializes concurrent accepts with `FOR UPDATE` and raises a clear exception when
`status <> 'pending'`. The same treatment applies to the three fallback methods: a `catch (_)`
that silently degrades to an unsafe client write is worse than an error, because it hides the
failure. On RPC failure the real error should reach the caller.

**One thing to watch that the plan does not mention:** `accept_ride_request` already inserts the
passenger notification itself (schema lines 489–497). The Dart code inserts the same
notification again. Routing through the RPC without removing the Dart insert would produce two
notifications per accept. The Dart notification block must go when the RPC becomes the only
path. The same overlap needs checking for the other three methods before their fallbacks are cut.

## F2 — RLS hole on `ride_requests`

`FOR ALL ... USING (true) WITH CHECK (true)` means any authenticated user can read, update, or
delete any other user's ride request straight through the Supabase REST API, with the app's
logic bypassed entirely. Scoped policies replace it: SELECT stays open to all authenticated
users (drivers must browse open requests — deliberately unchanged), UPDATE narrows to
`auth.uid() = passenger_id`, DELETE narrows to `auth.uid() = passenger_id` and only for
`cancelled` or `completed` rows. Driver-side transitions do not need a direct UPDATE grant
because after F1 they run through `SECURITY DEFINER` RPCs, which bypass RLS. Written as
`DROP POLICY IF EXISTS` + `CREATE POLICY` in the file's existing style, not an edit of history.
F1's accept flow gets re-tested afterward to confirm the tightening did not break the RPC path.

## F3 — Server-side expiry

`expire_unconfirmed_ride_requests()` and `expire_past_slot_ride_requests()` exist but nothing
invokes them on a schedule; they fire only incidentally when someone calls
`getAvailableRequests()`. If no user opens that screen, an unconfirmed `accepted` ride stays
stuck indefinitely. The fix is a `pg_cron` schedule calling both every 30–60s. I do not have
credentials to the live Supabase instance, so I cannot verify `pg_cron` is enabled — I will
write the migration assuming it must be enabled and flag the dashboard step (Database →
Extensions) as a user action. If the plan tier lacks `pg_cron`, that becomes `NEEDS_DECISION`
with an Edge Function + external scheduler proposed as fallback.

## F4 — Defense-in-depth constraints

Two backstops that hold even if application logic is wrong. First, a partial unique index
`uq_active_match_per_passenger` on `ride_matches (session_id, passenger_id) WHERE status =
'active'`, independent of `assign_passengers`. Second, a `BEFORE INSERT OR UPDATE` trigger on
`driver_availability` rejecting `seats_offered > vehicles.capacity`. Drivers with no vehicle row
(the README's admin account) must not be blocked — enforce only when a vehicle exists. Both get
tested by deliberately attempting a violation and confirming rejection.

## F5 — Idempotency on ride-request creation

`createRideRequest()` has no idempotency key, so a retry on a flaky connection creates a second
request. Add a client-generated `client_request_id` UUID to the payload plus a unique index on
that column (nullable, unique when present), so a retried insert collides instead of
duplicating. Explicitly scoped to ride-request creation only — not extended to other mutations
this pass.

## F6 — Stop

Broader architectural hardening. Per the plan I write a proposal marked `NEEDS_DECISION` and
write no code for it without an explicit go-ahead.

## Per-fix loop

After each fix: `flutter analyze` + `flutter test`, fix regressions I introduced (pre-existing
unrelated failures noted and left, stated explicitly), write `progress/0<n>_<name>.md`, make one
commit for that fix alone, `git push origin main` and verify it succeeded before starting the
next, then update `progress/SUMMARY.md`. A failed push stops the run and gets reported verbatim.

After F1–F5: final `SUMMARY.md` update, and do **not** proceed to `TEST_PLAN.md` — that is a
separate step the user kicks off.
