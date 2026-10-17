"""Seed the database: classes, users, fee heads, expense categories, demo data.

Usage:
    cd backend
    python seed.py            # uses DATABASE_URL from .env or the default
"""
import datetime as dt
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.auth import hash_password
from app.database import Base, SessionLocal, engine
from app.models import (AcademicSession, ExpenseCategory, FeeHead, SchoolClass,
                        Section, Staff, Student, Subject, User)

CLASSES = [
    ("Play Group", 25), ("Nursery", 19), ("Prep", 36),
    ("1st", 20), ("2nd", 24), ("3rd", 25), ("4th", 17),
    ("5th", 14), ("6th", 14), ("7th", 10), ("8th", 8),
]

SUBJECTS_JUNIOR = ["English", "Urdu", "Math", "Nazra Quran", "Art"]
SUBJECTS_SENIOR = ["English", "Urdu", "Mathematics", "Science", "Islamiat",
                   "Nazra Quran", "Social Studies", "Computer"]


def main():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # session
        if not db.query(AcademicSession).first():
            db.add(AcademicSession(name="2025-26", is_current=True,
                                   start_date=dt.date(2025, 4, 1),
                                   end_date=dt.date(2026, 3, 31)))
        # classes + sections + subjects
        for i, (name, count) in enumerate(CLASSES, 1):
            c = db.query(SchoolClass).filter(SchoolClass.name == name).first()
            if not c:
                c = SchoolClass(name=name, level_order=i, student_count=count)
                db.add(c)
                db.flush()
                db.add(Section(class_id=c.id, name="A"))
                subjects = SUBJECTS_JUNIOR if i <= 3 else SUBJECTS_SENIOR
                for sname in subjects:
                    db.add(Subject(class_id=c.id, name=sname))
            else:
                c.student_count = count
        # users (default password: alasif123 — change after first login)
        users = [
            ("principal", "Mrs. Hajra Iqbal", "principal"),
            ("admin", "Administrator", "administrator"),
            ("teacher1", "Demo Teacher", "teacher"),
            ("accounts", "Accountant", "accountant"),
            ("parent1", "Demo Parent", "parent"),
        ]
        for uname, fname, role in users:
            if not db.query(User).filter(User.username == uname).first():
                db.add(User(username=uname, password_hash=hash_password("alasif123"),
                            full_name=fname, role=role))
        # fee heads
        heads = [("Tuition Fee", 800, "monthly"), ("Admission Fee", 2000, "onetime"),
                 ("Annual Exam Fee", 500, "annual"), ("Books Fund", 300, "annual")]
        for name, amount, freq in heads:
            if not db.query(FeeHead).filter(FeeHead.name == name).first():
                db.add(FeeHead(name=name, amount=amount, frequency=freq))
        # expense categories
        for name in ["Salaries", "Utilities", "Stationery", "Maintenance",
                     "Rent", "Transport Fuel", "Miscellaneous"]:
            if not db.query(ExpenseCategory).filter(ExpenseCategory.name == name).first():
                db.add(ExpenseCategory(name=name))
        # demo staff
        if not db.query(Staff).first():
            db.add(Staff(name="Demo Teacher", staff_type="teaching",
                         designation="Class Teacher", phone="0300-0000001",
                         salary_monthly=25000, joining_date=dt.date(2023, 4, 1)))
            db.add(Staff(name="Demo Clerk", staff_type="non_teaching",
                         designation="Office Clerk", phone="0300-0000002",
                         salary_monthly=18000, joining_date=dt.date(2023, 4, 1)))
        # demo students (a few in 8th for testing flows)
        cls8 = db.query(SchoolClass).filter(SchoolClass.name == "8th").first()
        if cls8 and db.query(Student).count() == 0:
            for n in range(1, 4):
                db.add(Student(admission_no=f"AS-2025-00{n}", name=f"Demo Student {n}",
                               gender="Male" if n % 2 else "Female",
                               class_id=cls8.id, guardian_name="Demo Guardian",
                               guardian_phone="0300-0000000", status="active"))
        db.commit()
        print("Seed complete.")
        print("Logins (password alasif123): principal / admin / teacher1 / accounts / parent1")
    finally:
        db.close()


if __name__ == "__main__":
    main()
