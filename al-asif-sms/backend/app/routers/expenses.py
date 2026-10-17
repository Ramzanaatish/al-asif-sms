import calendar
import datetime as dt

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..auth import audit, require_roles
from ..database import get_db
from ..models import Expense, ExpenseCategory, FeeChallan, SalaryPayment, User
from ..schemas import ExpenseCategoryIn, ExpenseIn

router = APIRouter(prefix="/api/expenses", tags=["expenses"])
FINANCE = require_roles("principal", "administrator", "accountant")


@router.get("/categories")
def categories(db: Session = Depends(get_db), user: User = Depends(FINANCE)):
    return [{"id": c.id, "name": c.name} for c in db.query(ExpenseCategory).all()]


@router.post("/categories")
def add_category(data: ExpenseCategoryIn, db: Session = Depends(get_db),
                 user: User = Depends(FINANCE)):
    c = ExpenseCategory(name=data.name)
    db.add(c)
    db.commit()
    db.refresh(c)
    return {"id": c.id, "name": c.name}


@router.get("")
def list_expenses(month: int | None = None, year: int | None = None,
                  category_id: int | None = None, db: Session = Depends(get_db),
                  user: User = Depends(FINANCE)):
    q = db.query(Expense)
    if month and year:
        start = dt.date(year, month, 1)
        end = dt.date(year, month, calendar.monthrange(year, month)[1])
        q = q.filter(Expense.date >= start, Expense.date <= end)
    if category_id:
        q = q.filter(Expense.category_id == category_id)
    out = []
    for e in q.order_by(Expense.date.desc()).all():
        out.append({"id": e.id, "category": e.category.name if e.category else "",
                    "date": e.date, "amount": e.amount,
                    "description": e.description, "paid_to": e.paid_to})
    return out


@router.post("")
def add_expense(data: ExpenseIn, db: Session = Depends(get_db),
                user: User = Depends(FINANCE)):
    e = Expense(**data.model_dump(), entered_by=user.id)
    db.add(e)
    db.commit()
    db.refresh(e)
    audit(db, user, "add_expense", "expense", e.id, f"{data.amount} on {data.date}")
    return {"id": e.id, "amount": e.amount}


@router.get("/profit-loss")
def profit_loss(month: int, year: int, db: Session = Depends(get_db),
                user: User = Depends(FINANCE)):
    start = dt.date(year, month, 1)
    end = dt.date(year, month, calendar.monthrange(year, month)[1])

    challans = db.query(FeeChallan).filter(FeeChallan.month == month,
                                           FeeChallan.year == year).all()
    fee_collected = round(sum(c.amount_paid for c in challans), 2)

    expenses = db.query(Expense).filter(Expense.date >= start,
                                        Expense.date <= end).all()
    expenses_total = round(sum(e.amount for e in expenses), 2)
    by_cat: dict[str, float] = {}
    for e in expenses:
        name = e.category.name if e.category else "Other"
        by_cat[name] = round(by_cat.get(name, 0) + e.amount, 2)

    salaries = db.query(SalaryPayment).filter(SalaryPayment.month == month,
                                              SalaryPayment.year == year).all()
    salaries_total = round(sum(p.net for p in salaries), 2)

    total_outgoing = round(expenses_total + salaries_total, 2)
    return {"month": month, "year": year,
            "fee_collected": fee_collected,
            "expenses_total": expenses_total,
            "expenses_by_category": by_cat,
            "salaries_total": salaries_total,
            "total_outgoing": total_outgoing,
            "net_profit": round(fee_collected - total_outgoing, 2)}
