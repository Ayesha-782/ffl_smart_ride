# FFL Smart Ride — Fix Execution Plan
**For: Claude Code**
**Project: ffl_smart_ride (Flutter + Supabase)**

---

## Before you start

1. Read this entire file first. Do not write or change any code yet.
2. Create a folder at the project root called `progress/` if it doesn't already exist.
3. Confirm you are on the `claude-code-fixes` git branch (`git branch --show-current`). If not, stop and tell the user — do not proceed on `main`.
4. Confirm a baseline commit already exists on this branch (`git log --oneline -5`). If not, stop and tell the user to make one first.
5. Write `progress/00_plan_understanding.md` summarizing, in your own words, what you understand each fix (F1–F6 below) requires. This is a comprehension check before touching code — keep it short (a few sentences per fix is enough).

Then proceed through F1 → F6 **in order**. Do not skip ahead, and do not combine multiple fixes into one commit.

**After completing each fix (Fn):**
- Run `flutter analyze` and `flutter test`. Fix any new errors/failures your change introduced before moving on. Pre-existing unrelated failures can be noted and left, but say so explicitly.
- Write `progress/0<n>_<short-name>.md` (template below).
- Make a single git commit for that fix only, with a clear message (e.g. `fix: close ad-hoc ride-request double-booking race condition`).
- **Immediately run `git push origin main` after every single commit. Do this after every fix, no exceptions, without being asked again.** Confirm the push succeeded (check the output for errors — auth failures, rejected pushes, etc.) before moving to the next fix. If a push fails for any reason, stop and report the exact error rather than continuing on to the next fix with unpushed work piling up.
- Update `progress/SUMMARY.md` (create it on your first fix, append to it after each subsequent one) — a running one-line status table so the user can see overall progress at a glance without opening every file. Add a column noting whether each fix's commit was successfully pushed.

### Progress file template (`progress/0<n>_<name>.md`)
```markdown
# Fix <n>: <title>

## What was wrong
(1–3 sentences, plain language)

## What changed
- File: path/to/file — what changed and why
- File: path/to/file — what changed and why

## How it was verified
(what you ran, what you checked manually, what a reviewer should test)

## Risk / side effects
(anything else that touches this code path, anything you deliberately did NOT change)

## Status: DONE | BLOCKED | NEEDS_DECISION
(if BLOCKED or NEEDS_DECISION, explain exactly what you need from the user)
```

### `progress/SUMMARY.md` template
```markdown
# Fix Progress Summary
Last updated: <date>

| # | Fix | Status | Commit | Pushed to GitHub |
|---|-----|--------|--------|-------------------|
| F1 | Double-booking race condition | DONE | abc1234 | YES |
| F2 | RLS policy hole on ride_requests | ... | ... | ... |
```

---

## F1 — Fix the double-booking race condition (highest priority)

**Where:** `lib/features/rides/data/ride_repository.dart`

**The problem:** `acceptRide()` currently does a manual read-then-write from the client (read the row, check status client-side, then update) instead of using the database's own `accept_ride_request(p_ride_id)` RPC, which already exists in `database/supabase_schema.sql` and correctly uses `SELECT ... FOR UPDATE` to serialize concurrent accepts. Because the client-side path never checks whether its own UPDATE actually affected a row, two drivers accepting the same request within a short window can both appear to "succeed" client-side even though only one is actually recorded as the driver in the database.

**What to do:**
1. Rewrite `acceptRide()` to call the `accept_ride_request` RPC as the *only* path — remove the manual read-check-write logic entirely, don't keep it as a "fallback."
2. Do the same audit-and-fix for every other method in this file that has a "try RPC → catch → do it manually on the client" pattern: `cancelRideOffer()`, `confirmRide()`, `completeRide()`. In each case, the manual fallback re-introduces an unsafe client-side path. Remove the fallback; if the RPC call fails, surface the real error to the caller instead of silently degrading to an unsafe alternative.
3. Check whether corresponding RPCs (`cancel_ride_offer`, `confirm_ride_request`, `complete_ride_request`) already exist in `database/supabase_schema.sql` (they do, based on prior inspection) — use them as-is, don't rewrite the SQL unless you find a genuine bug in them.
4. Add a regression test (see F6/testing note below, or add now if quick) that fires two concurrent `acceptRide` calls at the same ride_id and asserts only one succeeds and the other receives a clear "already accepted" error — not a silent success.

---

## F2 — Fix the RLS security hole on `ride_requests`

**Where:** `database/supabase_schema.sql`

