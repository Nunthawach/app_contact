import os
from sqlalchemy import create_engine, Column, String, Integer, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import sessionmaker, declarative_base, relationship

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./enterprise_contacts.db")

# Fix Supabase / Render postgres:// -> postgresql:// URL compatibility for SQLAlchemy 2.0+
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

def build_engine(url: str):
    return create_engine(
        url, 
        connect_args={"check_same_thread": False} if url.startswith("sqlite") else {}
    )

engine = build_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    full_name = Column(String, nullable=False)
    department = Column(String, nullable=True)
    role = Column(String, default="employee")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class GlobalContact(Base):
    __tablename__ = "global_contacts"

    id = Column(String, primary_key=True, index=True)
    normalized_phone = Column(String, unique=True, index=True, nullable=False)
    primary_name = Column(String, index=True, nullable=False)
    sources_count = Column(Integer, default=1)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    sources = relationship("ContactSource", back_populates="global_contact", cascade="all, delete-orphan")

class ContactSource(Base):
    __tablename__ = "contact_sources"

    id = Column(String, primary_key=True, index=True)
    global_contact_id = Column(String, ForeignKey("global_contacts.id"), nullable=False)
    uploaded_by_user_id = Column(String, ForeignKey("users.id"), nullable=False)
    raw_name = Column(String, nullable=False)
    raw_phone = Column(String, nullable=False)
    uploaded_at = Column(DateTime(timezone=True), server_default=func.now())

    global_contact = relationship("GlobalContact", back_populates="sources")

def init_db():
    global engine, SessionLocal
    try:
        Base.metadata.create_all(bind=engine)
    except Exception as e:
        print(f"Warning: Primary database connection failed ({e}). Falling back to SQLite...")
        fallback_url = "sqlite:///./enterprise_contacts.db"
        engine = build_engine(fallback_url)
        SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
        Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
