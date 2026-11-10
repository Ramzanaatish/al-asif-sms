"""All SQLAlchemy models for the Al-Asif School Management System."""
from __future__ import annotations

import datetime as dt

from sqlalchemy import (JSON, Boolean, Column, Date, DateTime, Float, ForeignKey,
                        Integer, String, Text, UniqueConstraint)
from sqlalchemy.orm import relationship

from .database import Base


def _now():
    return dt.datetime.utcnow()


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    username = Column(String(64), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(128), nullable=False)
    role = Column(String(32), nullable=False)  # principal|administrator|teacher|accountant|parent
    linked_student_id = Column(Integer, ForeignKey("students.id"), nullable=True)
    is_active = Column(Boolean, default=True)


class AcademicSession(Base):
    __tablename__ = "sessions"
    id = Column(Integer, primary_key=True)
    name = Column(String(32), unique=True, nullable=False)  # e.g. 2025-26
    is_current = Column(Boolean, default=False)
    start_date = Column(Date, nullable=True)
    end_date = Column(Date, nullable=True)


class SchoolClass(Base):
    __tablename__ = "classes"
    id = Column(Integer, primary_key=True)
    name = Column(String(32), unique=True, nullable=False)  # Play Group..8th
    level_order = Column(Integer, nullable=False)
    student_count = Column(Integer, default=0)  # official enrolment figure
    sections = relationship("Section", back_populates="school_class", cascade="all, delete-orphan")
    subjects = relationship("Subject", back_populates="school_class", cascade="all, delete-orphan")


