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
        # users (principal password: alasif123 — change after first login;
        # teacher passwords: teacher123 — change after first login).
        # Principal + one login per class teacher (usernames are name slugs).
        users = [
            ("principal", "Mrs. Hajra Iqbal", "principal", "alasif123"),
            ("teacher", "Teacher", "teacher", "alasif123"),
            ("miss-asia", "Miss Asia", "teacher", "teacher123"),
            ("miss-nadia-ali", "Miss Nadia Ali", "teacher", "teacher123"),
            ("mrs-mehwish-sharif", "Mrs. Mehwish Sharif", "teacher", "teacher123"),
            ("miss-shakila", "Miss Shakila", "teacher", "teacher123"),
            ("miss-uzma", "Miss Uzma", "teacher", "teacher123"),
            ("miss-nadia-jamil", "Miss Nadia Jamil", "teacher", "teacher123"),
            ("miss-akeela", "Miss Akeela", "teacher", "teacher123"),
            ("miss-zunaira", "Miss Zunaira", "teacher", "teacher123"),
            ("mrs-saima-iqbal", "Mrs. Saima Iqbal", "teacher", "teacher123"),
        ]
        for uname, fname, role, pw in users:
            if not db.query(User).filter(User.username == uname).first():
                db.add(User(username=uname, password_hash=hash_password(pw),
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
# Real students from school registers (Oct 2026)
        STUDENTS = {
            "Play Group": [
                (1, "Ahmed Saleem"),
                (2, "Rizwan Abid"),
                (3, "Usman Saddiq"),
                (4, "Huzaifa Maqsood"),
                (5, "Muhammad Azam"),
                (6, "Usman Mujahid"),
                (7, "Usman Razzaq"),
                (8, "Dua Fatima"),
                (9, "Hafsa Bibi"),
                (10, "Dua Shahzad"),
                (11, "Hasnain Bibi (?)"),
                (12, "Asif Waseem"),
                (13, "Muhammad Anas"),
                (14, "Muhammad Ahtisham"),
                (15, "Muhammad Hamad"),
                (16, "Muhammad Subhan"),
                (17, "Hania Shahid"),
                (18, "Malika Mumtaz"),
                (19, "Fatima Bibi"),
                (20, "Mehwish Sadiq"),
                (21, "Fatima (?)"),
                (22, "Muhammad Fahad"),
                (23, "Muhammad Hassan"),
                (24, "Areeba Bibi"),
                (25, "Aziba Bibi (?)"),
                (26, "Muhammad Ali"),
            ],
            "Nursery": [
                (1, "Ibrahim Javaid (?)"),
                (2, "Abdullah Ahmad"),
                (3, "Hamdan Asim"),
                (4, "Hameedullah"),
                (5, "Muhammad Ahsaan"),
                (6, "Usman Asif"),
                (7, "Abdullah Abid"),
                (8, "Subhan Tariq"),
                (9, "Shehryar Sadiq"),
                (10, "Abdullah Hashim"),
                (11, "Muhammad Usman"),
                (12, "Unzila Waqar"),
                (13, "Khadija Bibi"),
                (14, "Nayab Bibi"),
                (15, "Abeeda Bibi"),
                (16, "Tayyiba Bibi"),
                (17, "Afia Saif"),
                (18, "Ayza Bibi"),
                (19, "Habiba Safdar"),
                (20, "Mahnoor Bibi"),
                (21, "Haleema Bilal"),
            ],
            "Prep": [
                (1, "Muhammad Ahmad"),
                (2, "Muhammad Farooq"),
                (3, "Rohan Asim (?)"),
                (4, "Faizan Mushtaq"),
                (5, "Abdullah Masoom (?)"),
                (6, "Muhammad Irfan"),
                (7, "Haji Ghulam Rasool"),
                (8, "Muzaffar Nazeer (?)"),
                (9, "Ahmad Nawaz"),
                (10, "Muhammad Iman (?)"),
                (11, "Muhammad Sajid"),
                (12, "Usman Ijaz"),
                (13, "Naeem Qadir"),
                (14, "Ali Hassan"),
                (15, "Rani Mumtaz"),
                (16, "Ayat Hassan"),
                (17, "Urwah Sajid (?)"),
                (18, "Busra Sajid"),
                (19, "Eman Fatima"),
                (20, "Ayat Hashim"),
                (21, "Alisha Abid"),
                (22, "Ruqayya Bibi"),
                (23, "Zainab Bibi"),
                (24, "Ajwad Safdar (?)"),
                (25, "Raha Hassan Bibi (?)"),
                (26, "Zain Khalid (?)"),
                (27, "Mujeeb Tariq"),
                (28, "Fakhir Majid"),
                (29, "Tayyab Abbas"),
                (30, "Arslan Shafique"),
                (31, "Zainab Ashfaq"),
                (32, "Maryam Asif"),
                (33, "Jannat Bibi"),
                (34, "Sidra Ayaz"),
                (35, "Shanze Jameel"),
                (36, "Lareb Mushtaq"),
                (37, "Dua Mubeen"),
                (38, "Ghulam Fatima"),
                (39, "Zain Anwar"),
            ],
            "1st": [
                (1, "Muhammad Hashir"),
                (2, "Muhammad Ahmad"),
                (3, "Azhar Bilal"),
                (4, "Rayan Amir"),
                (5, "Ahtisham Sadiq"),
                (6, "Ghulam Murtaza"),
                (7, "Bilal Raheem"),
                (8, "Ahmad Awais"),
                (9, "Abdullah Shafiq"),
                (10, "Muhammad Farhan"),
                (11, "Ayesha Bibi"),
                (12, "Humaira Shahid"),
                (13, "Zahra Batool"),
                (14, "Bushra Saleem"),
                (15, "Dua Asif"),
                (16, "Haya Bibi"),
                (17, "Bushra Sajid"),
                (18, "Anaya Hanif"),
                (19, "Zunaira Safdar"),
                (20, "Sabiha Bibi"),
            ],
            "2nd": [
                (1, "Ahad Farooq"),
                (2, "M. Kashif"),
                (3, "Dilshad"),
                (4, "M. Adnan"),
                (5, "Mazhar Bilal"),
                (6, "Rizwan Ahmed"),
                (7, "Ibrahim Azeem"),
                (8, "Ahmed Majid"),
                (9, "Saad Abbas"),
                (10, "Abu Bakar Abbas"),
                (11, "Mehr-ul-Nisa"),
                (12, "Dua Fatima"),
                (13, "Zobia Batool"),
                (14, "Hossna Iftikhar (?)"),
                (15, "Fatima Fiaz"),
                (16, "Alina Sajid"),
                (17, "Ayesha Ashfaq"),
                (18, "Fatima Siddique"),
                (19, "Fatima Javed"),
                (20, "Amina Ashfaq"),
                (21, "Saneen Bibi"),
                (22, "Shahzaib Tameez (?)"),
                (23, "Ayesha Khalid"),
                (24, "Areeba Khalid"),
                (25, "Abrar Khalid"),
            ],
            "3rd": [
                (1, "Hadia Hassan"),
                (2, "M. Nadir"),
                (3, "Alay Sahar (?)"),
                (4, "Abdul Hakim"),
                (5, "Fatih Azab (?)"),
                (6, "Zainab Bibi"),
                (7, "Areeba Imran"),
                (8, "Zobia Batool"),
                (9, "Zulkifal Amir"),
                (10, "Amina Saleem"),
                (11, "Zahra Bibi"),
                (12, "Horia Khan"),
                (13, "Fatima Waseem"),
                (14, "Allah Dita"),
                (15, "Hamza Ali"),
                (16, "Laiba Tariq"),
                (17, "Asad Faraz"),
                (18, "Raheel Afaz (?)"),
                (19, "M. Shehzad"),
                (20, "Numan Shahid"),
                (21, "M. Hassan"),
                (22, "Usman Abbas"),
                (23, "Saba Sadiq"),
                (24, "Junaid Afzal"),
                (25, "Faizan Asif"),
            ],
            "4th": [
                (1, "Muhammad Ismail"),
                (2, "Muhammad Ahmad"),
                (3, "Muhammad Shahzaib"),
                (4, "Sakeena Zafar (?)"),
                (5, "Nijah Fatima (?)"),
                (6, "Esha Bibi"),
                (7, "Rabia Sajid"),
                (8, "Fizza Bibi"),
                (9, "Muhammad Younis"),
                (10, "Abdullah Basit"),
                (11, "Dua Bibi"),
                (12, "Kaseem Bux Khan (?)"),
                (13, "Zahra Peer Bux"),
                (14, "Misbah Bibi"),
                (15, "Iqra Jamil"),
                (16, "Jaweria Fazal"),
                (17, "Sonia Abbas"),
                (18, "Mohsin Abbas"),
                (19, "Shaila Bibi"),
            ],
            "5th": [
                (1, "Rizwan Shahid"),
                (2, "Ikram Abbas"),
                (3, "Zeeshan Shaheen"),
                (4, "Mubashir Qasim"),
                (5, "Ghulam Muhammad"),
                (6, "Adeel Ashar"),
                (7, "Eshaat Sabir"),
                (8, "Noor Fatima"),
                (9, "Hifza Bibi"),
                (10, "Abdullah Eidal (?)"),
                (11, "Alishba Afzal"),
                (12, "M. Wajid"),
                (13, "Fozia Mujahid"),
                (14, "Saima Akmal"),
                (15, "Alia Bibi"),
            ],
            "6th": [
                (1, "Asif Raheem"),
                (2, "Kashif Abid"),
                (3, "Jahangir Javed"),
                (4, "Hamza Attar"),
                (5, "Mudassar"),
                (6, "Arslan Akram"),
                (7, "Tahira Shakeela"),
                (8, "Hadia Qasim"),
                (9, "Alia Sajjad"),
                (10, "Zahra Batool"),
                (11, "Laiba Kanwal"),
                (12, "Areeba Sajjad"),
            ],
            "7th": [
                (11, "Hussain Ahmad"),
                (12, "Altaf Mushtaq (?)"),
                (13, "Sara Shahid"),
                (14, "Namra Gul"),
                (15, "Aiza Tariq"),
                (16, "Sana Mashooq (?)"),
                (17, "Siddiqa Bibi"),
                (18, "Siddiqa Tariq"),
                (19, "Mona Tariq (?)"),
            ],
            "8th": [
                (1, "Hassan Ahmad"),
                (2, "Allah Ditta Mushtaq (?)"),
                (3, "Sara Shahid"),
                (4, "Namra Gull (?)"),
                (5, "Aslam Tariq (?)"),
                (6, "Sana Mashooq (?)"),
                (7, "Siddiqa Bibi"),
                (8, "Siddiqa Tariq"),
                (9, "Mona Tariq (?)"),
                (10, "Ayesha Asif"),
                (11, "Taqwa Ghalib (?)"),
                (12, "Lubna Fayyaz (?)"),
                (13, "Siddiqa Nazuk (?)"),
                (14, "Hajra tul Ain (?)"),
                (15, "Muhammad Arsalan"),
                (16, "Muhammad Hamid"),
            ],
        }
        for cls_name, lst in STUDENTS.items():
            cls = db.query(SchoolClass).filter(SchoolClass.name == cls_name).first()
            if cls:
                for roll, sname in lst:
                    adm = f"AS-2026-{cls.level_order:02d}{roll:03d}"
                    if not db.query(Student).filter(Student.admission_no == adm).first():
                        db.add(Student(admission_no=adm, name=sname,
                                       class_id=cls.id, status="active"))
        db.commit()
        print("Seed complete.")
        print("Logins: principal / alasif123; teachers / teacher123 (miss-asia, miss-nadia-ali, mrs-mehwish-sharif, miss-shakila, miss-uzma, miss-nadia-jamil, miss-akeela, miss-zunaira, mrs-saima-iqbal)")
    finally:
        db.close()


if __name__ == "__main__":
    main()
