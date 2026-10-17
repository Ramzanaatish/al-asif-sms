# Al-Asif SMS — API Contract (Flutter ↔ FastAPI)

Base URL is ONE config value: `AppConfig.apiBaseUrl` (default `http://10.0.2.2:8000` for emulator,
`http://<server-ip>:8000` on device). All endpoints below are prefixed with `/api`.
Auth: JWT Bearer token from `POST /api/auth/login`. Header: `Authorization: Bearer <token>`.

Roles: `principal`, `administrator`, `teacher`, `accountant`, `parent`.
School: AL-ASIF PUBLIC MIDDLE SCHOOL BASTI SHAIKHAN (REGD.) — Principal Mrs. Hajra Iqbal.
Classes (11): Play Group, Nursery, Prep, 1st, 2nd, 3rd, 4th, 5th, 6th, 7th, 8th.

## Auth
- POST /api/auth/login {username, password} → {access_token, token_type:"bearer", user:{id, username, full_name, role}}
- GET /api/auth/me → current user

## Students
- GET /api/students?class_id=&section_id=&status=active|left&search= → [{id, admission_no, name, gender, class_id, class_name, section_id, section_name, guardian_name, guardian_phone, status, photo_path}]
- POST /api/students {name, dob, gender, class_id, section_id, guardian_name, guardian_phone, guardian_relation, address, photo_path, documents:[{name, received:bool}]} → student (admission_no AUTO-GENERATED as AS-<year>-<seq>, e.g. AS-2026-0001; admission_date defaults to today, status defaults to active)
- GET /api/students/next-admission-no → {admission_no} (preview of the next auto ID)
- GET /api/students/{id} → full detail incl. documents, attendance_pct, fee_balance
- PUT /api/students/{id} → update
- POST /api/students/{id}/mark-left {leaving_date, reason} → {student, certificate:{certificate_no, ...}} (status → left)
- POST /api/students/promote {from_class_id, to_class_id, promoted_ids:[...], retained_ids:[...], session_id} → {promoted: n, retained: n}

## Staff
- GET /api/staff?staff_type=teaching|non_teaching&status= → [{id, name, staff_type, designation, phone, salary_monthly, status}]
- POST /api/staff {name, staff_type, designation, phone, cnic, salary_monthly, joining_date} → staff
- GET /api/staff/{id} / PUT /api/staff/{id}
- GET /api/staff/leaves?status= / POST /api/staff/leaves {staff_id, from_date, to_date, reason}
- PUT /api/staff/leaves/{id}/decision {decision: approved|rejected}
- GET /api/staff/salaries?month=&year= / POST /api/staff/salaries {staff_id, month, year, allowances, deductions} (basic = staff.salary_monthly, net computed)

## Academics
- GET /api/academics/classes → [{id, name, level_order, student_count, sections:[{id,name}]}]
- GET/POST /api/academics/sections {class_id, name}
- GET /api/academics/subjects?class_id= / POST /api/academics/subjects {class_id, name}
- GET /api/academics/syllabus?class_id=&subject_id= / POST /api/academics/syllabus {class_id, subject_id, topic}
- PUT /api/academics/syllabus/{id} {status: planned|in_progress|completed}
- GET /api/academics/timetable?class_id=&section_id= / POST /api/academics/timetable {class_id, section_id, day_of_week 0-6, period_no, subject_id, teacher_id, room}

## Attendance
- POST /api/attendance/students {date, class_id, section_id, records:[{student_id, status:present|absent|leave}]} → {saved:n}
- GET /api/attendance/students?date=&class_id=&section_id= → records
- POST /api/attendance/staff {date, records:[{staff_id, status}]}
- GET /api/attendance/staff?date=
- POST /api/attendance/alerts/absent {date} → {queued:n} (queues SMS/WhatsApp alerts to guardians of absent students)
- GET /api/attendance/monthly?month=&year=&class_id= → {month, year, working_days, holidays:[{date, kind, description}], students:[{student_id, name, class_name, present, absent, leave, fee_status, pct}]} (working_days excludes holidays)
- POST /api/attendance/holidays {date, end_date?, kind: unexpected|summer|winter|other, description?} → {id, date, kind} (principal/administrator only)
- GET /api/attendance/holidays?month=&year= → [{date, kind, description}] (ranges expanded)
- DELETE /api/attendance/holidays/{id} → {deleted} (principal/administrator only)

## Exams
- GET/POST /api/exams/terms {name, term_type:monthly|annual, session_id, start_date, end_date}
- GET /api/exams/datesheets?term_id=&class_id= / POST /api/exams/datesheets {term_id, class_id, subject_id, exam_date, start_time}
- POST /api/exams/marks {term_id, class_id, subject_id, total_marks, records:[{student_id, obtained_marks}]} → {saved:n}
- GET /api/exams/marks?term_id=&class_id=&subject_id=
- GET /api/exams/results/monthly?term_id=&class_id= → {term, class, subjects:[...], students:[{student_id, name, marks:{subject:obtained}, total, obtained, pct, position}]}
- GET /api/exams/results/annual?class_id=&session_id= → same shape, aggregated over annual term(s)
- GET /api/exams/analytics?term_id=&class_id= → {subject_averages:[{subject, avg_pct}], pass_pct, top_students}

## Fees
- GET/POST /api/fees/heads {name, amount, frequency:monthly|annual|onetime, class_id?}
- POST /api/fees/challans/generate {class_id, month, year, head_ids:[...]} → {created:n}
- GET /api/fees/challans?student_id=&month=&year=&status=unpaid|partial|paid → [{id, challan_no, student_id, student_name, month, year, total_amount, discount, amount_paid, balance, status}]
- POST /api/fees/challans/{id}/collect {amount, discount, payment_method:cash|bank|online} → {receipt:{receipt_no, ...}} (Urdu receipt data)
- GET /api/fees/defaulters?month=&year= → [{student_id, name, class_name, guardian_phone, balance}]
- GET /api/fees/collection-report?month=&year= → {month, year, classes:[{class_name, expected, collected, defaulters}], totals:{expected, collected, pct}}
- GET /api/fees/receipts?month=&year=&class_id= → [receipt objects] (same shape as the `receipt` in collect response; for reprint and batch 6-per-A4 printing)

## Expenses & P&L
- GET/POST /api/expenses/categories {name}
- GET /api/expenses?month=&year=&category_id= / POST /api/expenses {category_id, date, amount, description, paid_to}
- GET /api/expenses/profit-loss?month=&year= → {month, year, fee_collected, expenses_total, salaries_total, total_outgoing, net_profit}

## Communication
- GET /api/comms/notices?audience= / POST /api/comms/notices {title, body, audience:all|parents|staff}
- GET/POST /api/comms/complaints {student_id, subject, body} (parent); PUT /api/comms/complaints/{id} {status:open|resolved} (staff)
- GET /api/comms/parent/summary → for logged-in parent: {children:[{student_id, name, class_name, attendance_pct, fee_balance, last_result_pct}]}

## Dashboard
- GET /api/dashboard/principal → {total_students, total_staff, fee_collected_month, attendance_pct_today, staff_present_today, profit_month, defaulters_count}

## Audit
- GET /api/audit?limit=100 → [{id, user, action, entity, entity_id, created_at}] (key actions auto-logged)

## Print data endpoints (same JSON as above; Flutter renders PDFs locally)
- Leaving certificate data: from POST /api/students/{id}/mark-left response
- Urdu fee receipt data: from POST /api/fees/challans/{id}/collect response
- Monthly/annual result data: /api/exams/results/*
- Fee collection report: /api/fees/collection-report
