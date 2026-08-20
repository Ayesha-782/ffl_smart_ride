# Fix 6: Broader hardening — proposal only

FIX_PLAN.md instructs: write a proposal, mark it `NEEDS_DECISION`, **write no code without an
explicit go-ahead**. No code has been written for this section. What follows is a proposal and a
survey, not work in progress.

## Survey of the actual state

Measured, not estimated:

| Signal | Count |
|---|---|
| Dart in `lib/` | 17,592 lines across 61 files |
| Largest file — `available_requests_screen.dart` | 1,420 lines |
| Second — `home_screen.dart` | 1,217 lines |
| `ride_repository.dart` | 1,193 lines |
| `catch (_)` — errors swallowed silently | 33 |
| `setState` call sites | 108 |
| `debugPrint` (the entire logging story) | 6 |
| State management package | none — `StatefulWidget` + `setState` only |

## What I would propose, in priority order

### H1 — The 33 swallowed errors (highest value, lowest risk)

`catch (_) {}` appears 33 times in `lib/`. This is not a style problem. Two real bugs found
during F2 and F3 were *invisible for the lifetime of the project* because of it:
`autoExpirePastRequests()` and `expire_past_slot_ride_requests()` both wrote a status the CHECK
constraint forbade, so both failed on every call, and the empty catch meant nobody ever saw it.

I would audit all 33, and for each either handle the error, surface it, or log it with a comment
saying why it is genuinely ignorable. This is mechanical, testable, and needs no architectural
decision. **I would do this first regardless of what else is approved**, and it is small enough
to stand alone.

### H2 — Structured logging

Six `debugPrint` calls across 17.5k lines is effectively no observability. With no way to see
what happened on a user's device, every bug report starts from zero. A minimal logging
abstraction — levels, and one place to swap in a real sink later — would pair naturally with H1,
since H1 needs somewhere for the surfaced errors to go. Doing H1 without H2 means 33 new
`debugPrint`s.

### H3 — Offline / retry handling

Currently a dropped connection surfaces as a raw exception string in a `SnackBar`. F5 laid the
groundwork by making request creation idempotent, but nothing *uses* it — there is no retry, and
no caller passes a stable key. A retry policy for reads plus explicit idempotent retry for
writes would build directly on F5, and would make F5 deliver what its name implies.

### H4 — Screen decomposition

`available_requests_screen.dart` at 1,420 lines mixes data loading, business rules, and
presentation. It is the file most touched by F1 and F2 and the hardest to review. Decomposition
is real value, but it is also the largest diff with the least mechanical verification, and the
project has no widget tests covering these screens beyond smoke tests. **I would not start here.**

### H5 — State management

108 `setState` calls with no state management package. Introducing one (Riverpod, Bloc, or
similar) is the most invasive item on the list, touches nearly every screen, and is a decision
about the project's long-term direction rather than a bug fix. It should follow H4, not precede
it, and it needs an explicit owner decision — not a default from me.

## Recommendation

**Approve H1 and H2 as one small pass. Treat H3 as a follow-up. Defer H4 and H5** until there is
test coverage worth refactoring against, and until someone with authority over the project's
direction picks a state management approach.

H1 and H2 together are perhaps a day of mechanical work with clear pass/fail criteria. H4 and H5
are architecture programmes that would be reckless to start in the same pass as security fixes
that have not yet been deployed or verified against a live database.

## Prerequisite that outranks all of this

**Nothing from F1–F5 has been applied to a live database, and none of it has been verified at
runtime.** Before any hardening work begins, `database/DEPLOY_PENDING.sql` should be applied and
its post-conditions checked. Starting an architectural refactor on top of five undeployed,
runtime-unverified fixes would make it very hard to tell, when something breaks, which layer
broke it.

## Status: NEEDS_DECISION

Awaiting an explicit go-ahead, and a choice of scope: H1+H2 only, H1–H3, or the full set
including H4/H5. No code will be written for this section until then.
