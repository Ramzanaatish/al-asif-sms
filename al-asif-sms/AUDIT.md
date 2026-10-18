# Audit notes (backend verified by running tests; Flutter changes NOT compiled)

## Fixed
Backend: bcrypt pin (seed/login crash), fees `_challan_out` missing (collect/challans 500), staff route order (/leaves,/salaries 422),
notices/alerts `.limit()` before `.filter()` (500), student PUT wiping admission_no (500), parent could list all students,
holiday errors returned 200, salary paid_date never set, marks > total accepted, negative discount, UserOut missing linked_student_id.
Flutter: cleartext HTTP blocked on release, hardcoded emulator URL (now editable on login screen), wrong password showed
"Session expired", offline token caused forced logout during sync, stuck-offline after one timeout (retry timer),
silent op drop (now logged in audit_log as sync_dropped), backup closing DB under live queries, concurrent DB open race,
collect overpay/negative amount.

## Not fixed (design gaps)
- Pull never fetches: attendance, marks, expenses, timetable, syllabus, staff attendance. Challans/receipts/salaries only current month.
- Holiday delete of server-pulled rows never reaches server (server_id null) and reappears on next pull.
- fee_collect push not idempotent: lost response => duplicate receipt on server.
- Provisional receipt/leaving-certificate numbers can differ from server numbers after sync (printed docs mismatch).
- Backups fall back to Android/data/... which is deleted on uninstall; Documents path usually blocked on Android 11+.
- Offline credential hash = unsalted SHA-256(username:password) in SQLite.
- Seed has no subjects/sections: marks entry unusable until first online sync.
- Annual result with no session_id sums marks across all sessions' annual terms.
- Default SECRET_KEY, CORS *, default password alasif123, seed session 2025-26 expired.
- LocalDb.insert uses ConflictAlgorithm.replace: unique-index collision silently deletes the old row.
