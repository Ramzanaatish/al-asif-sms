from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .database import Base, engine
from .routers import (academics, attendance, auth, comms, dashboard, exams,
                      expenses, fees, staff, students)

# Import models so metadata is registered
from . import models  # noqa: F401

app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

for r in (auth.router, students.router, staff.router, academics.router,
          attendance.router, exams.router, fees.router, expenses.router,
          comms.router, dashboard.router):
    app.include_router(r)


@app.on_event("startup")
def create_tables():
    Base.metadata.create_all(bind=engine)


@app.get("/api/health")
def health():
    return {"status": "ok", "app": settings.app_name}
