# FFL_Smart_Ride - End-to-End Test Plan

This document defines the complete automated and manual verification suite for the **FFL_Smart_Ride** multiple-times-daily ride-matching system, row-level security boundaries, and environmental impact reporting.

---

## 1. Daily Session Lifecycle & Timezone Consistency

| ID | Test Scenario | Expected Outcome |
|---|---|---|
| **S-01** | `open_daily_session_rpc('morning')` is triggered at 06:30 PKT. | Session created with status `'open'`, session date pinned to `(now() AT TIME ZONE 'Asia/Karachi')::DATE`. Push notifications dispatched to all employees. |
| **S-02** | Session prompt modal on app launch during an open session. | Shows two distinct actions: *"I'm Riding"* (prompts for seat count default from vehicle capacity) and *"I Want Lift"* (registers waiting passenger). |
| **S-03** | `close_daily_session_rpc('morning')` triggered at 08:30 PKT. | Session status flips to `'closed'`. All still-active `ride_matches` rows automatically transition to `'completed'`, logging CO₂ savings. |
| **S-04** | App launch when no session is active. | `HomeScreen` displays `NoSessionOpenCard` indicating the next upcoming shift window and daily shift commute hours. |

---

## 2. Nearest-Passenger Priority Queue

| ID | Test Scenario | Expected Outcome |
|---|---|---|
| **Q-01** | Driver at Stop #4 (`Sector B`) requests waiting queue. | Returns passengers ordered strictly by `abs(passenger_stop - 4) ASC`. Passengers at Stop #4 appear first (`0 Stops Away`), followed by Stop #3 & #5 (`1 Stop Away`), then #2 & #6 (`2+ Stops Away`). |
| **Q-02** | Two passengers waiting at the exact same pickup stop. | Tiebreaker sorts by `requested_at ASC` (First-Come, First-Served). |
| **Q-03** | Multi-selection capacity capping in `DriverPriorityQueueScreen`. | Checkbox selection is capped at driver's `seats_remaining`. Selecting past capacity is disabled until an item is unselected. |
| **Q-04** | Empty queue state. | Displays friendly empty state illustration with message: *"All colleagues for this session are matched or have not requested a lift yet."* |

---

## 3. Atomic Matching & Concurrent Driver Race Conditions

| ID | Test Scenario | Expected Outcome |
|---|---|---|
| **M-01** | Single driver matching selected passengers. | Executes in an atomic PostgreSQL transaction: decrements driver `seats_remaining`, creates `ride_matches` rows, updates `passenger_log` to `'matched'`, and sends match notifications. |
| **M-02** | **Simultaneous Match Race Condition**: Driver A and Driver B attempt to select the same waiting Passenger P simultaneously. | Driver A acquires row lock with `FOR UPDATE` and successfully matches. Driver B's transaction detects status != `'waiting'`, rolls back atomically, throws `ERR_PASSENGER_ALREADY_MATCHED`, and Flutter app presents the *"Queue Updated"* modal while automatically reloading the queue. |
| **M-03** | Realtime Sync during queue inspection. | As another driver claims a passenger, Supabase Realtime channel automatically triggers queue reload on active screens. |

---

## 4. Cancellation & Queue Re-Queuing

| ID | Test Scenario | Expected Outcome |
|---|---|---|
| **C-01** | Driver cancels an individual match (`cancel_match`). | Match status becomes `'cancelled'`. Passenger status returns to `'waiting'` while **preserving their original `requested_at` timestamp** (maintaining queue priority). Driver `seats_remaining` increments by 1. |
| **C-02** | Driver cancels entire availability (`cancel_driver_availability`). | Availability marked `'cancelled'`. All active matches under that availability are cancelled and all affected passengers return to `'waiting'` at the top of the queue. |
| **C-03** | Passenger self-cancels request before match (`cancel_passenger_request`). | Passenger log status transitions to `'cancelled'`. |
| **C-04** | Driver switches to passenger mode (`switch_driver_to_passenger`). | Cancels driver availability, re-registers user into `passenger_log` as a new waiting passenger in a single transaction. |

---

## 5. Row-Level Security (RLS) Privilege Boundaries

| Table | Permitted Client Operations | Blocked Client Operations |
|---|---|---|
| `ride_sessions` | Authenticated `SELECT` | Direct client `INSERT`, `UPDATE`, `DELETE` (Restricted to `SECURITY DEFINER` RPCs). |
| `driver_availability` | `SELECT`, `INSERT`, `UPDATE` where `auth.uid() = driver_id` | Access to or mutation of other drivers' availability records. |
| `passenger_log` | `SELECT`, `INSERT`, `UPDATE` where `auth.uid() = passenger_id`; `SELECT` for active session drivers | Unauthenticated access or unauthorized modifications. |
| `ride_matches` | `SELECT` where `auth.uid() = driver_id OR auth.uid() = passenger_id` | Direct client `INSERT`, `UPDATE`, `DELETE` (Mutations exclusively through audited RPCs). |
| `app_config` | Authenticated `SELECT` | Direct client mutation of constants (Restricted to Supabase Admin). |

---

## 6. Environmental Impact & Reports

| ID | Test Scenario | Expected Outcome |
|---|---|---|
| **E-01** | Completed match CO₂ computation (`co2_savings` view). | Computes $2.5\text{ km} \times 0.12\text{ kg/km} = 0.30\text{ kg CO}_2$ ($0.000300\text{ Metric Tons}$) per completed commute. |
| **E-02** | Monthly Leaderboards (`monthly_leaderboard`). | Accurately ranks top drivers and top passengers by count and CO₂ saved with 🥇🥈🥉 medal formatting. |
| **E-03** | User Personal Impact (`get_user_monthly_stats`). | Aggregates individual user's rides given, rides taken, and personal CO₂ savings. |
| **E-04** | 6-Month Savings Trend (`get_last_6_months_co2_trend`). | Returns continuous 6-month monthly series for the animated bar chart. |
