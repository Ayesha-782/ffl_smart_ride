# Fix Progress Summary
Last updated: 2026-08-21

Branch: `main` (gate 3 of FIX_PLAN.md overridden by the user in-session; auto-push to
`origin main` after each fix authorized by the user directly).
Baseline commit: `4193035`.

| # | Fix | Status | Commit | Pushed to GitHub |
|---|-----|--------|--------|-------------------|
| F1 | Double-booking race condition | DONE | `aa6dfb4` | YES |
| F2 | RLS policy hole on ride_requests | DONE | (this commit) | YES |
| F3 | Server-side expiry scheduling | NOT STARTED | — | — |
| F4 | Defense-in-depth constraints | NOT STARTED | — | — |
| F5 | Idempotency on ride-request creation | NOT STARTED | — | — |
| F6 | Broader hardening | BLOCKED BY PLAN — needs explicit go-ahead | — | — |

## Verification baseline

Established before any code changed, so regressions can be told from pre-existing noise:

- `flutter analyze` — 70 issues, 0 errors (all deprecations / lint style / unused imports in
  `test/unit/admin_test.dart`).
- `flutter test` — 74/74 passing.

| After | analyze | tests |
|-------|---------|-------|
| baseline | 70 issues, 0 errors | 74/74 |
| F1 | 70 issues, 0 errors | 88/88 (+14 new) |
| F2 | 70 issues, 0 errors | 96/96 (+8 new) |

## Carried-forward notes

- **The schema edits are not deployed, and this is now urgent.** F1 moved the "must be
  confirmed" guard from Dart into `complete_ride_request`, so until the schema is applied that
  guard is enforced in neither place. F2 closes an RLS hole that lets any authenticated user
  modify any other user's ride request — **that hole is open in production until someone with
  Supabase dashboard access applies `database/supabase_schema.sql`.** Highest priority item for
  whoever holds database credentials.
- **Client-side expiry sweeps narrow under F2 and their replacement does not land until F3.**
  See `02_ride_requests_rls.md`. Related pre-existing bug found there:
  `autoExpirePastRequests()` writes a status the CHECK constraint forbids, so it has never
  worked; its failure is swallowed by an empty `catch`. F3 must not assume it works.
- No live database access from this session, so all SQL work is verified by reading only. Every
  fix touching SQL will carry the same caveat.
- A true concurrent two-driver accept test still needs an integration environment — see
  `01_double_booking_race.md`.
