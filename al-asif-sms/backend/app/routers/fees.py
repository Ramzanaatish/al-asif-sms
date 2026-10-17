import datetime as dt

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import audit, get_current_user, require_roles
from ..database import get_db
from ..models import FeeChallan, FeeHead, FeeReceipt, SchoolClass, Student, User
from ..schemas import ChallanGenIn, CollectIn, FeeHeadIn

router = APIRouter(prefix="/api/fees", tags=["fees"])
FINANCE = require_roles("principal", "administrator", "accountant")


@router.get("/heads")
def heads(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return [{"id": h.id, "name": h.name, "amount": h.amount,
             "frequency": h.frequency, "class_id": h.class_id} for h in db.query(FeeHead).all()]


@router.post("/heads")
def add_head(data: FeeHeadIn, db: Session = Depends(get_db), user: User = Depends(FINANCE)):
    h = FeeHead(**data.model_dump())
    db.add(h)
    db.commit()
    db.refresh(h)
    return {"id": h.id, "name": h.name}


def _receipt_out(r: FeeReceipt, c: FeeChallan, received_by_name: str) -> dict:
    s = c.student
    balance = round(c.total_amount - c.discount - c.amount_paid, 2)
    return {"receipt_no": r.receipt_no, "amount": r.amount,
            "payment_method": r.payment_method, "received_at": r.received_at,
            "received_by": received_by_name,
            "student_name": s.name if s else "",
            "admission_no": s.admission_no if s else "",
            "class_name": s.school_class.name if s and s.school_class else "",
            "guardian_name": s.guardian_name if s else "",
            "month": c.month, "year": c.year,
            "total_amount": c.total_amount, "discount": c.discount,
            "balance": balance,
            "school": "AL-ASIF PUBLIC MIDDLE SCHOOL BASTI SHAIKHAN (REGD.)",
            "principal": "Mrs. Hajra Iqbal"}


@router.get("/receipts")
def receipts(month: int | None = None, year: int | None = None,
             class_id: int | None = None, db: Session = Depends(get_db),
             user: User = Depends(FINANCE)):
    """Receipt data for reprint / batch printing (6-per-A4)."""
    q = db.query(FeeReceipt, FeeChallan).join(
        FeeChallan, FeeReceipt.challan_id == FeeChallan.id).join(
        Student, FeeChallan.student_id == Student.id)
    if month:
        q = q.filter(FeeChallan.month == month)
    if year:
        q = q.filter(FeeChallan.year == year)
    if class_id:
        q = q.filter(Student.class_id == class_id)
    out = []
    for r, c in q.order_by(FeeReceipt.id).all():
        ru = db.query(User).get(r.received_by) if r.received_by else None
        out.append(_receipt_out(r, c, ru.full_name if ru else ""))
    return out
    balance = round(c.total_amount - c.discount - c.amount_paid, 2)
    return {"id": c.id, "challan_no": c.challan_no, "student_id": c.student_id,
            "student_name": c.student.name if c.student else "",
            "month": c.month, "year": c.year, "total_amount": c.total_amount,
            "discount": c.discount, "amount_paid": c.amount_paid,
            "balance": balance, "status": c.status}


@router.post("/challans/generate")
def generate_challans(data: ChallanGenIn, db: Session = Depends(get_db),
                      user: User = Depends(FINANCE)):
    heads = db.query(FeeHead).filter(FeeHead.id.in_(data.head_ids)).all()
    if not heads:
        raise HTTPException(400, "No valid fee heads")
    total = sum(h.amount for h in heads)
    students = db.query(Student).filter(Student.class_id == data.class_id,
                                        Student.status == "active").all()
    created = 0
    for s in students:
        exists = db.query(FeeChallan).filter(
            FeeChallan.student_id == s.id, FeeChallan.month == data.month,
            FeeChallan.year == data.year).first()
        if exists:
            continue
        c = FeeChallan(challan_no=f"CH-{data.year}{data.month:02d}-{s.id:05d}",
                       student_id=s.id, month=data.month, year=data.year,
                       due_date=dt.date(data.year, data.month, 10),
                       total_amount=total, issued_by=user.id)
        db.add(c)
        created += 1
    db.commit()
    audit(db, user, "generate_challans", "fee", None,
          f"{created} challans for class {data.class_id} {data.month}/{data.year}")
    return {"created": created, "per_student": total}


@router.get("/challans")
def challans(student_id: int | None = None, month: int | None = None,
             year: int | None = None, status: str | None = None,
             db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    q = db.query(FeeChallan)
    if student_id:
        q = q.filter(FeeChallan.student_id == student_id)
    if month:
        q = q.filter(FeeChallan.month == month)
    if year:
        q = q.filter(FeeChallan.year == year)
    if status:
        q = q.filter(FeeChallan.status == status)
    return [_challan_out(c) for c in q.order_by(FeeChallan.id.desc()).limit(500).all()]


@router.post("/challans/{cid}/collect")
def collect(cid: int, data: CollectIn, db: Session = Depends(get_db),
            user: User = Depends(FINANCE)):
    c = db.query(FeeChallan).get(cid)
    if not c:
        raise HTTPException(404, "Challan not found")
    c.discount = (c.discount or 0) + data.discount
    c.amount_paid = (c.amount_paid or 0) + data.amount
    balance = c.total_amount - c.discount - c.amount_paid
    c.status = "paid" if balance <= 0.01 else ("partial" if c.amount_paid > 0 else "unpaid")
    receipt_no = f"R-{c.id:06d}-{db.query(FeeReceipt).count() + 1:03d}"
    r = FeeReceipt(receipt_no=receipt_no, challan_id=c.id, amount=data.amount,
                   payment_method=data.payment_method, received_by=user.id)
    db.add(r)
    db.commit()
    db.refresh(r)
    audit(db, user, "collect_fee", "fee", c.id, f"{data.amount} via {data.payment_method}")
    return {"challan": _challan_out(c),
            "receipt": _receipt_out(r, c, user.full_name)}


@router.get("/defaulters")
def defaulters(month: int, year: int, db: Session = Depends(get_db),
               user: User = Depends(FINANCE)):
    rows = db.query(FeeChallan).filter(FeeChallan.month == month,
                                      FeeChallan.year == year,
                                      FeeChallan.status != "paid").all()
    out = []
    for c in rows:
        s = c.student
        out.append({"student_id": c.student_id, "name": s.name if s else "",
                    "class_name": s.school_class.name if s and s.school_class else "",
                    "guardian_phone": s.guardian_phone if s else "",
                    "balance": round(c.total_amount - c.discount - c.amount_paid, 2)})
    return out


@router.get("/collection-report")
def collection_report(month: int, year: int, db: Session = Depends(get_db),
                      user: User = Depends(FINANCE)):
    classes = db.query(SchoolClass).order_by(SchoolClass.level_order).all()
    rows, exp_total, col_total = [], 0.0, 0.0
    for cl in classes:
        challans = db.query(FeeChallan).join(Student).filter(
            Student.class_id == cl.id, FeeChallan.month == month,
            FeeChallan.year == year).all()
        expected = sum(c.total_amount - c.discount for c in challans)
        collected = sum(c.amount_paid for c in challans)
        defaulters = sum(1 for c in challans if c.status != "paid")
        rows.append({"class_name": cl.name, "expected": round(expected, 2),
                     "collected": round(collected, 2), "defaulters": defaulters})
        exp_total += expected
        col_total += collected
    return {"month": month, "year": year, "classes": rows,
            "totals": {"expected": round(exp_total, 2),
                       "collected": round(col_total, 2),
                       "pct": round(100 * col_total / exp_total, 1) if exp_total else 0}}
