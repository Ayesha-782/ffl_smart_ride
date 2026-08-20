# Fix 2: Close the RLS hole on `ride_requests`

## What was wrong

`public.ride_requests` carried one policy:

```sql
CREATE POLICY "allow_all_authenticated_ride_requests"
    ON public.ride_requests FOR ALL
    TO authenticated USING (true) WITH CHECK (true);
```

Any authenticated user could read, update or delete **any other user's** ride request straight
through the Supabase REST API. Every rule the app enforces — who may cancel, who may accept,
the confirmation deadline — was advisory, because the table itself permitted anything to anyone
holding a valid token. F1's work would have been largely cosmetic while this stood: closing the
race in the RPC means little if a client can just `PATCH` the row directly.

## What changed

**File: `database/supabase_schema.sql`** — replaced the single `FOR ALL` policy with four
per-command policies, in the file's existing `DROP POLICY IF EXISTS` + `CREATE POLICY` style,
matching the scoping already used for `driver_availability` and `passenger_log`:

- **SELECT** — `USING (true)`, unchanged and deliberately open. Drivers must be able to browse
  the open request queue. The plan calls this out as intentional; I have not narrowed it.
- **INSERT** — `WITH CHECK (auth.uid() = passenger_id)`.
- **UPDATE** — `USING (auth.uid() = passenger_id)` **and** the same predicate in `WITH CHECK`.
- **DELETE** — own rows only, and only rows that can no longer be acted on.

Drivers are given **no** direct UPDATE grant. Accept/confirm/complete/cancel-offer all run
through `SECURITY DEFINER` RPCs after F1, which bypass RLS entirely, so a `driver_id`-based
UPDATE policy would serve no purpose except to reopen the hole F1 just closed.

**File: `test/unit/ride_requests_rls_test.dart`** (new) — 8 regression tests.

## Two deviations from the plan's literal text

Both are deliberate, and both would have caused real breakage if followed exactly.

**1. The plan omits an INSERT policy.** It specifies SELECT, UPDATE and DELETE only. But the
`FOR ALL` policy being replaced was the *only* INSERT grant on the table — dropping it without a
replacement would deny all inserts, and `createRideRequest()` would fail outright for every
user. Added `WITH CHECK (auth.uid() = passenger_id)`.

**2. The plan's DELETE scope is narrower than the app's behaviour.** It specifies `cancelled` or
`completed`. The UI also offers "Delete Expired Request" for a request that is still `pending`
but whose departure time has passed (`available_requests_screen.dart:920` —
`showDeleteOption = isCancelled || isCompleted || isSlotOrStatusExpired`). Under the literal
policy that button would silently delete nothing: no error, no row removed, no feedback. Such a
row has no driver attached, so deleting it harms nobody. The policy therefore also allows
`status = 'pending' AND leaving_time < now()`. The plan's actual intent — don't let a request be
deleted out from under a driver who was offered it — is preserved: `accepted` and `confirmed`
remain undeletable.

`WITH CHECK` on UPDATE is also slightly beyond the plan's wording. Without it a passenger could
satisfy `USING` on their own row and then rewrite `passenger_id`, handing the row to someone
else. It costs nothing and closes an obvious gap.

## How it was verified

`flutter analyze` — 70 issues, 0 errors, identical to baseline. `flutter test` — 96/96 pass
(88 before this fix + 8 new).

The 8 new tests were confirmed to fail against the pre-F2 schema: **7 of 8 fail**, restored from
`HEAD` and re-run before putting the fix back. The one that passes on both is "drivers get no
direct UPDATE grant", which was true before as well — the old schema was permissive rather than
driver-scoped.

One test bug worth recording, because it is the kind that makes a security test worthless: the
first run reported the hole still open. The schema documents the removed policy in a `--`
comment so future readers know what was taken out and why, and the assertions were matching
that prose. The tests now strip `--` comments and assert against executable SQL only. A test
that reads comments as if they were policy would have passed happily on a schema where the hole
had been re-added in a commented-out block.

## Risk / side effects

**Enforcement is not tested, and cannot be from here.** These tests assert the *shape* of the
policy block in the `.sql` file. Proving that user A cannot `PATCH` user B's row needs a live
instance and two authenticated roles. **That check is the one that actually matters for a
security fix, and it remains outstanding** — it belongs in the integration pass alongside F1's
concurrency check.

**Two client-side sweeps will silently stop working across other users' rows**, and this is a
real behaviour change landing before its replacement:

- `autoExpirePastRequests()` (`ride_repository.dart:477`) updates *every* pending row past its
  departure time, regardless of owner.
- The expiry loop inside `expireUnconfirmedMatches()` (`ride_repository.dart:1000`) reverts
  *every* stale accepted row to pending.

Under the new policies each only affects the caller's own rows. This is the anti-pattern F3
exists to replace with a server-side `pg_cron` schedule — but F3 is the next fix, so between
this commit and F3 landing *and being deployed*, expiry coverage is reduced. Both sweeps are
wrapped in `catch (_) {}`, so the narrowing will not surface as an error anywhere.

**A pre-existing bug found while checking that path, unrelated to my change and not fixed here:**
`autoExpirePastRequests()` writes `status: 'expired'`, but the table's CHECK constraint allows
only `('pending', 'accepted', 'confirmed', 'completed', 'cancelled')`. That write has therefore
*always* failed, and the empty `catch (_) {}` has always swallowed it. The function has never
done anything. It is squarely in F3's territory and I have left it alone rather than widen this
commit — flagging it so F3 does not assume it works.

**Not deployed.** As with F1, this is an edit to `database/supabase_schema.sql`. The live
database still carries the permissive policy until someone with dashboard access applies it.
**Until then this hole is open in production.**

## Status: DONE
