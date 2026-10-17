from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import audit, require_roles
from ..database import get_db
from ..models import SalaryPayment, Staff, StaffLeave, User
from ..schemas import LeaveDecision, LeaveIn, SalaryIn, StaffIn

router = APIRouter(prefix="/api/staff", tags=["staff"])
MANAGE = require_roles("principal", "administrator")
HR = require_roles("principal", "administrator", "accountant")


def _out(s: Staff) -> dict:
    return {"id": s.id, "name": s.name, "staff_type": s.staff_type,
            "designation": s.designation, "phone": s.phone, "cnic": s.cnic,
            "salary_monthly": s.salary_monthly, "joining_date": s.joining_date,
            "status": s.status}


@router.get("")
def list_staff(staff_type: str | None = None, status: str = "active",
               db: Session = Depends(get_db), user: User = Depends(HR)):
    q = db.query(Staff)
    if staff_type:
        q = q.filter(Staff.staff_type == staff_type)
    if status != "all":
        q = q.filter(Staff.status == status)
    return [_out(s) for s in q.order_by(Staff.name).all()]


@router.post("")
def add_staff(data: StaffIn, db: Session = Depends(get_db), user: User = Depends(MANAGE)):
    s = Staff(**data.model_dump())
    db.add(s)
    db.commit()
    db.refresh(s)
    audit(db, user, "add_staff", "staff", s.id, s.name)
    return _out(s)


@router.get("/{sid}")
def get_staff(sid: int, db: Session = Depends(get_db), user: User = Depends(HR)):
    s = db.query(Staff).get(sid)
    if not s:
        raise HTTPException(404, "Staff not found")
    return _out(s)


@router.put("/{sid}")
def update_staff(sid: int, data: StaffIn, db: Session = Depends(get_db),
                 user: User = Depends(MANAGE)):
    s = db.query(Staff).get(sid)
    if not s:
        raise HTTPException(404, "Staff not found")
    for k, v in data.model_dump().items():
        setattr(s, k, v)
    db.commit()
    audit(db, user, "update_staff", "staff", sid, s.name)
    return _out(s)


# ---------- leaves ----------
@router.get("/leaves")
def list_leaves(status: str | None = None, db: Session = Depends(get_db),
                user: User = Depends(HR)):
    q = db.query(StaffLeave).order_by(StaffLeave.from_date.desc())
    if status:
        q = q.filter(StaffLeave.status == status)
    out = []
    for lv in q.all():
        out.append({"id": lv.id, "staff_id": lv.staff_id,
                    "staff_name": lv.staff.name if lv.staff else "",
                    "from_date": lv.from_date, "to_date": lv.to_date,
                    "reason": lv.reason, "status": lv.status})
    return out


@router.post("/leaves")
def apply_leave(data: LeaveIn, db: Session = Depends(get_db),
                user: User = Depends(require_roles("principal", "administrator", "teacher"))):
    lv = StaffLeave(**data.model_dump())
    db.add(lv)
    db.commit()
    db.refresh(lv)
    audit(db, user, "apply_leave", "leave", lv.id, f"staff {data.staff_id}")
    return {"id": lv.id, "status": lv.status}


@router.put("/leaves/{lid}/decision")
def decide_leave(lid: int, data: LeaveDecision, db: Session = Depends(get_db),
                 user: User = Depends(MANAGE)):
    lv = db.query(StaffLeave).get(lid)
    if not lv:
        raise HTTPException(404, "Leave not found")
    if data.decision not in ("approved", "rejected"):
        raise HTTPException(400, "decision must be approved|rejected")
    lv.status = data.decision
    lv.decided_by = user.id
    db.commit()
    audit(db, user, "decide_leave", "leave", lid, data.decision)
    return {"id": lid, "status": lv.status}


# ---------- salaries ----------
@router.get("/salaries")
def list_salaries(month: int | None = None, year: int | None = None,
                  db: Session = Depends(get_db), user: User = Depends(HR)):
    q = db.query(SalaryPayment)
    if month:
        q = q.filter(SalaryPayment.month == month)
    if year:
        q = q.filter(SalaryPayment.year == year)
    out = []
    for p in q.order_by(SalaryPayment.year.desc(), SalaryPayment.month.desc()).all():
        out.append({"id": p.id, "staff_id": p.staff_id,
                    "staff_name": p.staff.name if p.staff else "",
                    "month": p.month, "year": p.year, "basic": p.basic,
                    "allowances": p.allowances, "deductions": p.deductions,
                    "net": p.net, "paid_date": p.paid_date})
    return out


@router.post("/salaries")
def pay_salary(data: SalaryIn, db: Session = Depends(get_db), user: User = Depends(HR)):
    st = db.query(Staff).get(data.staff_id)
    if not st:
        raise HTTPException(404, "Staff not found")
    basic = st.salary_monthly
    net = basic + data.allowances - data.deductions
    p = SalaryPayment(staff_id=st.id, month=data.month, year=data.year, basic=basic,
                      allowances=data.allowances, deductions=data.deductions,
                      net=net, paid_by=user.id)
    db.add(p)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(400, "Salary already recorded for this month")
    db.refresh(p)
    audit(db, user, "pay_salary", "salary", p.id, f"{st.name} {data.month}/{data.year} net {net}")
    return {"id": p.id, "net": net}
