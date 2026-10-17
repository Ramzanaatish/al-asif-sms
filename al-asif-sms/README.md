# Al-Asif School Management System

Android app + backend for **AL-ASIF PUBLIC MIDDLE SCHOOL BASTI SHAIKHAN (REGD.)**
(Principal: Mrs. Hajra Iqbal). Classes Play Group–8th, ~212 students.

`API_CONTRACT.md` is the single source of truth for the Flutter ↔ backend API.

## Structure

```
al-asif-sms/
├── API_CONTRACT.md        # endpoint contract (read before changing either side)
├── README.md              # this file
├── app/                   # Flutter Android app (package com.alasif.schoolms)
│   ├── lib/               # config, services, repositories, providers, models, screens, printing
│   ├── assets/            # logo.png, fonts/NotoNastaliqUrdu.ttf
│   └── README_flutter.md  # Flutter-specific notes
└── backend/               # FastAPI + PostgreSQL
    ├── app/               # config, database, auth, models, schemas, main, routers/
    ├── alembic/           # migrations (env.py wired to settings)
    ├── requirements.txt
    └── seed.py            # classes, users, fee heads, expense categories, demo data
```

## Backend setup

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# PostgreSQL: create db + user (or point DATABASE_URL at SQLite for a quick try)
createdb alasif_sms
# .env (optional):
# DATABASE_URL=postgresql+psycopg2://alasif:alasif@localhost:5432/alasif_sms
# SECRET_KEY=<random-string>

python seed.py        # creates tables + seeds 11 classes, users, fee heads, categories
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Migrations: `alembic revision --autogenerate -m "..."` then `alembic upgrade head`
(tables are also auto-created on startup via `Base.metadata.create_all`).

Seeded logins (password `alasif123` — change after first login):
`principal` (Mrs. Hajra Iqbal), `admin`, `teacher1`, `accounts`, `parent1`.

## Flutter app setup

Built without a Flutter SDK in this environment — **build the APK on your machine**:

```bash
cd app
flutter pub get
# point the app at your backend server:
#   edit lib/config.dart → AppConfig.apiBaseUrl = "http://<server-ip>:8000"
#   (Android emulator: http://10.0.2.2:8000)
flutter run
flutter build apk --release   # → build/app/outputs/flutter-apk/app-release.apk
```

## Offline mode (offline-first)

The app works with **zero internet** for all daily operations — login
(cached), dashboard, admissions, attendance, fee collection + Urdu receipts,
expenses, salaries, holidays, exams/marks, notices, and all reports. Every
module reads from a local SQLite database on the device; writes apply
instantly and sync to the server automatically when connectivity returns.

- Local rows keep permanent local ids with `server_id` stored alongside;
  the sync engine translates ids only at the network boundary.
- Auto numbers (admission `AS-YYYY-NNNN`, challan, receipt, leaving
  certificate) are generated locally in the server's format, marked
  provisional, and reconciled with server-assigned values after sync.
- Conflict rule: server wins, except locally edited (`dirty`) rows are never
  overwritten.
- UI: an app-wide sync badge in the home shell (pending count, tap to force
  sync) and a slim "Offline mode" banner while offline.
- First run without internet seeds classes, fee heads and expense categories
  from a bundled asset so the app is usable immediately.

Full protocol: `app/lib/services/SYNC_PROTOCOL.md`.

## Backup & restore

The app automatically backs up its whole database as a single `.alasif`
file (SQLite copy + metadata with SHA-256 checksum) — once a day and after
every 50 changes, keeping the newest 7, in `Documents/AlAsifBackups/` (or
the app's external files folder). From **Settings** (principal/
administrator) you can trigger "Backup now" or "Import backup" to move the
full database to another phone; import validates the file and asks for
confirmation before replacing local data. There is no app-open password
lock, by the owner's explicit decision.

## Modules (Library, Transport, Inventory excluded by design)

Students (admission, mark-as-left + leaving certificate, year-end promote/retain) ·
Staff (profiles, attendance, leaves, salaries) · Academics (classes, sections,
subjects, syllabus, timetable) · Attendance (offline queue + sync, absence
SMS/WhatsApp alert queue) · Exams (date sheets, marks, monthly/annual results,
analytics) · Fees (heads, challans, collection, defaulters, Urdu receipts) ·
Expenses & P&L (categories, entries, salaries → net profit on dashboard) ·
Communication (notices, complaints, parent child-summary) · Dashboard & audit log.

## Print documents

Flutter renders all PDFs locally (`printing` package): full-size Urdu fee receipt
(single, shown after each collection), compact Urdu receipt (6 per A4 for batch),
leaving certificate, monthly result, annual result, Urdu annual progress report,
whole-school fee collection report. Logo + ® school name on every document.

## Config values to change before real use

- `backend`: `SECRET_KEY`, `DATABASE_URL`, seed user passwords
- `app/lib/config.dart`: `apiBaseUrl`
- Absence alerts: `alert_queue` rows are queued by the API; connect an SMS/WhatsApp
  provider worker to send them (endpoint `GET /api/attendance/alerts` lists queued).
