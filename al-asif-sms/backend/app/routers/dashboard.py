import datetime as dt

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..auth import get_current_user, require_roles
from ..database import get_db
from ..models import (AuditLog, FeeChallan, Staff, StaffAttendance, Student,
                      StudentAttendance, User)

router = APIRouter(tags=["dashboard", "audit"])


@router.get("/api/dashboard/principal")
def principal_dashboard(db: Session = Depends(get_db),
                        user: User = Depends(require_roles("principal", "administrator"))):
    today = dt.date.today()
    total_students = db.query(Student).filter(Student.status == "active").count()
    total_staff = db.query(Staff).filter(Staff.status == "active").count()
    challans = db.query(FeeChallan).filter(FeeChallan.month == today.month,
                                           FeeChallan.year == today.year).all()
    fee_collected = round(sum(c.amount_paid for c in challans), 2)
    defaulters = sum(1 for c in challans if c.status != "paid")

    s_att = db.query(StudentAttendance).filter(StudentAttendance.date == today).all()
    att_pct = round(100 * sum(1 for a in s_att if a.status == "present") / len(s_att), 1) if s_att else 0
    st_att = db.query(StaffAttendance).filter(StaffAttendance.date == today).all()
    staff_present = sum(1 for a in st_att if a.status == "present")

    from ..models import Expense, SalaryPayment
    start = dt.date(today.year, today.month, 1)
    exp_total = sum(e.amount for e in db.query(Expense).filter(Expense.date >= start).all())
    sal_total = sum(p.net for p in db.query(SalaryPayment).filter(
        SalaryPayment.month == today.month, SalaryPayment.year == today.year).all())
    profit = round(fee_collected - exp_total - sal_total, 2)

    return {"total_students": total_students, "total_staff": total_staff,
            "fee_collected_month": fee_collected, "defaulters_count": defaulters,
            "attendance_pct_today": att_pct, "staff_present_today": staff_present,
            "profit_month": profit, "month": today.month, "year": today.year}


@router.get("/api/audit")
def audit_log(limit: int = 100, db: Session = Depends(get_db),
              user: User = Depends(require_roles("principal", "administrator"))):
    rows = db.query(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit).all()
    return [{"id": r.id, "username": r.username, "action": r.action,
             "entity": r.entity, "entity_id": r.entity_id,
             "details": r.details, "created_at": r.created_at} for r in rows]
