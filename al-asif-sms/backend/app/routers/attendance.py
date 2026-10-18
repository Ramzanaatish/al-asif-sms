import datetime as dt

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import audit, get_current_user, require_roles
from ..database import get_db
from ..models import (AlertQueue, FeeChallan, Holiday, StaffAttendance, Student, StudentAttendance, User)
from ..schemas import AbsentAlertIn, HolidayIn, StaffAttIn, StudentAttIn

router = APIRouter(prefix="/api/attendance", tags=["attendance"])
STAFF = require_roles("principal", "administrator", "teacher")


@router.post("/students")
def mark_student_attendance(data: StudentAttIn, db: Session = Depends(get_db),
                            user: User = Depends(STAFF)):
    saved = 0
    for r in data.records:
        if not r.student_id:
            continue
        a = db.query(StudentAttendance).filter(
            StudentAttendance.date == data.date,
            StudentAttendance.student_id == r.student_id).first()
        leave_type = r.leave_type if r.status == "leave" else None
        if a:
            a.status = r.status
            a.leave_type = leave_type
        else:
            db.add(StudentAttendance(date=data.date, student_id=r.student_id,
                                     status=r.status, leave_type=leave_type,
                                     marked_by=user.id))
        saved += 1
    db.commit()
    audit(db, user, "mark_student_attendance", "attendance", None,
          f"{saved} records on {data.date} class {data.class_id}")
    return {"saved": saved}


@router.get("/students")
def get_student_attendance(date: dt.date, class_id: int | None = None,
                           section_id: int | None = None,
                           db: Session = Depends(get_db),
                           user: User = Depends(get_current_user)):
    q = db.query(StudentAttendance, Student).join(
        Student, Student.id == StudentAttendance.student_id).filter(
        StudentAttendance.date == date)
    if class_id:
        q = q.filter(Student.class_id == class_id)
    if section_id:
        q = q.filter(Student.section_id == section_id)
    return [{"student_id": s.id, "name": s.name,
             "class_name": s.school_class.name if s.school_class else "",
             "status": a.status, "leave_type": a.leave_type} for a, s in q.all()]


@router.post("/staff")
def mark_staff_attendance(data: StaffAttIn, db: Session = Depends(get_db),
                          user: User = Depends(require_roles("principal", "administrator"))):
    saved = 0
    for r in data.records:
        if not r.staff_id:
            continue
        a = db.query(StaffAttendance).filter(
            StaffAttendance.date == data.date,
            StaffAttendance.staff_id == r.staff_id).first()
        if a:
            a.status = r.status
        else:
            db.add(StaffAttendance(date=data.date, staff_id=r.staff_id,
                                   status=r.status, marked_by=user.id))
        saved += 1
    db.commit()
    audit(db, user, "mark_staff_attendance", "attendance", None, f"{saved} on {data.date}")
    return {"saved": saved}


@router.get("/staff")
def get_staff_attendance(date: dt.date, db: Session = Depends(get_db),
                         user: User = Depends(require_roles("principal", "administrator"))):
    from ..models import Staff
    rows = db.query(StaffAttendance, Staff).join(
        Staff, Staff.id == StaffAttendance.staff_id).filter(
        StaffAttendance.date == date).all()
    return [{"staff_id": s.id, "name": s.name, "staff_type": s.staff_type,
             "status": a.status} for a, s in rows]


@router.post("/alerts/absent")
def queue_absent_alerts(data: AbsentAlertIn, db: Session = Depends(get_db),
                        user: User = Depends(STAFF)):
    """Queue SMS/WhatsApp absence alerts for guardians of absent students.

    A separate worker (or the Flutter app via a messaging plugin) picks up
    queued rows and sends them through the school's SMS/WhatsApp provider.
    """
    rows = db.query(StudentAttendance, Student).join(
        Student, Student.id == StudentAttendance.student_id).filter(
        StudentAttendance.date == data.date,
        StudentAttendance.status == "absent").all()
    queued = 0
    for a, s in rows:
        if not s.guardian_phone:
            continue
        msg = (f"AL-ASIF SCHOOL: Assalam-o-Alaikum, {s.name} (Class "
               f"{s.school_class.name if s.school_class else ''}) was absent on "
               f"{data.date}. Please contact the school office.")
        db.add(AlertQueue(channel=data.channel, recipient_phone=s.guardian_phone,
                          message=msg))
        queued += 1
    db.commit()
    audit(db, user, "queue_absent_alerts", "alert", None, f"{queued} queued for {data.date}")
    return {"queued": queued}


