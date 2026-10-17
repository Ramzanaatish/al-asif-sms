# Offline-First Sync Protocol — Al-Asif SMS

This document is the contract between the app's local SQLite store
(`lib/services/local_db.dart`), the synchronisation engine
(`lib/services/sync_service.dart`), the repositories (`lib/repositories/`),
and the FastAPI backend. Read it before changing any sync behaviour.

## 1. Identity model

* Every synced table has a permanent **local integer PK** (`id`) and a
  nullable `server_id` (the backend PK, filled after the first successful push
  or pull).
* **Local ids never change.** All local cross-references (challan → student,
  marks → student, attendance → student) use local ids forever.
* The `data` JSON column stores the server response shape but with `id`
  rewritten to the **local** id, so existing `Model.fromJson` parsers and all
  screens work unchanged offline.
* `SyncService` translates local ↔ server ids **only at the network
  boundary** (outgoing payloads, incoming responses).

## 2. Write path (offline-first)

1. Repository writes the row to SQLite immediately (`dirty = 1`,
   `provisional = 1` for auto-numbered rows) and enqueues one op in
   `sync_queue` (`entity`, `op`, `local_id`, `payload_json`, `attempts`).
2. `SyncService.notifyDirty()` bumps the pending badge and triggers
   `syncNow()` if online.
3. `syncNow()` = **push, then pull**.

### 2.1 Op catalog (`op` column)

| op       | entity examples                                  | behaviour on push |
|----------|--------------------------------------------------|-------------------|
| `create` | students, staff, staff_leaves, salaries, sections, subjects, syllabus, timetable, fee_heads, expense_categories, expenses, holidays, exam_terms, date_sheets, notices, complaints | POST to the entity's REST endpoint after translating reference ids |
| `update` | students, staff, syllabus, complaints           | PUT `/{server_id}` |
| `delete` | (reserved)                                       | best-effort DELETE `/{server_id}` |
| `bulk`   | `attendance_students`, `attendance_staff`, `marks` | POST the whole payload to the bulk endpoint |
| `action` | see §2.2                                          | entity-specific multi-step call |

### 2.2 Action ops

| entity              | server call | notes |
|---------------------|-------------|-------|
| `challans_generate` | `POST /api/fees/challans/generate` | after success, `_reconcileChallans` pulls the month/year and matches server challans to local rows by (student, month, year), replacing provisional `challan_no` with the server's |
| `fee_collect`       | `POST /api/fees/challans/{server_id}/collect` | server's `receipt_no` wins; the local provisional receipt row is updated. Receipt server id is resolved lazily on pull by matching `receipt_no` |
| `student_mark_left` | `POST /api/students/{id}/mark-left` | server's `certificate_no` is written back into the local row for reprints |
| `student_promote`   | `POST /api/students/promote` | promoted students get `class_id = to`, section cleared locally at write time |
| `leave_decision`    | `PUT /api/staff/leaves/{id}/decision` | |
| `syllabus_status`   | `PUT /api/academics/syllabus/{id}` | |
| `complaint_resolve` | `PUT /api/comms/complaints/{id}` | |
| `absent_alerts`     | `POST /api/attendance/alerts/absent` | fire-and-forget; guardian lookup happens locally at write time |

### 2.3 Reference resolution & ordering

* Reference fields in payloads (`class_id`, `section_id`, `subject_id`,
  `student_id`, `staff_id`, `teacher_id`, `term_id`, `challan_id`,
  `category_id`) are translated local → server at push time.
* An op whose referenced row has **no `server_id` yet is skipped for that
  pass**; pushes run in FIFO order with up to 10 repeat passes, so a create
  followed by a dependent op resolves in the same sync run.
* Fields the server derives from the JWT (`issued_by`, `received_by`,
  `marked_by`, `published_by`, `decided_by`, `parent_user_id`, …) are stripped
  from outgoing payloads and never sent.
* **Idempotency:** before pushing a `create`, the queue checks whether the
  row already has a `server_id` (a previous push may have succeeded before its
  ack) and drops the op if so. A queue row is deleted immediately after its
  push succeeds.

