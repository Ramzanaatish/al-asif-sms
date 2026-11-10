# Al-Asif SMS — Windows app

The same Flutter codebase builds both the Android APK and the Windows desktop
app. Screens, fees, attendance, reports and the database are identical on
both. The only platform difference is the SQLite engine: Android uses the
platform `sqflite`, Windows uses the same API over FFI
(`sqflite_common_ffi`, see `app/lib/services/db_factory.dart`).

## Where the data lives

The database file `alasif_sms.db` lives in the app's data folder, **outside**
the install folder:

- Windows: `%APPDATA%\com.alasif.schoolms\` (via `getDatabasesPath()`)
- Android: the app's private data folder

Installing a new version over the old one never touches that folder, so an
update can never delete students, attendance, fees or receipts. Uninstalling
the app does delete it — keep a `.alasif` backup (Settings → Backup now).

## Schema updates

`app/lib/services/local_db.dart` keeps a `_migrations` map and an `onUpgrade`
handler. When the schema version is raised, the old database file is first
copied aside (`alasif_sms.db.bak-v<old>`), then the migration steps run in
order. Migrations must only add things — never drop a table or delete rows.

## Builds (GitHub Actions, on every push to main)

- `build-apk.yml` → APK artifact `alasif-apk`
- `build-windows.yml` → Windows artifact `alasif-windows` (a folder:
  `alasif_sms.exe` plus its DLLs and data folder)

Download the artifact from the Actions run, unzip, and run `alasif_sms.exe`.
To update: unzip the new artifact over the old folder. Do not delete the
folder first — the database is not inside it, but the install folder itself
is replaced by the new files.

## Checking for updates in the app

Settings → App & Updates → Check for updates. The app reads the latest
release on GitHub and reports whether a newer version exists. It never
downloads or installs anything itself.

## Moving data between phone and PC

Settings → Backup now creates a `.alasif` file (whole database). Copy that
file to the other device and use Settings → Import backup. The file is
checked for schema version and checksum before it restores anything.

## CSV backup (download / upload)

Settings → CSV backup:

- **Export CSV backup** downloads one zip holding one `.csv` file per
  table (students.csv, fee_challans.csv, ...). Unzip it and every file
  opens in Excel; Urdu text is written with a UTF-8 BOM so Excel shows it
  correctly.
- **Import CSV backup** uploads such a zip. The headers are checked
  against the real columns first, and only then does every table in the
  file replace that table's rows (after a confirmation). A broken file
  changes nothing.

Use CSV when you want to look at the data in Excel, fix a name or a
number by hand, and import it back. The `.alasif` backup stays the main
backup — it also carries the checksum and schema version.
