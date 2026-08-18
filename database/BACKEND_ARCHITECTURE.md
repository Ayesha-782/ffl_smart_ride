# 🚗 FFL Smart Ride — Comprehensive Backend Architecture & Application Flow

This document provides a complete technical explanation of the **FFL Smart Ride** employee carpooling system built with **Flutter (Dart)** and **Supabase (PostgreSQL, Auth, Realtime, Edge Functions)** for the Township-to-Factory commute route.

---

## 📑 Table of Contents
1. [System Architecture Overview](#1-system-architecture-overview)
2. [Database Schema & Data Model](#2-database-schema--data-model)
3. [Row Level Security (RLS) & Protection Model](#3-row-level-security-rls--protection-model)
4. [Backend Logic & PostgreSQL RPC Functions](#4-backend-logic--postgresql-rpc-functions)
5. [End-to-End Application Lifecycle Flows](#5-end-to-end-application-lifecycle-flows)
   - [5.1 User Authentication & Registration](#51-user-authentication--registration)
   - [5.2 Shift Session Lifecycle & Automation](#52-shift-session-lifecycle--automation)
   - [5.3 Nearest-Passenger Priority Queue & Matching](#53-nearest-passenger-priority-queue--matching)
   - [5.4 Cancellation, Re-Queuing & Driver Switch](#54-cancellation-re-queuing--driver-switch)
   - [5.5 Environmental Impact & Reporting](#55-environmental-impact--reporting)
6. [Realtime Synchronization Architecture](#6-realtime-synchronization-architecture)

---

## 1. System Architecture Overview

```mermaid
graph TD
    subgraph Flutter App [Flutter Mobile Client]
        UI[UI Screens & Widgets]
        Repo[Repositories: Auth, Ride, Reports]
        Client[Supabase Flutter Client]
        UI --> Repo
        Repo --> Client
    end

    subgraph Supabase [Supabase Cloud Infrastructure]
        Auth[Supabase Auth Engine]
        DB[(PostgreSQL Database)]
        Realtime[Realtime Replication Server]
        Edge[Edge Functions / pg_cron]
        FCM[Firebase Cloud Messaging]
    end

    Client -->|HTTPS / WSS| Auth
    Client -->|PostgREST & RPC| DB
    Client -->|WebSocket| Realtime
    DB -->|WAL Stream| Realtime
    Edge -->|Cron Shift Automation| DB
    Edge -->|Push Notifications| FCM
    FCM -->|Push Notification| Flutter App
```

---

## 2. Database Schema & Data Model

The database is designed around a fixed **Township-to-Factory** commute route with predefined pickup stops, shift sessions, and atomic matching states.

```mermaid
erDiagram
    PROFILES ||--o| VEHICLES : owns
    PROFILES ||--o{ DRIVER_AVAILABILITY : offers
    PROFILES ||--o{ PASSENGER_LOG : requests
    PROFILES ||--o{ RIDE_MATCHES : participates
    PROFILES }|--|| PICKUP_STOPS : assigned_stop
    RIDE_SESSIONS ||--o{ DRIVER_AVAILABILITY : contains
    RIDE_SESSIONS ||--o{ PASSENGER_LOG : contains
    RIDE_SESSIONS ||--o{ RIDE_MATCHES : contains
    SESSION_SCHEDULE ||--o{ RIDE_SESSIONS : schedules

    PROFILES {
        uuid id PK
        string employee_id UK
        string full_name
        string email UK
        string phone
        string home_address
        string pickup_stop_id FK
        smallint pickup_stop_order
        string vehicle_number
        boolean has_vehicle
    }

    VEHICLES {
        uuid id PK
        uuid user_id FK
        string vehicle_type
        string make
        string model
        string license_plate UK
        smallint capacity
    }

    PICKUP_STOPS {
        string id PK
        string name
        smallint stop_order UK
        string description
    }

    SESSION_SCHEDULE {
        string id PK
        string slot
        time opens_at
        time closes_at
        boolean is_active
    }

    RIDE_SESSIONS {
        uuid id PK
        date session_date
        string slot
        string status
        timestamptz created_at
    }

    DRIVER_AVAILABILITY {
        uuid id PK
        uuid session_id FK
        uuid driver_id FK
        int seats_offered
        int seats_remaining
        string status
    }

    PASSENGER_LOG {
        uuid id PK
        uuid session_id FK
        uuid passenger_id FK
        string status
        timestamptz requested_at
    }

    RIDE_MATCHES {
        uuid id PK
        uuid session_id FK
        uuid driver_id FK
        uuid passenger_id FK
        string status
        timestamptz matched_at
        timestamptz cancelled_at
    }

    APP_CONFIG {
        string key PK
        numeric value
        string text_value
        string description
    }
```

### Route Pickup Stops (Fixed Township-to-Factory Layout)
| Stop ID | Stop Name | Order | Description |
|---|---|:---:|---|
| `stop_gate_1` | Gate 1 (Township Main Entrance) | 1 | Main residential entry gate, Security Post 1 |
| `stop_sector_a` | Sector A (Central Park / Mosque) | 2 | Sector A roundabout, near Central Park |
| `stop_comm_center` | Commercial Center (Township Market) | 3 | Main marketplace parking area |
| `stop_sector_b` | Sector B (Staff Quarters / Club) | 4 | Executive club bus bay & Sector B junction |
| `stop_gate_2` | Gate 2 (Township North Exit) | 5 | Township exit towards Factory expressway |
| `stop_factory_main`| Factory Main Plant Gate | 6 | FFL Manufacturing Plant Employee Reception |

---

## 3. Row Level Security (RLS) & Protection Model

All tables enforce strict Row Level Security policies to prevent unauthorized data manipulation and privilege leaks.

| Table | SELECT Policy | INSERT / UPDATE / DELETE Policies | Security Rationale |
|---|---|---|---|
| **`profiles`** | Authenticated users can view all employee profiles. | Users can insert and update **only their own** profile (`auth.uid() = id`). | Colleagues can see each other's names and vehicle numbers, but cannot alter someone else's credentials. |
| **`vehicles`** | Authenticated users can view registered vehicle specs. | Scoped to owner (`auth.uid() = user_id`). | Only the vehicle owner can update make, model, and plate. |
| **`ride_sessions`** | Authenticated users can view active/past sessions. | **Direct client write is disabled.** | Sessions are opened and closed strictly through audited PostgreSQL RPC functions. |
| **`driver_availability`**| Scoped to owner (`auth.uid() = driver_id`). | Scoped to owner (`auth.uid() = driver_id`). | Drivers manage only their own seat quotas. |
| **`passenger_log`** | Scoped to passenger (`auth.uid() = passenger_id`) + Active Drivers in that session. | Scoped to passenger (`auth.uid() = passenger_id`). | Passengers control their own requests; drivers can only view waiting lists while actively offering seats. |
| **`ride_matches`** | Scoped to ride participants (`auth.uid() = driver_id OR auth.uid() = passenger_id`). | **Direct client write is disabled.** | Matches are formed, cancelled, and completed only through transactional `SECURITY DEFINER` RPCs. |

---

## 4. Backend Logic & PostgreSQL RPC Functions

### 4.1 Automatic Profile & Vehicle Creation (`handle_new_user`)
* **Trigger Type**: `AFTER INSERT ON auth.users`
* **Logic**: Intercepts `raw_user_meta_data` provided during signup. In a single atomic database transaction, it populates `public.profiles` and creates the `public.vehicles` record if the user checked "I have a vehicle".

### 4.2 Nearest-Passenger Priority Queue (`get_priority_queue`)
* **Parameters**: `p_session_id UUID, p_driver_id UUID`
* **Sorting Formula**:
  1. Primary: $\text{Proximity} = |\text{passenger\_stop\_order} - \text{driver\_stop\_order}| \text{ ASC}$
  2. Secondary: $\text{requested\_at ASC}$ (First-Come, First-Served tiebreaker)
* **Outcome**: A driver at Stop #4 (Sector B) sees colleagues at Stop #4 first (0 stops away), then Stop #3 & #5 (1 stop away), then Stop #2 & #6 (2+ stops away).

### 4.3 Atomic Multi-Passenger Assignment (`assign_passengers`)
* **Parameters**: `p_session_id UUID, p_driver_id UUID, p_passenger_ids UUID[]`
* **Concurrency & Race-Condition Safety**:
  1. Applies `FOR UPDATE` row lock on `driver_availability`.
  2. Verifies $\text{seats\_remaining} \ge \text{array\_length}(p\_passenger\_ids)$.
  3. Iterates over each passenger ID and acquires a `FOR UPDATE` lock on `passenger_log`.
  4. Verifies `passenger_log.status = 'waiting'`. If another driver already matched this passenger concurrently, the entire transaction **rolls back** with an exception.
  5. Inserts `ride_matches` rows, updates `passenger_log.status = 'matched'`, decrements `seats_remaining`, and writes notifications.

### 4.4 Cancellation Handlers
* **`cancel_match(p_match_id)`**:
  - Marks match as `'cancelled'` with timestamp.
  - Returns passenger to `'waiting'` status while **preserving their original `requested_at` timestamp** so they do not lose priority queue ranking.
  - Recovers +1 seat for the driver.
* **`cancel_driver_availability(p_driver_availability_id)`**:
  - Marks driver availability as `'cancelled'`.
  - Re-queues all active passengers assigned to this driver and dispatches cancellation alerts.
* **`switch_driver_to_passenger(p_session_id, p_user_id)`**:
  - Cancels driver availability and re-queues any previously matched passengers.
  - Automatically registers the user into `passenger_log` with status `'waiting'`.

### 4.5 Environmental Reporting & ESG Analytics
* **`monthly_co2_summary(p_month)`**: Sums completed ride CO₂ reductions and trip counts for the month.
* **`monthly_leaderboard(p_month)`**: Dense ranks top 10 drivers and passengers by completed trips and kilograms of CO₂ saved.
* **`get_last_6_months_co2_trend()`**: Produces a continuous monthly time series for historical trend graphs.
* **`get_user_monthly_stats(p_user_id, p_month)`**: Calculates individual personal statistics (rides given, rides taken, personal kg CO₂ saved).

---

## 5. End-to-End Application Lifecycle Flows

### 5.1 User Authentication & Registration Flow

```mermaid
sequenceDiagram
    autonumber
    actor User as Employee
    participant Flutter as Flutter App
    participant Auth as Supabase Auth
    participant DB as Postgres (handle_new_user Trigger)
    
    User->>Flutter: Fills Full Name, ID, Stop, Vehicle, Email & Password
    Flutter->>Flutter: Pre-submission Validation (RFC Email, Plate format, etc.)
    Flutter->>Auth: signUp(email, password, metadata: registrationData)
    Auth->>DB: INSERT INTO auth.users
    DB->>DB: Trigger: Insert into profiles & vehicles (Atomic Tx)
    Auth-->>Flutter: Returns AuthResponse (Session active)
    Flutter->>Flutter: Saves session locally & Routes to HomeScreen
```

---

### 5.2 Shift Session Lifecycle & Automation

```mermaid
sequenceDiagram
    autonumber
    participant Cron as pg_cron / Edge Function
    participant DB as PostgreSQL
    participant FCM as Firebase Cloud Messaging
    actor Driver as Driver App
    actor Pass as Passenger App

    Note over Cron,DB: Morning Commute Shift Opens (06:30 PKT)
    Cron->>DB: open_daily_session_rpc('morning')
    DB->>DB: Create ride_sessions row (status: 'open')
    DB->>DB: Insert session_open notifications
    Cron->>FCM: Push broadcast to /topics/all_employees
    FCM-->>Driver: "Morning Commute Open! Are you riding or need a lift?"
    FCM-->>Pass: "Morning Commute Open! Are you riding or need a lift?"

    Driver->>Driver: Opens App -> SessionPromptDialog appears
    Driver->>DB: Selects "I'm Riding" (Offers 3 seats) -> driver_availability
    Pass->>Pass: Opens App -> SessionPromptDialog appears
    Pass->>DB: Selects "I Want Lift" -> passenger_log (status: 'waiting')

    Note over Cron,DB: Shift Closes (08:30 PKT)
    Cron->>DB: close_daily_session_rpc('morning')
    DB->>DB: Update ride_sessions (status: 'closed')
    DB->>DB: Auto-flip active ride_matches to 'completed' (Calculates CO2 savings)
```

---

### 5.3 Nearest-Passenger Matching Flow

```mermaid
sequenceDiagram
    autonumber
    actor Driver as Driver (Stop #4 - Sector B)
    participant Flutter as Driver App
    participant DB as PostgreSQL (get_priority_queue / assign_passengers)
    participant Realtime as Supabase Realtime
    actor Pass as Passenger (Stop #4)

    Driver->>Flutter: Opens Priority Queue
    Flutter->>DB: get_priority_queue(session_id, driver_id)
    DB-->>Flutter: Returns list sorted by abs(stop_order - 4) ASC
    Note over Flutter: Passenger at Stop #4 appears #1 (0 stops away)<br/>Passenger at Stop #3 appears #2 (1 stop away)
    Driver->>Flutter: Selects Checkbox (1 of 3 seats) -> Taps "Confirm Match"
    Flutter->>DB: assign_passengers(session_id, driver_id, [passenger_id])
    DB->>DB: Locks rows (FOR UPDATE), checks 'waiting', decrements seat count
    DB->>DB: Creates ride_matches & updates passenger_log to 'matched'
    DB-->>Realtime: Broadcasts table change on passenger_log
    Realtime-->>Pass: Live update: Matched with Driver!
    Flutter->>Flutter: Routes to DriverMyRideScreen (Shows passenger contact)
```

---

### 5.4 Cancellation, Re-Queuing & Driver Switch Flow

```mermaid
sequenceDiagram
    autonumber
    actor Driver as Driver
    participant Flutter as Driver App
    participant DB as PostgreSQL (cancel RPCs)
    actor Pass as Passenger

    Driver->>Flutter: Taps "Cancel Entire Ride"
    Flutter->>Driver: Dialog: "Do you need a lift instead?"
    alt Driver selects "Yes, I Need Lift"
        Flutter->>DB: switch_driver_to_passenger(session_id, user_id)
        DB->>DB: Cancels driver offering & re-queues passengers (status: 'waiting')
        DB->>DB: Enters driver into passenger_log (status: 'waiting')
        DB-->>Pass: Notification: Driver unavailable, you are back in queue
        Flutter->>Flutter: Home dashboard updates to Passenger Waiting card
    else Driver selects "Cancel Only"
        Flutter->>DB: cancel_driver_availability(availability_id)
        DB->>DB: Cancels offering & re-queues all matched passengers
    end
```

---

### 5.5 Environmental Impact & Reporting Flow

$$\text{kg CO}_2\text{ Saved} = 2.5\text{ km (Route)} \times 0.12\text{ kg/km (Emission Factor)} = 0.30\text{ kg CO}_2\text{ per passenger}$$

```mermaid
graph LR
    Match[Ride Match Reaches 'completed'] --> View[co2_savings View]
    View --> Summary[monthly_co2_summary RPC]
    View --> Leaderboard[monthly_leaderboard RPC]
    View --> Trend[get_last_6_months_co2_trend RPC]
    View --> UserStats[get_user_monthly_stats RPC]

    Summary --> UI1[Total kg / Tons Prevented]
    Leaderboard --> UI2[Top 10 Drivers & Passengers]
    Trend --> UI3[6-Month Bar Chart]
    UserStats --> UI4[Personal Impact Metrics]
```

---

## 6. Realtime Synchronization Architecture

* **Publication**: PostgreSQL WAL publication `supabase_realtime` replicates changes across:
  * `session_schedule`, `ride_sessions`, `driver_availability`, `passenger_log`, `ride_matches`, `notifications`.
* **Client Subscription**:
  * [DriverPriorityQueueScreen](file:///c:/Users/Zain/Desktop/ffl_smart_ride/ffl_smart_ride/lib/features/rides/screens/driver_priority_queue_screen.dart) listens to `streamPassengerLogChanges(session.id)`. When another driver matches a passenger, the queue silently refreshes to prevent stale selections.
  * [HomeScreen](file:///c:/Users/Zain/Desktop/ffl_smart_ride/ffl_smart_ride/lib/features/home/screens/home_screen.dart) listens to `ride_sessions` to update the active card immediately when shifts open or close.
