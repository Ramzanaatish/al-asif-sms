import datetime as dt

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import audit, get_current_user, require_roles
from ..database import get_db
from ..models import FeeChallan, SchoolClass, Section, Student, StudentAttendance, User
from ..schemas import MarkLeftIn, PromoteIn, StudentIn, StudentOut

router = APIRouter(prefix="/api/students", tags=["students"])
STAFF = require_roles("principal", "administrator", "teacher", "accountant")


def _out(s: Student) -> dict:
    return {"id": s.id, "admission_no": s.admission_no, "name": s.name,
            "roll_number": s.roll_number,
            "gender": s.gender, "class_id": s.class_id,
            "class_name": s.school_class.name if s.school_class else "",
            "section_id": s.section_id,
            "section_name": s.section.name if s.section else "",
            "guardian_name": s.guardian_name, "guardian_phone": s.guardian_phone,
            "status": s.status}


@router.get("")
def list_students(class_id: int | None = None, section_id: int | None = None,
                  status: str = "active", search: str | None = None,
                  db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if user.role == "parent":
        raise HTTPException(403, "Not allowed for this role")
    q = db.query(Student)
    if status != "all":
        q = q.filter(Student.status == status)
    if class_id:
        q = q.filter(Student.class_id == class_id)
    if section_id:
        q = q.filter(Student.section_id == section_id)
    if search:
        q = q.filter(Student.name.ilike(f"%{search}%") |
                      Student.admission_no.ilike(f"%{search}%"))
    q = q.order_by(Student.roll_number.nulls_last(), Student.name)
    return [_out(s) for s in q.all()]


@router.post("")
def admit(data: StudentIn, db: Session = Depends(get_db), user: User = Depends(STAFF)):
    payload = data.model_dump()
    if payload.get("admission_no"):
        if db.query(Student).filter(Student.admission_no == payload["admission_no"]).first():
            raise HTTPException(400, "Admission number already exists")
    else:
        payload["admission_no"] = _next_admission_no(db)
    s = Student(**payload)
    db.add(s)
    db.commit()
    db.refresh(s)
    audit(db, user, "admit_student", "student", s.id, f"{s.name} ({s.admission_no})")
    return _out(s)


def _next_admission_no(db: Session) -> str:
    """Auto student ID: AS-<year>-<seq>, e.g. AS-2026-0001."""
    year = dt.date.today().year
    prefix = f"AS-{year}-"
    seqs = []
    for (no,) in db.query(Student.admission_no).filter(
            Student.admission_no.like(f"{prefix}%")).all():
        try:
            seqs.append(int(no.rsplit("-", 1)[1]))
        except (ValueError, IndexError):
            pass
    nxt = max(seqs, default=0) + 1
    while db.query(Student).filter(
            Student.admission_no == f"{prefix}{nxt:04d}").first():
        nxt += 1
    return f"{prefix}{nxt:04d}"


@router.get("/next-admission-no")
def next_admission_no(db: Session = Depends(get_db), user: User = Depends(STAFF)):
    return {"admission_no": _next_admission_no(db)}


@router.get("/{sid}")
def get_student(sid: int, db: Session = Depends(get_db),
                user: User = Depends(get_current_user)):
    if user.role == "parent" and user.linked_student_id != sid:
        raise HTTPException(403, "Not allowed for this role")
    s = db.query(Student).get(sid)
    if not s:
        raise HTTPException(404, "Student not found")
    att = db.query(StudentAttendance).filter(StudentAttendance.student_id == sid).all()
    pct = round(100 * sum(1 for a in att if a.status == "present") / len(att), 1) if att else 0
    challans = db.query(FeeChallan).filter(FeeChallan.student_id == sid).all()
    balance = round(sum(c.total_amount - c.discount - c.amount_paid for c in challans), 2)
    d = _out(s)
    d.update({"dob": s.dob, "guardian_relation": s.guardian_relation, "address": s.address,
              "photo_path": s.photo_path, "documents": s.documents or [],
              "admission_date": s.admission_date, "leaving_date": s.leaving_date,
              "leaving_reason": s.leaving_reason, "attendance_pct": pct,
              "fee_balance": balance})
    return d


@router.put("/{sid}")
def update_student(sid: int, data: StudentIn, db: Session = Depends(get_db),
                   user: User = Depends(STAFF)):
    s = db.query(Student).get(sid)
    if not s:
        raise HTTPException(404, "Student not found")
    for k, v in data.model_dump().items():
        if k == "admission_no" and not v:
            continue  # keep the existing admission number
        if k == "admission_no" and v != s.admission_no and db.query(Student).filter(
                Student.admission_no == v, Student.id != sid).first():
            raise HTTPException(400, "Admission number already exists")
        setattr(s, k, v)
    db.commit()
    audit(db, user, "update_student", "student", sid, s.name)
    return _out(s)


@router.post("/{sid}/mark-left")
def mark_left(sid: int, data: MarkLeftIn, db: Session = Depends(get_db),
              user: User = Depends(STAFF)):
    s = db.query(Student).get(sid)
    if not s:
        raise HTTPException(404, "Student not found")
    s.status = "left"
    s.leaving_date = data.leaving_date
    s.leaving_reason = data.reason
    db.commit()
    cert_no = f"LC-{s.id:05d}-{data.leaving_date.year}"
    audit(db, user, "mark_left", "student", sid, f"{s.name}, cert {cert_no}")
    return {"student": _out(s),
            "certificate": {"certificate_no": cert_no,
                            "student_name": s.name,
                            "admission_no": s.admission_no,
                            "class_name": s.school_class.name if s.school_class else "",
                            "dob": s.dob, "guardian_name": s.guardian_name,
                            "admission_date": s.admission_date,
                            "leaving_date": data.leaving_date,
                            "reason": data.reason,
                            "school": "AL-ASIF PUBLIC MIDDLE SCHOOL BASTI SHAIKHAN (REGD.)",
                            "principal": "Mrs. Hajra Iqbal"}}


@router.post("/promote")
def promote(data: PromoteIn, db: Session = Depends(get_db),
            user: User = Depends(require_roles("principal", "administrator"))):
    from_c = db.query(SchoolClass).get(data.from_class_id)
    to_c = db.query(SchoolClass).get(data.to_class_id)
    if not from_c or not to_c:
        raise HTTPException(400, "Invalid class ids")
    promoted = retained = 0
    for sid in data.promoted_ids:
        s = db.query(Student).get(sid)
        if s and s.status == "active":
            s.class_id = to_c.id
            s.section_id = None
            promoted += 1
    for sid in data.retained_ids:
        s = db.query(Student).get(sid)
        if s and s.status == "active":
            retained += 1  # stays in the same class
    db.commit()
    audit(db, user, "promote_students", "class", from_c.id,
          f"{promoted} promoted to {to_c.name}, {retained} retained in {from_c.name}")
    return {"promoted": promoted, "retained": retained,
            "from_class": from_c.name, "to_class": to_c.name}
