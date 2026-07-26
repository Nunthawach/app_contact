# Enterprise Internal Contact Directory App

ระบบแอปพลิเคชันค้นหารายชื่อส่วนกลางภายในองค์กร (Internal Contact Directory App) ครบวงจร ทั้งส่วน Backend Service และ Flutter Mobile Application

---

## 📁 โครงสร้างโปรเจกต์ (Project Structure)

```
d:\App Contact\
├── backend/                  # Python FastAPI Backend Service
│   ├── main.py               # API Endpoints (Auth, Upload, Sync)
│   ├── database.py           # SQLAlchemy Engine & Database ORM Schemas
│   ├── auth.py               # JWT Authentication & Password Hashing
│   ├── models.py             # Pydantic Schemas
│   ├── requirements.txt      # Python Dependencies
│   └── .env.example          # Environment Variables
│
├── mobile_app/               # Flutter Mobile Application
│   ├── pubspec.yaml          # Flutter Package Configuration
│   └── lib/
│       ├── main.dart         # Flutter Entry Point
│       ├── models/           # Contact Data Models
│       ├── services/         # Native Contacts, SQLite Local DB & API Services
│       └── screens/          # Login, Scan & Upload, Global Search Screens
│
└── presentation.html         # Executive Slide Presentation
```

---

## 🚀 วิธีการทดสอบและสั่งรันระบบ (How to Run)

### 1. วิธีสั่งรัน Backend Service (Python FastAPI)

1. เปิด Terminal เข้าไปที่โฟลเดอร์ `backend`:
   ```bash
   cd backend
   ```
2. ติดตั้ง Dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. รัน Server:
   ```bash
   python main.py
   # หรือ uvicorn main:app --reload --port 8000
   ```
4. สามารถทดสอบ API Documentation ผ่าน Interactive Swagger UI ได้ที่:
   👉 `http://localhost:8000/docs`

> 🔑 **Demo User Credentials**:
> - Email: `employee@company.com`
> - Password: `password123`

---

### 2. วิธีสั่งรัน Mobile App (Flutter)

1. เปิด Terminal เข้าไปที่โฟลเดอร์ `mobile_app`:
   ```bash
   cd mobile_app
   ```
2. ติดตั้ง Flutter Packages:
   ```bash
   flutter pub get
   ```
3. สั่งรันแอปพลิเคชันลงใน Android Emulator / iOS Simulator หรือเครื่องจริง:
   ```bash
   flutter run
   ```

---

## 💡 ฟีเจอร์สำคัญที่เปิดใช้งานแล้ว (Key Implemented Features)

- [x] **JWT Authentication**: เข้าสู่ระบบด้วย Email/Password
- [x] **Native Contact Permission & Scan**: ดึงรายชื่อจากสมาร์ทโฟน พร้อม Normalization เบอร์โทร (+66 -> 0)
- [x] **Batch Upload & De-duplication**: รวมข้อมูลซ้ำบน Cloud ด้วยกฎ Majority Voting
- [x] **Sub-10ms SQLite Offline Search**: ค้นหารายชื่อกลางแบบ Partial Match ระดับมิลลิวินาที แม้ไม่มีอินเทอร์เน็ต
- [x] **Click-to-Call**: กดโทรออกหาบุคลากรในองค์กรได้ทันทีผ่าน System Phone Dialer
