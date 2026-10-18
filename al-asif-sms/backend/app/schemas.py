"""Pydantic request/response schemas."""
from __future__ import annotations

import datetime as dt

from pydantic import BaseModel, Field


# ---------- auth ----------
class LoginIn(BaseModel):
    username: str
    password: str


class UserOut(BaseModel):
    id: int
    username: str
    full_name: str
    role: str
    linked_student_id: int | None = None

    class Config:
        from_attributes = True


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ---------- students ----------
class DocumentItem(BaseModel):
    name: str
    received: bool = False


class StudentIn(BaseModel):
    admission_no: str | None = None  # auto-generated when omitted
    roll_number: int | None = None
    name: str
    dob: dt.date | None = None
    gender: str | None = None
    class_id: int
    section_id: int | None = None
    guardian_name: str | None = None
    guardian_phone: str | None = None
    guardian_relation: str | None = None
    address: str | None = None
    photo_path: str | None = None
    documents: list[DocumentItem] = []


class StudentOut(BaseModel):
    id: int
    admission_no: str
    name: str
    gender: str | None = None
    class_id: int
    class_name: str = ""
    section_id: int | None = None
    section_name: str = ""
    guardian_name: str | None = None
    guardian_phone: str | None = None
    status: str

    class Config:
        from_attributes = True


class MarkLeftIn(BaseModel):
    leaving_date: dt.date
    reason: str


class PromoteIn(BaseModel):
    from_class_id: int
    to_class_id: int
    promoted_ids: list[int]
    retained_ids: list[int] = []
    session_id: int | None = None


# ---------- staff ----------
class StaffIn(BaseModel):
    name: str
    staff_type: str  # teaching|non_teaching
    designation: str | None = None
    phone: str | None = None
    cnic: str | None = None
    salary_monthly: float = 0
    joining_date: dt.date | None = None


class LeaveIn(BaseModel):
    staff_id: int
    from_date: dt.date
    to_date: dt.date
    reason: str | None = None


class LeaveDecision(BaseModel):
    decision: str  # approved|rejected


class SalaryIn(BaseModel):
    staff_id: int
    month: int = Field(ge=1, le=12)
    year: int
    allowances: float = 0
    deductions: float = 0


# ---------- academics ----------
class SectionIn(BaseModel):
    class_id: int
    name: str = "A"


class SubjectIn(BaseModel):
    class_id: int
    name: str


class SyllabusIn(BaseModel):
    class_id: int
    subject_id: int
    topic: str


class SyllabusStatus(BaseModel):
    status: str  # planned|in_progress|completed


class TimetableIn(BaseModel):
    class_id: int
    section_id: int | None = None
    day_of_week: int = Field(ge=0, le=6)
    period_no: int = Field(ge=1)
    subject_id: int | None = None
    teacher_id: int | None = None
    room: str | None = None


# ---------- attendance ----------
class AttRecord(BaseModel):
    student_id: int | None = None
    staff_id: int | None = None
    status: str  # present|absent|leave
    leave_type: str | None = None  # sick|casual|urgent (when status=leave)


class StudentAttIn(BaseModel):
    date: dt.date
    class_id: int
    section_id: int | None = None
    records: list[AttRecord]


class StaffAttIn(BaseModel):
    date: dt.date
    records: list[AttRecord]


class AbsentAlertIn(BaseModel):
    date: dt.date
    channel: str = "sms"  # sms|whatsapp


class HolidayIn(BaseModel):
    date: dt.date
    end_date: dt.date | None = None  # for vacation ranges
    kind: str = "unexpected"  # unexpected|summer|winter|other
    description: str | None = None


# ---------- exams ----------
class TermIn(BaseModel):
    name: str
    term_type: str  # monthly|annual
    session_id: int | None = None
    start_date: dt.date | None = None
    end_date: dt.date | None = None


class DateSheetIn(BaseModel):
    term_id: int
    class_id: int
    subject_id: int
    exam_date: dt.date
    start_time: str | None = None


class MarkRecord(BaseModel):
    student_id: int
    obtained_marks: float


class MarksIn(BaseModel):
    term_id: int
    class_id: int
    subject_id: int
    total_marks: float
    records: list[MarkRecord]


# ---------- fees ----------
class FeeHeadIn(BaseModel):
    name: str
    amount: float
    frequency: str = "monthly"
    class_id: int | None = None


class ChallanGenIn(BaseModel):
    class_id: int
    month: int = Field(ge=1, le=12)
    year: int
    head_ids: list[int]


class CollectIn(BaseModel):
    amount: float = Field(gt=0)
    discount: float = Field(default=0, ge=0)
    payment_method: str = "cash"


# ---------- expenses ----------
class ExpenseCategoryIn(BaseModel):
    name: str


class ExpenseIn(BaseModel):
    category_id: int
    date: dt.date
    amount: float = Field(gt=0)
    description: str | None = None
    paid_to: str | None = None


# ---------- comms ----------
class NoticeIn(BaseModel):
    title: str
    body: str
    audience: str = "all"


class ComplaintIn(BaseModel):
    student_id: int | None = None
    subject: str
    body: str


class ComplaintStatus(BaseModel):
    status: str  # open|resolved
