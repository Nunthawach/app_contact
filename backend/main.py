import uuid
import time
from typing import Optional
from datetime import datetime, timezone
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from database import init_db, get_db, User, GlobalContact, ContactSource
from models import (
    LoginRequest, RegisterRequest, TokenResponse, 
    UploadContactsRequest, UploadContactsResponse,
    SyncResponse, SyncContactItem
)
from auth import (
    verify_password, get_password_hash, 
    create_access_token, get_current_user
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # App Startup: Initialize DB and ensure demo user exists
    init_db()
    db = next(get_db())
    demo_email = "employee@company.com"
    existing_user = db.query(User).filter(User.email == demo_email).first()
    new_hash = get_password_hash("password123")
    if not existing_user:
        demo_user = User(
            id=str(uuid.uuid4()),
            email=demo_email,
            password_hash=new_hash,
            full_name="Somchai Jaidee",
            department="IT Support",
            role="admin" # Default demo user is Admin
        )
        db.add(demo_user)
        db.commit()
    else:
        existing_user.password_hash = new_hash
        existing_user.role = "admin"
        db.commit()
    yield

app = FastAPI(
    title="Internal Contact Directory API",
    version="1.0.0",
    description="Enterprise Directory Backend with De-duplication and Offline Sync",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/api/v1/auth/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED, tags=["Auth"])
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    req_email = req.email.strip().lower()
    if not req_email or "@" not in req_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="รูปแบบอีเมลไม่ถูกต้อง"
        )
    if not req.password or len(req.password.strip()) < 4:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="รหัสผ่านต้องมีอย่างน้อย 4 ตัวอักษร"
        )
    if not req.full_name or len(req.full_name.strip()) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="กรุณากรอกชื่อ-นามสกุลให้ครบถ้วน"
        )

    existing_user = db.query(User).filter(User.email == req_email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="อีเมลนี้ถูกลงทะเบียนในระบบแล้ว"
        )

    user_id = str(uuid.uuid4())
    hashed_pwd = get_password_hash(req.password.strip())
    new_user = User(
        id=user_id,
        email=req_email,
        password_hash=hashed_pwd,
        full_name=req.full_name.strip(),
        department=req.department.strip() if req.department else "General",
        role="employee"
    )
    db.add(new_user)
    db.commit()

    token = create_access_token(data={"sub": new_user.id, "email": new_user.email})
    return TokenResponse(
        access_token=token,
        token_type="Bearer",
        expires_in=86400,
        user_info={
            "id": new_user.id,
            "email": new_user.email,
            "full_name": new_user.full_name,
            "department": new_user.department,
            "role": new_user.role
        }
    )

@app.post("/api/v1/auth/login", response_model=TokenResponse, tags=["Auth"])
def login(req: LoginRequest, db: Session = Depends(get_db)):
    req_email = req.email.strip().lower()
    user = db.query(User).filter(User.email == req_email).first()
    if not user or not verify_password(req.password.strip(), user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    token = create_access_token(data={"sub": user.id, "email": user.email})
    return TokenResponse(
        access_token=token,
        token_type="Bearer",
        expires_in=86400,
        user_info={
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name,
            "department": user.department,
            "role": user.role or "employee"
        }
    )

@app.post("/api/v1/contacts/upload", response_model=UploadContactsResponse, tags=["Contacts"])
def upload_contacts(
    req: UploadContactsRequest, 
    current_user: dict = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    user_id = current_user["user_id"]
    inserted_new = 0
    merged_existing = 0

    for item in req.contacts:
        if not item.normalized_phone or not item.raw_name:
            continue

        global_contact = db.query(GlobalContact).filter(
            GlobalContact.normalized_phone == item.normalized_phone
        ).first()

        if not global_contact:
            new_id = str(uuid.uuid4())
            global_contact = GlobalContact(
                id=new_id,
                normalized_phone=item.normalized_phone,
                primary_name=item.raw_name,
                sources_count=1
            )
            db.add(global_contact)
            db.flush()

            source = ContactSource(
                id=str(uuid.uuid4()),
                global_contact_id=new_id,
                uploaded_by_user_id=user_id,
                raw_name=item.raw_name,
                raw_phone=item.raw_phone
            )
            db.add(source)
            inserted_new += 1
        else:
            existing_source = db.query(ContactSource).filter(
                ContactSource.global_contact_id == global_contact.id,
                ContactSource.uploaded_by_user_id == user_id
            ).first()

            if not existing_source:
                source = ContactSource(
                    id=str(uuid.uuid4()),
                    global_contact_id=global_contact.id,
                    uploaded_by_user_id=user_id,
                    raw_name=item.raw_name,
                    raw_phone=item.raw_phone
                )
                db.add(source)
                global_contact.sources_count += 1
            
            if len(item.raw_name) > len(global_contact.primary_name):
                global_contact.primary_name = item.raw_name
            
            global_contact.updated_at = datetime.now(timezone.utc)
            merged_existing += 1

    db.commit()
    return UploadContactsResponse(
        success=True,
        total_received=len(req.contacts),
        inserted_new=inserted_new,
        merged_existing=merged_existing
    )

@app.get("/api/v1/contacts/sync", response_model=SyncResponse, tags=["Contacts"])
def sync_contacts(
    since: Optional[int] = 0,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    total_db_count = db.query(GlobalContact).count()
    query = db.query(GlobalContact)
    if since and since > 0:
        since_dt = datetime.fromtimestamp(since, tz=timezone.utc)
        query = query.filter(GlobalContact.updated_at >= since_dt)
    
    contacts_list = query.all()
    results = []
    for c in contacts_list:
        ts = int(c.updated_at.timestamp()) if c.updated_at else int(time.time())
        results.append(SyncContactItem(
            id=c.id,
            normalized_phone=c.normalized_phone,
            display_name=c.primary_name,
            sources_count=c.sources_count,
            updated_at=ts
        ))

    return SyncResponse(
        success=True,
        sync_timestamp=int(time.time()),
        total_db_count=total_db_count,
        contacts=results
    )

@app.get("/api/v1/contacts/count", tags=["Contacts"])
def get_contacts_count(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    total_db_count = db.query(GlobalContact).count()
    return {"success": True, "total_db_count": total_db_count}

@app.delete("/api/v1/contacts/clear", tags=["Admin"])
def clear_all_contacts(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Clear all global contacts and contact sources for Admin Reset
    db.query(ContactSource).delete()
    deleted_contacts = db.query(GlobalContact).delete()
    db.commit()
    return {
        "success": True,
        "message": f"ล้างข้อมูลรายชื่อส่วนกลางทั้งหมดเรียบร้อยแล้ว ({deleted_contacts} รายชื่อ)"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
