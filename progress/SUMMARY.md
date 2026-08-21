# Fix Progress Summary
Last updated: 2026-08-21 — F1-F5 complete, F6 awaiting go-ahead

Branch: `main` (gate 3 of FIX_PLAN.md overridden by the user in-session; auto-push to
`origin main` after each fix authorized by the user directly).
Baseline commit: `4193035`.

| # | Fix | Status | Commit | Pushed to GitHub |
|---|-----|--------|--------|-------------------|
| F1 | Double-booking race condition | DONE | `aa6dfb4` | YES |
| F2 | RLS policy hole on ride_requests | DONE | `336c09c` | YES |
| F3 | Server-side expiry scheduling | **NEEDS_DECISION** (migration written; needs pg_cron enabled) | `4f65de2` | YES |
| F4 | Defense-in-depth constraints | DONE | `2fc9913` | YES |
| F5 | Idempotency on ride-request creation | DONE (narrower than it sounds — see below) | `945a2cd` | YES |
| F6 | Broader hardening | **NEEDS_DECISION** — proposal written, no code | `6ad2142` | YES |

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
| F3 | 70 issues, 0 errors | 108/108 (+12 new) |
| F4 | 70 issues, 0 errors | 117/117 (+9 new) |
| F5 | 70 issues, 0 errors | 127/127 (+10 new) |

## Open decisions

**F3 — NEEDS_DECISION.** The pg_cron migration is written but cannot be verified. Someone with
Supabase access must (a) confirm pg_cron can be enabled on this plan tier and enable it, or
(b) if it cannot, choose a fallback scheduler for an Edge Function (GitHub Actions / QStash /
other) — an infrastructure and cost decision. **The scheduling block is deliberately non-fatal,
so applying the script succeeds even when it schedules nothing.** Verify with
`SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = '''ride_request_expiry''';`
— an empty result means F3 is not in force. Full steps in `03_server_side_expiry.md`.

## Deployment

**`database/DEPLOY_PENDING.sql` is the single script to run when Supabase access is available.**
It consolidates every schema/RPC/policy change from F1 onward in apply order, guarded so it is
safe to re-run, and ends with post-condition queries. It is updated after every fix that touches
the database.

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
- **F4 adds the one statement that can fail on real data.** `CREATE UNIQUE INDEX` aborts if a
  passenger already holds two active matches in one session. Run the pre-check in
  `DEPLOY_PENDING.sql` section F4 before applying. Remediation is provided but deliberately
  left commented out — it picks a winner between two matches, which is a judgement call.
- **F5 protects less than its name implies.** The idempotency key only helps when the *same*
  key is reused across a retry. No caller passes a stable key yet, so a double-tapped Create
  Request button still creates two requests. Closing that is a UI change, deliberately outside
  F5's stated scope — `createRideRequest` exposes `clientRequestId` ready for it.
- **No constraint in F4 has had its rejection behaviour tested.** The plan asks for deliberate
  violation tests; those need a live database and are written out as post-conditions 7-8 in
  `DEPLOY_PENDING.sql`.
