# Al-Asif SMS — Flutter Android App

**Al-Asif Public Middle School Basti Shaikhan (REGD.) — School Management System**

> **Note:** There is no Flutter/Dart SDK on the machine where this code was
> written, so it has **not** been compiled or run. The code was written
> carefully against stable package APIs, but please run the steps below and
> fix any analyzer warnings/errors that surface on your machine before
> distributing the APK.

## Run / build

```bash
cd app
flutter pub get
flutter run                        # debug on emulator / device
flutter build apk --release        # release APK -> build/app/outputs/flutter-apk/app-release.apk
```

## Configuration

The backend base URL is a **single config value**:

- `lib/config.dart` → `AppConfig.apiBaseUrl`
- Default: `http://10.0.2.2:8000` (works on the Android emulator).
- On a physical device, change it to your server's LAN IP, e.g.
  `http://192.168.1.50:8000`, then rebuild.

Package id: `com.alasif.schoolms` · App name: **Al-Asif SMS** · minSdk 21.
App icon/launcher branding uses `assets/logo.png` (shown on splash, login,
drawer and every printed document with the ® school name).

## Fonts

- `assets/fonts/NotoNastaliqUrdu.ttf` is registered in `pubspec.yaml` under
  the family name `NotoNastaliqUrdu` (as specified).
- **PDF Urdu rendering:** the `pdf` package cannot perform Arabic-script
  OpenType shaping, and inspection of NotoNastaliqUrdu's cmap showed it does
  **not** contain the Arabic Presentation Forms glyphs — so raw Urdu text
  would print as disconnected letters. Urdu PDF text is therefore pre-shaped
  with the `arabic_reshaper` package (`lib/printing/urdu_text.dart`) and
  rendered with the bundled `assets/fonts/Amiri-Regular.ttf` (OFL license,
  full presentation-forms coverage including Urdu-specific letters), loaded
  via `rootBundle` in `lib/printing/pdf_assets.dart`. If you prefer a
  different PDF Urdu font, drop its TTF into `assets/fonts/`, add it to the
  `assets:` list in `pubspec.yaml`, and point `PdfAssets.urduFont()` at it.

## Structure

```
lib/
  config.dart            AppConfig.apiBaseUrl + school constants + brand colors
  main.dart              MultiProvider wiring, theme, auth-gated home
  navigation.dart        role -> drawer menu mapping
  models/                Dart models matching API_CONTRACT.md JSON
  services/
    backend_client.dart  JWT http client (GET/POST/PUT/DELETE), auto-logout on 401
  repositories/          one per module, exact endpoint paths from API_CONTRACT.md
  providers/             ChangeNotifier providers per module
  screens/               all app screens (see below)
  widgets/               SchoolAppBar (logo), LoadingView, EmptyState, RoleGate, helpers
  printing/              PDF builders (printing + pdf packages)
```

## Offline mode (offline-first architecture)

The app works with **zero internet** for all daily operations. Every module
reads from a local SQLite database (`sqflite`) and writes go to SQLite
**immediately**, then sync automatically when connectivity returns.

**How it works**

- `lib/services/local_db.dart` — SQLite schema mirroring the backend:
  students, staff, attendance, fees, expenses, exams, notices, … Each synced
  table has `server_id` (backend PK once synced), `dirty`, `deleted`,
  `updated_at`, plus a `sync_queue` table and a `meta` key-value store.
- `lib/repositories/` — every repository is offline-first: reads from
  SQLite, writes to SQLite + enqueues a sync op. Public method signatures are
  unchanged, so screens and providers work as before.
- `lib/services/sync_service.dart` — watches `connectivity_plus`; when
  online it **pushes** queued ops in FIFO order to the existing REST
  endpoints (translating local ids → server ids at the network boundary),
  then **pulls** fresh master data. Local ids are permanent; `server_id` is
  stored alongside. Conflict rule: server wins, except local `dirty` rows are
  never overwritten. Skipped on dependency, retried next pass; a mid-run
  pull links seeded master rows to server ids by name.
- Full protocol: `lib/services/SYNC_PROTOCOL.md`.

**Provisional numbering** — auto numbers are generated locally in the
server's format and corrected after sync:

| number | local format | reconciliation |
|---|---|---|
| admission_no | `AS-YYYY-NNNN` (local per-year sequence) | on 400 collision the create is retried without the number; the server-assigned value is written back |
| challan_no | `CH-YYYYMM-SSSSS` (local student id) | after generate, matched by (student, month, year); server number wins |
| receipt_no | `R-CCCCCC-NNN` (local challan id + sequence) | replaced by the server's `receipt_no` from the collect response |
| certificate_no | `LC-SSSSS-YYYY` | server's number written back for reprints |

**Offline login** — a successful online login caches a SHA-256 hash of the
credentials + the user profile in SQLite. Offline, login verifies against
the cached hash (wrong password still fails; online 401 behaviour
unchanged) and the app shows an **"Offline mode"** banner.

**Sync UI** — `HomeShell` shows an app-wide sync badge (pending-count,
tap to force sync; amber = waiting, green = synced, grey = offline) plus a
slim offline banner above every screen.