**The problem:** The current policy is:
```sql
CREATE POLICY "allow_all_authenticated_ride_requests"
    ON public.ride_requests FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);
```
This allows any authenticated user to read, update, or delete **any other user's** ride request row directly via the Supabase API, bypassing the app entirely.

**What to do:**
1. Replace this single broad policy with scoped policies, following the same pattern already used correctly elsewhere in this schema for `driver_availability` and `passenger_log`:
   - `SELECT`: keep open to all authenticated users (drivers need to browse open requests) — this part is intentional, don't restrict it.
   - `UPDATE`: restrict to `auth.uid() = passenger_id` for passenger-initiated changes (create/cancel/edit their own request). Since accept/confirm/complete/cancel-by-driver now go through `SECURITY DEFINER` RPCs (F1), those don't need direct client UPDATE grant at all — RPCs run with elevated privilege regardless of RLS.
   - `DELETE`: restrict to `auth.uid() = passenger_id`, and only when status is `cancelled` or `completed`.
2. Write this as a new migration block (don't silently edit history — add `DROP POLICY IF EXISTS ...` + `CREATE POLICY ...` statements, consistent with the rest of the file's style).
3. After changing this, re-test F1's accept flow end-to-end to make sure tightening RLS didn't break the RPC path (it shouldn't, since RPCs are `SECURITY DEFINER`, but verify).

---

## F3 — Server-side expiry (stop relying on clients to clean up state)

**The problem:** `expire_unconfirmed_ride_requests()` and `expire_past_slot_ride_requests()` exist as RPCs but nothing calls them on a schedule. Expiry currently only happens when a user's app happens to call `getAvailableRequests()`. If nobody opens that screen, expired "accepted" rides can stay stuck indefinitely.

**What to do:**
1. Check whether `pg_cron` extension is enabled/available on the project's Supabase instance (`SELECT * FROM pg_extension WHERE extname = 'pg_cron';`). If you don't have direct database access to check/enable it, write the migration SQL assuming it needs to be enabled, and flag this clearly in your progress file as something the user needs to enable in the Supabase dashboard (Database → Extensions) since you may not have credentials to do it yourself.
2. Add a `pg_cron` schedule calling both expiry RPCs every 30–60 seconds.
3. If `pg_cron` truly isn't available on this project's plan tier, document that as a `NEEDS_DECISION` in your progress file and propose the fallback (a Supabase Edge Function triggered by an external scheduler) rather than silently leaving it unscheduled.

---

## F4 — Defense-in-depth constraints

**What to do:**
1. Add a partial unique index on `ride_matches` to prevent duplicate active matches for the same passenger in the same session, as a backstop independent of the application logic in `assign_passengers`:
   ```sql
   CREATE UNIQUE INDEX IF NOT EXISTS uq_active_match_per_passenger
     ON public.ride_matches (session_id, passenger_id)
     WHERE status = 'active';
   ```
2. Add a trigger or check constraint ensuring `driver_availability.seats_offered` cannot exceed the driver's registered `vehicles.capacity`. Implement as a `BEFORE INSERT OR UPDATE` trigger on `driver_availability` that looks up the driver's vehicle capacity and raises an exception if `seats_offered > capacity`. Handle the case where a driver has no vehicle registered (admin accounts, per the README's test admin account) — don't block those, only enforce when a vehicle row exists.
3. Test both constraints directly with an SQL client or a Dart test that intentionally tries to violate them, confirming they reject correctly.

---

## F5 — Idempotency on ride-request creation (scoped, don't over-build)

**The problem:** No idempotency key on `createRideRequest()` — a retried network call on a flaky connection could create duplicate ride requests.

**What to do:**
1. Add a client-generated UUID (`client_request_id`) to the `createRideRequest` payload.
2. Add a unique constraint or unique index on `ride_requests.client_request_id` (nullable column, unique when present) so a retried insert with the same key fails gracefully or is treated as already-created rather than creating a duplicate.
3. Keep this scoped to ride-request creation only — do not extend idempotency keys to every mutation in this pass, that's a larger change for a later cycle.

---

## F6 — STOP before this section. Do not start without explicit go-ahead.

This section is broader hardening (screen decomposition, state management, offline/retry handling, structured logging) from the original audit. It's real and worth doing, but it's more invasive/architectural than F1–F5 and isn't release-blocking in the same way. **Write a progress file describing what you'd propose for this section and mark it `NEEDS_DECISION` — do not write any code for it until the user explicitly says go.**

---

## After F1–F5 are done

1. Update `progress/SUMMARY.md` with final status of everything.
2. Do **not** proceed to `TEST_PLAN.md` automatically — that's a separate, later step the user will kick off explicitly once they've reviewed the fix progress files.
