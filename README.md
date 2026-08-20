# FFL Smart Ride - Employee Carpool & Environmental Mobility Platform

Smart carpooling application for employees commuting between the Township residential area and the FFL Manufacturing Plant, tracking verified CO₂ and fuel savings with an immutable audit trail.

---

## 🛡️ Admin & Super Admin Dashboard

The application includes a fully dedicated Admin & Super Admin Dashboard separate from the commuter experience:
- **Role-Based Auth Gate**: Automatically directs `'admin'` and `'super_admin'` roles to the Admin Shell and regular `'user'` roles to the commuter interface.
- **Environmental Analytics**: Real-time summary metrics, interactive `fl_chart` visualizations (CO₂ reduction trend, completed rides over time, top contributors), and immutable leaderboards from `ride_completion_log`.
- **PDF Report Generation**: Downloadable and printable executive audit reports via `pdf` and `printing` packages.
- **User & Admin Management**: Pre-register employees, manage vehicle registrations, soft-deactivate accounts, and delegate administrator permissions.

---

## 🧪 Development & Testing Admin Account

> [!WARNING]
> **DEVELOPMENT / TEST ONLY ACCOUNT**
> The pre-made admin account below is provided solely for local testing and demonstration.
> **DO NOT USE IN PRODUCTION. Remove or rotate credentials prior to real deployment.**

| Field | Value |
| :--- | :--- |
| **Email** | `admin11@gmail.com` |
| **Password** | `admin11` |
| **Role** | `admin` |
| **Vehicle** | None (Demonstrates non-driver admin account resilience) |

### How to Seed in Supabase:
Run the SQL script [`database/seed_admin.sql`](database/seed_admin.sql) directly in your [Supabase SQL Editor](https://supabase.com/dashboard/project/_/sql).

---

## 🚀 Running the App

```bash
# Get dependencies
flutter pub get

# Run unit & widget tests
flutter test

# Run app
flutter run
```