### 2.4 Failure handling

* `NetworkException` aborts the whole sync run; everything stays queued.
* `ApiException` 404, or any `ApiException` after 5 attempts, drops the op
  (gone on server / persistently invalid) so one bad op can never block the
  queue forever.

## 3. Provisional numbering protocol

Auto numbers are generated **locally in the server's format**, flagged
`provisional = 1`, and corrected after sync:

| number | local format | server format | reconciliation |
|--------|--------------|---------------|----------------|
| admission_no | `AS-YYYY-NNNN` (local per-year sequence in `meta`, seeded from bundled seed + advanced past pulled rows on every pull) | same | on `POST /api/students` 400 (duplicate), the create is retried **without** the number; the server-assigned `admission_no` from the response is written back to the local row |
| challan_no | `CH-YYYYMM-SSSSS` (local student id, zero-padded) | same shape with server student id | after `challans_generate`, reconcile by (student, month, year): server `challan_no` replaces the provisional one |
| receipt_no | `R-CCCCCC-NNN` (local challan id + local per-receipt sequence) | `R-<server challan>-<n>` | on `fee_collect`, the response's `receipt_no` replaces the provisional one immediately |
| certificate_no | `LC-SSSSS-YYYY` (local student id) | same shape with server student id | on `mark-left` push, the server's `certificate_no` is written back for reprints; the printed paper keeps the number issued at print time |

Screens and printed documents (Urdu fee receipt, leaving certificate) always
show whatever number the local row carries, so they work fully offline. The
server value is authoritative once synced.

## 4. Read path (pull)

After pushing, the engine pulls (in this order): classes (+ nested sections),
subjects, fee heads, expense categories, exam terms, notices, complaints,
staff leaves, date sheets, students (`?status=all`), staff (`?status=all`),
holidays (current and next month), salaries (current month), challans and
receipts (current month/year).

* Upsert is by `server_id`; the pulled row's `data` JSON is rewritten to the
  local id before storage.
* **Seed linking:** the bundled first-run seed (classes, fee heads, expense
  categories) has no `server_id`. On pull, clean (`dirty = 0`) local rows are
  matched to server rows by natural key (classes/sections/subjects/fee
  heads/expense categories/exam terms by name, sections/subjects additionally
  scoped to class) and adopt the server id instead of duplicating. If a full
  push pass stalls on unresolved references, one mid-run pull is attempted to
  link seeds before retrying the queue.
* **Conflict rule: server wins, except a local row with `dirty = 1` is never
  overwritten** — the local edit stays and will be pushed on the next run.
  Natural-key linking likewise never touches dirty rows.
* Marks and attendance **history** are not pulled (too large); the local
  device is the source of truth for what it marked. Master data and current
  fee state are pulled.
* Pull failures for optional endpoints are tolerated (skipped); a failed pull
  never rolls back a successful push.

## 5. Offline login

* Successful **online** login caches `sha256(username:password)` plus the
  user profile in SQLite (`meta`).
* Offline, login verifies the password against the cached hash and issues a
  local session (`access_token = 'offline'`). A wrong password still fails;
  online 401 behaviour is unchanged. The password itself is never stored.
* The cached profile/role drives offline screens (notice audience filter,
  parent complaint filter, linked student). The UI shows an **"Offline mode"**
  banner while offline.

## 6. First-run seed

If the database is empty at first open, it is seeded from the bundled
`assets/seed.json` (classes with official student counts, expense categories,
fee heads) so admissions, attendance and fee collection work before the
device ever goes online.

## 7. UI contract

* `SyncService` is a `ChangeNotifier` provided app-wide:
  `isOnline`, `isSyncing`, `pendingCount`, `lastSyncAt`, `lastError`.
* `HomeShell` shows an app-wide sync badge (tap = force sync) and a slim
  offline banner. Per-screen behaviour is unchanged; screens never call the
  network directly — only repositories do.
