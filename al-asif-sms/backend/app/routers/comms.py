from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import audit, get_current_user, require_roles
from ..database import get_db
from ..models import (Complaint, FeeChallan, Notice, Student, StudentAttendance,
                      User)
from ..schemas import ComplaintIn, ComplaintStatus, NoticeIn

router = APIRouter(prefix="/api/comms", tags=["communication"])
STAFF = require_roles("principal", "administrator", "teacher")


@router.get("/notices")
def notices(audience: str | None = None, db: Session = Depends(get_db),
            user: User = Depends(get_current_user)):
    q = db.query(Notice).order_by(Notice.created_at.desc()).limit(100)
    if user.role == "parent":
        q = q.filter(Notice.audience.in_(["all", "parents"]))
    elif audience:
        q = q.filter(Notice.audience == audience)
    return [{"id": n.id, "title": n.title, "body": n.body,
             "audience": n.audience, "created_at": n.created_at} for n in q.all()]


@router.post("/notices")
def publish_notice(data: NoticeIn, db: Session = Depends(get_db), user: User = Depends(STAFF)):
    n = Notice(**data.model_dump(), published_by=user.id)
    db.add(n)
    db.commit()
    db.refresh(n)
    audit(db, user, "publish_notice", "notice", n.id, data.title)
    return {"id": n.id, "title": n.title}


@router.get("/complaints")
def complaints(status: str | None = None, db: Session = Depends(get_db),
               user: User = Depends(get_current_user)):
    q = db.query(Complaint).order_by(Complaint.created_at.desc())
    if user.role == "parent":
        q = q.filter(Complaint.parent_user_id == user.id)
    if status:
        q = q.filter(Complaint.status == status)
    out = []
    for c in q.limit(200).all():
        out.append({"id": c.id, "subject": c.subject, "body": c.body,
                    "status": c.status, "created_at": c.created_at,
                    "student_id": c.student_id})
    return out


@router.post("/complaints")
def file_complaint(data: ComplaintIn, db: Session = Depends(get_db),
                   user: User = Depends(require_roles("parent", "principal",
                                                       "administrator"))):
    c = Complaint(parent_user_id=user.id if user.role == "parent" else None,
                  student_id=data.student_id, subject=data.subject, body=data.body)
    db.add(c)
    db.commit()
    db.refresh(c)
    return {"id": c.id, "status": c.status}


@router.put("/complaints/{cid}")
def resolve_complaint(cid: int, data: ComplaintStatus, db: Session = Depends(get_db),
                      user: User = Depends(STAFF)):
    c = db.query(Complaint).get(cid)
    if not c:
        raise HTTPException(404, "Complaint not found")
    c.status = data.status
    db.commit()
    audit(db, user, "resolve_complaint", "complaint", cid, data.status)
    return {"id": cid, "status": c.status}


@router.get("/parent/summary")
def parent_summary(db: Session = Depends(get_db),
                   user: User = Depends(require_roles("parent"))):
    # A parent account is linked to one child via User.linked_student_id
    # (set at admission time by the administrator).
    linked = []
    if user.linked_student_id:
        s = db.query(Student).get(user.linked_student_id)
        if s:
            linked = [s]
    out = []
    for s in linked:
        att = db.query(StudentAttendance).filter(
            StudentAttendance.student_id == s.id).all()
        pct = round(100 * sum(1 for a in att if a.status == "present") / len(att), 1) if att else 0
        challans = db.query(FeeChallan).filter(FeeChallan.student_id == s.id).all()
        balance = round(sum(c.total_amount - c.discount - c.amount_paid for c in challans), 2)
        out.append({"student_id": s.id, "name": s.name,
                    "class_name": s.school_class.name if s.school_class else "",
                    "attendance_pct": pct, "fee_balance": balance, "status": s.status})
    return {"children": out}
