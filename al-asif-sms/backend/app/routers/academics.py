from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import audit, require_roles
from ..database import get_db
from ..models import SchoolClass, Section, Subject, SyllabusItem, TimetableEntry, User
from ..schemas import SectionIn, SubjectIn, SyllabusIn, SyllabusStatus, TimetableIn

router = APIRouter(prefix="/api/academics", tags=["academics"])
STAFF = require_roles("principal", "administrator", "teacher")


@router.get("/classes")
def classes(db: Session = Depends(get_db), user=Depends(require_roles(
        "principal", "administrator", "teacher", "accountant", "parent"))):
    out = []
    for c in db.query(SchoolClass).order_by(SchoolClass.level_order).all():
        out.append({"id": c.id, "name": c.name, "level_order": c.level_order,
                    "student_count": c.student_count,
                    "sections": [{"id": s.id, "name": s.name} for s in c.sections]})
    return out


@router.post("/sections")
def add_section(data: SectionIn, db: Session = Depends(get_db), user: User = Depends(STAFF)):
    sec = Section(**data.model_dump())
    db.add(sec)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(400, "Section already exists for this class")
    db.refresh(sec)
    audit(db, user, "add_section", "section", sec.id, data.name)
    return {"id": sec.id, "class_id": sec.class_id, "name": sec.name}


@router.get("/subjects")
def subjects(class_id: int | None = None, db: Session = Depends(get_db),
             user: User = Depends(STAFF)):
    q = db.query(Subject)
    if class_id:
        q = q.filter(Subject.class_id == class_id)
    return [{"id": s.id, "class_id": s.class_id, "name": s.name} for s in q.all()]


@router.post("/subjects")
def add_subject(data: SubjectIn, db: Session = Depends(get_db), user: User = Depends(STAFF)):
    s = Subject(**data.model_dump())
    db.add(s)
    db.commit()
    db.refresh(s)
    return {"id": s.id, "class_id": s.class_id, "name": s.name}


@router.get("/syllabus")
def syllabus(class_id: int | None = None, subject_id: int | None = None,
             db: Session = Depends(get_db), user: User = Depends(STAFF)):
    q = db.query(SyllabusItem)
    if class_id:
        q = q.filter(SyllabusItem.class_id == class_id)
    if subject_id:
        q = q.filter(SyllabusItem.subject_id == subject_id)
    return [{"id": i.id, "class_id": i.class_id, "subject_id": i.subject_id,
             "topic": i.topic, "status": i.status} for i in q.all()]


@router.post("/syllabus")
def add_syllabus(data: SyllabusIn, db: Session = Depends(get_db), user: User = Depends(STAFF)):
    i = SyllabusItem(**data.model_dump())
    db.add(i)
    db.commit()
    db.refresh(i)
    return {"id": i.id, "topic": i.topic, "status": i.status}


@router.put("/syllabus/{sid}")
def syllabus_status(sid: int, data: SyllabusStatus, db: Session = Depends(get_db),
                    user: User = Depends(STAFF)):
    i = db.query(SyllabusItem).get(sid)
    if not i:
        raise HTTPException(404, "Not found")
    i.status = data.status
    db.commit()
    return {"id": sid, "status": i.status}


@router.get("/timetable")
def timetable(class_id: int | None = None, section_id: int | None = None,
              db: Session = Depends(get_db), user: User = Depends(STAFF)):
    q = db.query(TimetableEntry)
    if class_id:
        q = q.filter(TimetableEntry.class_id == class_id)
    if section_id:
        q = q.filter(TimetableEntry.section_id == section_id)
    out = []
    for t in q.order_by(TimetableEntry.day_of_week, TimetableEntry.period_no).all():
        subj = db.query(Subject).get(t.subject_id) if t.subject_id else None
        out.append({"id": t.id, "class_id": t.class_id, "section_id": t.section_id,
                    "day_of_week": t.day_of_week, "period_no": t.period_no,
                    "subject": subj.name if subj else "", "teacher_id": t.teacher_id,
                    "room": t.room})
    return out


@router.post("/timetable")
def add_timetable(data: TimetableIn, db: Session = Depends(get_db),
                  user: User = Depends(require_roles("principal", "administrator"))):
    t = TimetableEntry(**data.model_dump())
    db.add(t)
    db.commit()
    db.refresh(t)
    return {"id": t.id}