@router.get("/alerts")
def list_alerts(status: str | None = None, db: Session = Depends(get_db),
                user: User = Depends(require_roles("principal", "administrator"))):
    q = db.query(AlertQueue)
    if status:
        q = q.filter(AlertQueue.status == status)
    q = q.order_by(AlertQueue.created_at.desc()).limit(200)
    return [{"id": a.id, "channel": a.channel, "recipient_phone": a.recipient_phone,
             "message": a.message, "status": a.status,
             "created_at": a.created_at} for a in q.all()]


def _holiday_dates(db: Session, start: dt.date, end: dt.date) -> list[dict]:
    """All holiday dates in [start, end), expanding ranges."""
    out = []
    for h in db.query(Holiday).filter(Holiday.date < end).all():
        h_end = h.end_date or h.date
        d = max(h.date, start)
        last = min(h_end, end - dt.timedelta(days=1))
        while d <= last:
            out.append({"date": d.isoformat(), "kind": h.kind,
                        "description": h.description or ""})
            d += dt.timedelta(days=1)
    return out


@router.post("/holidays")
def add_holiday(data: HolidayIn, db: Session = Depends(get_db),
                user: User = Depends(require_roles("principal", "administrator"))):
    if data.end_date and data.end_date < data.date:
        raise HTTPException(400, "end_date cannot be before date")
    h = Holiday(date=data.date, end_date=data.end_date, kind=data.kind,
                description=data.description, created_by=user.id)
    db.add(h); db.commit(); db.refresh(h)
    audit(db, user, "add_holiday", "holiday", h.id, f"{h.kind} {h.date}")
    return {"id": h.id, "date": h.date.isoformat(), "kind": h.kind}


@router.get("/holidays")
def list_holidays(month: int, year: int, db: Session = Depends(get_db),
                  user: User = Depends(STAFF)):
    start = dt.date(year, month, 1)
    end = (start + dt.timedelta(days=32)).replace(day=1)
    return _holiday_dates(db, start, end)


@router.delete("/holidays/{hid}")
def delete_holiday(hid: int, db: Session = Depends(get_db),
                   user: User = Depends(require_roles("principal", "administrator"))):
    h = db.query(Holiday).filter(Holiday.id == hid).first()
    if not h:
        raise HTTPException(404, "Holiday not found")
    db.delete(h); db.commit()
    audit(db, user, "delete_holiday", "holiday", hid, "")
    return {"deleted": hid}


@router.get("/monthly")
def monthly_report(month: int, year: int, class_id: int | None = None,
                   db: Session = Depends(get_db), user: User = Depends(STAFF)):
    start = dt.date(year, month, 1)
    end = (start + dt.timedelta(days=32)).replace(day=1)
    holidays = _holiday_dates(db, start, end)
    holiday_set = {h["date"] for h in holidays}
    q = db.query(Student)
    if class_id:
        q = q.filter(Student.class_id == class_id)
    students = q.filter(Student.status == "active").order_by(Student.name).all()
    marked_dates = db.query(StudentAttendance.date).filter(
        StudentAttendance.date >= start, StudentAttendance.date < end).distinct().all()
    days = sum(1 for (d,) in marked_dates if d.isoformat() not in holiday_set)
    out = []
    for s in students:
        recs = db.query(StudentAttendance).filter(
            StudentAttendance.student_id == s.id,
            StudentAttendance.date >= start, StudentAttendance.date < end).all()
        present = sum(1 for r in recs if r.status == "present")
        absent = sum(1 for r in recs if r.status == "absent")
        leave = sum(1 for r in recs if r.status == "leave")
        marked = present + absent + leave
        challan = db.query(FeeChallan).filter(
            FeeChallan.student_id == s.id,
            FeeChallan.month == month, FeeChallan.year == year).first()
        if challan is None or challan.status == "unpaid":
            fee_status = "Not Paid"
        elif challan.status == "partial":
            fee_status = "Partial"
        else:
            fee_status = "Paid"
        out.append({"student_id": s.id, "name": s.name,
                    "class_name": s.school_class.name if s.school_class else "",
                    "present": present, "absent": absent, "leave": leave,
                    "fee_status": fee_status,
                    "pct": round(100 * present / marked, 1) if marked else 0})
    return {"month": month, "year": year, "working_days": days,
            "holidays": holidays, "students": out}