class Section(Base):
    __tablename__ = "sections"
    id = Column(Integer, primary_key=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    name = Column(String(8), nullable=False, default="A")
    school_class = relationship("SchoolClass", back_populates="sections")
    __table_args__ = (UniqueConstraint("class_id", "name"),)


class Subject(Base):
    __tablename__ = "subjects"
    id = Column(Integer, primary_key=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    name = Column(String(64), nullable=False)
    school_class = relationship("SchoolClass", back_populates="subjects")


class Student(Base):
    __tablename__ = "students"
    id = Column(Integer, primary_key=True)
    admission_no = Column(String(32), unique=True, nullable=False)
    roll_number = Column(Integer, nullable=True)  # class-wise roll no
    name = Column(String(128), nullable=False)
    dob = Column(Date, nullable=True)
    gender = Column(String(16), nullable=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    section_id = Column(Integer, ForeignKey("sections.id"), nullable=True)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=True)
    guardian_name = Column(String(128), nullable=True)
    guardian_phone = Column(String(32), nullable=True)
    guardian_relation = Column(String(32), nullable=True)
    # Extra fields the HTML software + APK sync needs (all optional).
    b_form = Column(String(16), nullable=True)
    name_urdu = Column(String(128), nullable=True)
    father_urdu = Column(String(128), nullable=True)
    mother_name = Column(String(128), nullable=True)
    mother_name_urdu = Column(String(128), nullable=True)
    group_name = Column(String(32), nullable=True)
    address = Column(Text, nullable=True)
    photo_path = Column(String(255), nullable=True)
    documents = Column(JSON, default=list)  # [{name, received}]
    status = Column(String(16), default="active")  # active|left|graduated
    admission_date = Column(Date, default=dt.date.today)
    leaving_date = Column(Date, nullable=True)
    leaving_reason = Column(Text, nullable=True)

    school_class = relationship("SchoolClass")
    section = relationship("Section")


class Staff(Base):
    __tablename__ = "staff"
    id = Column(Integer, primary_key=True)
    name = Column(String(128), nullable=False)
    staff_type = Column(String(16), nullable=False)  # teaching|non_teaching
    designation = Column(String(64), nullable=True)
    phone = Column(String(32), nullable=True)
    cnic = Column(String(32), nullable=True)
    salary_monthly = Column(Float, default=0)
    joining_date = Column(Date, nullable=True)
    status = Column(String(16), default="active")


class StaffLeave(Base):
    __tablename__ = "staff_leaves"
    id = Column(Integer, primary_key=True)
    staff_id = Column(Integer, ForeignKey("staff.id"), nullable=False)
    from_date = Column(Date, nullable=False)
    to_date = Column(Date, nullable=False)
    reason = Column(Text, nullable=True)
    status = Column(String(16), default="pending")  # pending|approved|rejected
    decided_by = Column(Integer, ForeignKey("users.id"), nullable=True)

    staff = relationship("Staff")


class SalaryPayment(Base):
    __tablename__ = "salary_payments"
    id = Column(Integer, primary_key=True)
    staff_id = Column(Integer, ForeignKey("staff.id"), nullable=False)
    month = Column(Integer, nullable=False)
    year = Column(Integer, nullable=False)
    basic = Column(Float, default=0)
    allowances = Column(Float, default=0)
    deductions = Column(Float, default=0)
    net = Column(Float, default=0)
    paid_date = Column(Date, nullable=True)
    paid_by = Column(Integer, ForeignKey("users.id"), nullable=True)

    staff = relationship("Staff")
    __table_args__ = (UniqueConstraint("staff_id", "month", "year"),)


class SyllabusItem(Base):
    __tablename__ = "syllabus"
    id = Column(Integer, primary_key=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    topic = Column(String(255), nullable=False)
    status = Column(String(16), default="planned")  # planned|in_progress|completed


class TimetableEntry(Base):
    __tablename__ = "timetable"
    id = Column(Integer, primary_key=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    section_id = Column(Integer, ForeignKey("sections.id"), nullable=True)
    day_of_week = Column(Integer, nullable=False)  # 0=Monday
    period_no = Column(Integer, nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=True)
    teacher_id = Column(Integer, ForeignKey("staff.id"), nullable=True)
    room = Column(String(32), nullable=True)


class StudentAttendance(Base):
    __tablename__ = "student_attendance"
    id = Column(Integer, primary_key=True)
    date = Column(Date, nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    status = Column(String(16), nullable=False)  # present|absent|leave
    leave_type = Column(String(32), nullable=True)  # sick|casual|urgent (when leave)
    marked_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    __table_args__ = (UniqueConstraint("date", "student_id"),)


class StaffAttendance(Base):
    __tablename__ = "staff_attendance"
    id = Column(Integer, primary_key=True)
    date = Column(Date, nullable=False)
    staff_id = Column(Integer, ForeignKey("staff.id"), nullable=False)
    status = Column(String(16), nullable=False)  # present|absent|leave
    marked_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    __table_args__ = (UniqueConstraint("date", "staff_id"),)


class AlertQueue(Base):
    __tablename__ = "alert_queue"
    id = Column(Integer, primary_key=True)
    channel = Column(String(16), nullable=False)  # sms|whatsapp
    recipient_phone = Column(String(32), nullable=False)
    message = Column(Text, nullable=False)
    status = Column(String(16), default="queued")  # queued|sent|failed
    created_at = Column(DateTime, default=_now)


class ExamTerm(Base):
    __tablename__ = "exam_terms"
    id = Column(Integer, primary_key=True)
    name = Column(String(64), nullable=False)
    term_type = Column(String(16), nullable=False)  # monthly|annual
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=True)
    start_date = Column(Date, nullable=True)
    end_date = Column(Date, nullable=True)


class DateSheetEntry(Base):
    __tablename__ = "datesheet"
    id = Column(Integer, primary_key=True)
    term_id = Column(Integer, ForeignKey("exam_terms.id"), nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    exam_date = Column(Date, nullable=False)
    start_time = Column(String(16), nullable=True)


class Mark(Base):
    __tablename__ = "marks"
    id = Column(Integer, primary_key=True)
    term_id = Column(Integer, ForeignKey("exam_terms.id"), nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    total_marks = Column(Float, nullable=False)
    obtained_marks = Column(Float, nullable=False)
    __table_args__ = (UniqueConstraint("term_id", "subject_id", "student_id"),)


class FeeHead(Base):
    __tablename__ = "fee_heads"
    id = Column(Integer, primary_key=True)
    name = Column(String(64), nullable=False)
    amount = Column(Float, nullable=False)
    frequency = Column(String(16), default="monthly")  # monthly|annual|onetime
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=True)


class FeeChallan(Base):
    __tablename__ = "fee_challans"
    id = Column(Integer, primary_key=True)
    challan_no = Column(String(32), unique=True, nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    month = Column(Integer, nullable=False)
    year = Column(Integer, nullable=False)
    due_date = Column(Date, nullable=True)
    total_amount = Column(Float, default=0)
    discount = Column(Float, default=0)
    amount_paid = Column(Float, default=0)
    status = Column(String(16), default="unpaid")  # unpaid|partial|paid
    issued_by = Column(Integer, ForeignKey("users.id"), nullable=True)

    student = relationship("Student")


class FeeReceipt(Base):
    __tablename__ = "fee_receipts"
    id = Column(Integer, primary_key=True)
    receipt_no = Column(String(32), unique=True, nullable=False)
    challan_id = Column(Integer, ForeignKey("fee_challans.id"), nullable=False)
    amount = Column(Float, nullable=False)
    payment_method = Column(String(16), default="cash")
    received_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    received_at = Column(DateTime, default=_now)


class ExpenseCategory(Base):
    __tablename__ = "expense_categories"
    id = Column(Integer, primary_key=True)
    name = Column(String(64), unique=True, nullable=False)


class Expense(Base):
    __tablename__ = "expenses"
    id = Column(Integer, primary_key=True)
    category_id = Column(Integer, ForeignKey("expense_categories.id"), nullable=False)
    date = Column(Date, nullable=False)
    amount = Column(Float, nullable=False)
    description = Column(Text, nullable=True)
    paid_to = Column(String(128), nullable=True)
    entered_by = Column(Integer, ForeignKey("users.id"), nullable=True)

    category = relationship("ExpenseCategory")


class Notice(Base):
    __tablename__ = "notices"
    id = Column(Integer, primary_key=True)
    title = Column(String(255), nullable=False)
    body = Column(Text, nullable=False)
    audience = Column(String(16), default="all")  # all|parents|staff
    published_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=_now)


class Complaint(Base):
    __tablename__ = "complaints"
    id = Column(Integer, primary_key=True)
    parent_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=True)
    subject = Column(String(255), nullable=False)
    body = Column(Text, nullable=False)
    status = Column(String(16), default="open")  # open|resolved
    created_at = Column(DateTime, default=_now)


class AuditLog(Base):
    __tablename__ = "audit_log"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    username = Column(String(64), nullable=True)
    action = Column(String(64), nullable=False)
    entity = Column(String(64), nullable=True)
    entity_id = Column(Integer, nullable=True)
    details = Column(Text, nullable=True)
    created_at = Column(DateTime, default=_now)


class Holiday(Base):
    __tablename__ = "holidays"
    id = Column(Integer, primary_key=True)
    date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=True)  # for vacation ranges; None = single day
    kind = Column(String(32), nullable=False, default="unexpected")  # unexpected|summer|winter|other
    description = Column(String(255), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=True)
