from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import get_current_user, require_roles
from ..database import get_db
from ..models import (DateSheetEntry, ExamTerm, Mark, SchoolClass, Student,
                      Subject, User)
from ..schemas import DateSheetIn, MarksIn, TermIn

router = APIRouter(prefix="/api/exams", tags=["exams"])
STAFF = require_roles("principal", "administrator", "teacher")


@router.get("/terms")
def terms(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return [{"id": t.id, "name": t.name, "term_type": t.term_type,
             "session_id": t.session_id, "start_date": t.start_date,
             "end_date": t.end_date} for t in db.query(ExamTerm).all()]


@router.post("/terms")
def add_term(data: TermIn, db: Session = Depends(get_db), user: User = Depends(STAFF)):
    t = ExamTerm(**data.model_dump())
    db.add(t)
    db.commit()
    db.refresh(t)
    return {"id": t.id, "name": t.name}


@router.get("/datesheets")
def datesheets(term_id: int | None = None, class_id: int | None = None,
               db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    q = db.query(DateSheetEntry)
    if term_id:
        q = q.filter(DateSheetEntry.term_id == term_id)
    if class_id:
        q = q.filter(DateSheetEntry.class_id == class_id)
    out = []
    for d in q.order_by(DateSheetEntry.exam_date).all():
        subj = db.query(Subject).get(d.subject_id)
        cls = db.query(SchoolClass).get(d.class_id)
        out.append({"id": d.id, "term_id": d.term_id,
                    "class_name": cls.name if cls else "",
                    "subject": subj.name if subj else "",
                    "exam_date": d.exam_date, "start_time": d.start_time})
    return out


@router.post("/datesheets")
def add_datesheet(data: DateSheetIn, db: Session = Depends(get_db),
                  user: User = Depends(STAFF)):
    d = DateSheetEntry(**data.model_dump())
    db.add(d)
    db.commit()
    db.refresh(d)
    return {"id": d.id}


@router.post("/marks")
def save_marks(data: MarksIn, db: Session = Depends(get_db), user: User = Depends(STAFF)):
    saved = 0
    for r in data.records:
        if r.obtained_marks < 0 or r.obtained_marks > data.total_marks:
            raise HTTPException(400, f"Invalid marks for student {r.student_id}")
    for r in data.records:
        m = db.query(Mark).filter(Mark.term_id == data.term_id,
                                  Mark.subject_id == data.subject_id,
                                  Mark.student_id == r.student_id).first()
        if m:
            m.obtained_marks = r.obtained_marks
            m.total_marks = data.total_marks
        else:
            db.add(Mark(term_id=data.term_id, class_id=data.class_id,
                        subject_id=data.subject_id, student_id=r.student_id,
                        total_marks=data.total_marks,
                        obtained_marks=r.obtained_marks))
        saved += 1
    db.commit()
    return {"saved": saved}


@router.get("/marks")
def get_marks(term_id: int, class_id: int, subject_id: int,
              db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    marks = db.query(Mark).filter(Mark.term_id == term_id,
                                  Mark.class_id == class_id,
                                  Mark.subject_id == subject_id).all()
    return [{"student_id": m.student_id, "obtained_marks": m.obtained_marks,
             "total_marks": m.total_marks} for m in marks]


def _result_rows(db: Session, term_ids: list[int], class_id: int):
    students = db.query(Student).filter(Student.class_id == class_id,
                                        Student.status == "active").order_by(Student.name).all()
    subjects = db.query(Subject).filter(Subject.class_id == class_id).all()
    rows = []
    for s in students:
        marks = {}
        total = obtained = 0.0
        for subj in subjects:
            ms = db.query(Mark).filter(Mark.term_id.in_(term_ids),
                                       Mark.student_id == s.id,
                                       Mark.subject_id == subj.id).all()
            om = sum(m.obtained_marks for m in ms)
            tm = sum(m.total_marks for m in ms) or 0
            marks[subj.name] = {"obtained": om, "total": tm}
            obtained += om
            total += tm
        pct = round(100 * obtained / total, 1) if total else 0
        rows.append({"student_id": s.id, "name": s.name, "admission_no": s.admission_no,
                     "marks": marks, "total": total, "obtained": obtained,
                     "pct": pct, "grade": _grade(pct)})
    rows.sort(key=lambda r: r["pct"], reverse=True)
    for i, r in enumerate(rows, 1):
        r["position"] = i
    return rows, [s.name for s in subjects]


def _grade(pct: float) -> str:
    if pct >= 90:
        return "A+"
    if pct >= 80:
        return "A"
    if pct >= 70:
        return "B"
    if pct >= 60:
        return "C"
    if pct >= 50:
        return "D"
    if pct >= 33:
        return "E"
    return "F"


@router.get("/results/monthly")
def monthly_result(term_id: int, class_id: int, db: Session = Depends(get_db),
                   user: User = Depends(get_current_user)):
    term = db.query(ExamTerm).get(term_id)
    cls = db.query(SchoolClass).get(class_id)
    rows, subjects = _result_rows(db, [term_id], class_id)
    return {"term": term.name if term else "", "term_type": "monthly",
            "class_name": cls.name if cls else "", "subjects": subjects,
            "students": rows}


@router.get("/results/annual")
def annual_result(class_id: int, session_id: int | None = None,
                  db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    q = db.query(ExamTerm).filter(ExamTerm.term_type == "annual")
    if session_id:
        q = q.filter(ExamTerm.session_id == session_id)
    term_ids = [t.id for t in q.all()]
    if not term_ids:
        raise HTTPException(404, "No annual term found")
    cls = db.query(SchoolClass).get(class_id)
    rows, subjects = _result_rows(db, term_ids, class_id)
    return {"term_type": "annual", "class_name": cls.name if cls else "",
            "subjects": subjects, "students": rows}


@router.get("/analytics")
def analytics(term_id: int, class_id: int, db: Session = Depends(get_db),
              user: User = Depends(STAFF)):
    rows, subjects = _result_rows(db, [term_id], class_id)
    subj_avgs = []
    for subj in subjects:
        vals = [r["marks"][subj]["obtained"] for r in rows
                if r["marks"][subj]["total"]]
        pcts = [100 * r["marks"][subj]["obtained"] / r["marks"][subj]["total"]
                for r in rows if r["marks"][subj]["total"]]
        subj_avgs.append({"subject": subj,
                          "avg_pct": round(sum(pcts) / len(pcts), 1) if pcts else 0})
    passed = sum(1 for r in rows if r["pct"] >= 33)
    return {"subject_averages": subj_avgs,
            "pass_pct": round(100 * passed / len(rows), 1) if rows else 0,
            "top_students": [{"name": r["name"], "pct": r["pct"]} for r in rows[:5]]}
