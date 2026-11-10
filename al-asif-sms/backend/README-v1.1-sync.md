# Al-Asif SMS — Backend v1.1 (Sync)

FastAPI server that the Al-Asif APK (phones), the Windows software and the
Complete HTML v6 file all sync against. One server, one database — every
client reads and writes the same students, attendance, marks, challans,
staff and expenses.

## What changed in v1.1 (vs the repo's v1.0)
- Student record gained 6 optional fields so the HTML software loses nothing
  in sync: B-Form (`b_form`), Urdu name (`name_urdu`), Urdu father name
  (`father_urdu`), mother name (`mother_name`), mother Urdu name
  (`mother_name_urdu`), group (`group_name`). All nullable — old clients
  are unaffected.
- `seed.py` now creates one login per class teacher (usernames are name
  slugs: miss-asia, miss-nadia-ali, mrs-mehwish-sharif, miss-shakila,
  miss-uzma, miss-nadia-jamil, miss-akeela, miss-zunaira, mrs-saima-iqbal),
  all with password `teacher123`. Principal login stays `principal` /
  `alasif123`. **Change both passwords after the first login.**
- The seed loads the school's real register students (227).

## Run (Windows PC)
See `Al-Asif-Server-PC-Steps.txt` (delivered alongside this zip) for the
numbered, paste-ready steps. Short version:
1. Python 3.12+ installed, "Add Python to PATH" ticked.
2. `python -m venv venv` then `venv\Scripts\activate`.
3. `pip install -r requirements.txt`
4. Copy `.env.example` to `.env`, put a real random SECRET_KEY in it
   (generate one with `python -c "import secrets; print(secrets.token_urlsafe(32))"`).
5. `python seed.py` (creates the database + 227 students + logins).
6. `uvicorn app.main:app --host 0.0.0.0 --port 8000`
7. Test in a browser: http://127.0.0.1:8000/api/health
   (from a phone on the same WiFi: http://<PC-LAN-IP>:8000/api/health)

## Notes
- Database is SQLite (`alasif_sms.db` in this folder) — no Postgres needed.
- The server must be running and the PC on for phones to sync. Each client
  works offline and syncs when it can reach the server.
- Photos are never uploaded by any client — they stay on the device/file
  where they were added.
- Teachers can sync students, attendance and marks. Fees (challan generate /
  collect) and staff/expense setup need the principal login.