**First-run seed** — if the DB is empty and the device is offline, classes
(Play Group–8th with official student counts), expense categories and fee
heads are seeded from the bundled `assets/seed.json`, so the app is usable
before ever going online.

## Backup & restore

- `lib/services/backup_service.dart` — packs the whole SQLite database plus
  a `metadata.json` (format/schema version, SHA-256 checksum, creation time,
  row counts) into a single **`.alasif`** zip file.
- **Auto-backup:** once a day and after every 50 local changes. Only the
  newest **7** backup files are kept.
- **Location:** `Documents/AlAsifBackups/` when the shared folder is
  writable, otherwise the app's external files folder
  (`Android/data/com.alasif.schoolms/files/AlAsifBackups`) — reachable from
  any file manager. A `.alasif` file can be copied to another phone.
- **Settings screen** (principal/administrator): "Backup now" button and
  "Import backup" — pick any `.alasif` file, the app validates it
  (extension, zip layout, schema version, checksum) and asks for confirmation
  ("All current data on this device will be replaced by this backup. This
  cannot be undone.") before restoring.
- There is deliberately **no app-open password lock** (owner's decision).

## Screens (all wired into role-based navigation)

| Module | Screens |
|---|---|
| Auth | SplashScreen, LoginScreen |
| Dashboard | PrincipalDashboardScreen (also used by administrator) |
| Students | StudentListScreen (filter class/section/search, active/left toggle), StudentDetailScreen (profile, documents, attendance %, fee balance, mark-as-left flow), AdmissionScreen, PromoteScreen, LeavingCertificatePreviewScreen |
| Staff | StaffListScreen (teaching/non-teaching filter), StaffDetailScreen, AddStaffScreen, LeaveListScreen (approve/reject), SalaryScreen (pay per staff/month + list) |
| Academics | AcademicsHomeScreen hub, ClassesScreen (sections + subjects), TimetableScreen (day x period grid), SyllabusScreen (topic status toggle) |
| Attendance | AttendanceHomeScreen hub, MarkAttendanceScreen (fully offline-first: saves to SQLite, syncs automatically, pending-count badge in app bar), StaffAttendanceScreen, AttendanceReportScreen (monthly table + %) |
| Exams | ExamsHomeScreen hub, TermsScreen, DateSheetScreen, MarksEntryScreen, MonthlyResultScreen (table + print), AnnualResultScreen (English card + Urdu progress report prints), AnalyticsScreen (subject averages, pass %, top 5) |
| Fees | FeesHomeScreen hub, FeeHeadsScreen, ChallanGenerateScreen, ChallanListScreen, CollectFeeScreen (collect -> full-size Urdu receipt preview with Print/Share), BatchReceiptScreen (6-per-A4), DefaultersScreen, CollectionReportScreen (table + print) |
| Expenses | ExpenseListScreen, AddExpenseScreen (categories), ProfitLossScreen (income/outgoing/net profit, role-gated) |
| Comms | NoticesScreen (list + publish), ComplaintsScreen (parent files, staff resolves), ParentHomeScreen (children summary cards) |
| Reports | ReportsHomeScreen hub |
| Audit | AuditLogScreen (principal only) |

## Print documents (`lib/printing/`)

All carry the logo header + ® school name.

- `receipt_single.dart` — full-size **Urdu** fee receipt (RTL), previewed with
  Print/Share right after each collection.
- `receipt_batch.dart` — compact **Urdu** receipts, **6 per A4** (2x3 grid).
- `leaving_certificate.dart` — English formal certificate; principal
  signature block "Mrs. Hajra Iqbal" + school stamp box.
- `result_monthly.dart` — English monthly result (subjects, %, grade, position).
- `result_annual.dart` — English annual result card + grading-scale legend.
- `progress_annual_urdu.dart` — **Urdu RTL** annual progress report
  (سالانہ ترقی رپورٹ): subject marks, attendance %, conduct, teacher remarks.
- `fee_collection_report.dart` — English whole-school class-wise collection
  table + totals.

Print flow: **single receipt** is offered automatically after each individual
fee collection; **batch (6-per-A4)** is offered from Fees → Batch Receipts.

## Roles

`principal` · `administrator` (no audit log) · `teacher` (attendance, students
view-only, academics, exams, notices) · `accountant` (fees, expenses, salaries,
P&L, reports) · `parent` (children summary, notices, complaints). Server is the
final authority on permissions; the app gates screens/menus and the most
sensitive figures (P&L, audit) via `RoleGate`.

## Known limitations / to verify on a real device

1. **Not compiled here** — run `flutter analyze` and fix anything it flags
   (most likely candidates: dependency version resolution; the pubspec uses
   wide ranges so `flutter pub get` picks what fits your Flutter SDK).
2. The write queue is the SQLite `sync_queue` table (survives restarts and
   app-data clearing only if the DB file survives); a legacy
   `shared_preferences` attendance queue from the old online-first build is
   migrated once on first launch of this version.
3. Urdu PDF output should be visually checked once (receipt + annual progress
   report) to confirm shaping/alignment with the bundled Amiri font.
