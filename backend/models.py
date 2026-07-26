from pydantic import BaseModel, EmailStr
from typing import List, Optional

# --- Auth Models ---
class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    email: str
    password: str
    full_name: str
    department: Optional[str] = "General"

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "Bearer"
    expires_in: int
    user_info: dict

# --- Contact Upload Models ---
class RawContactItem(BaseModel):
    raw_name: str
    raw_phone: str
    normalized_phone: str

class UploadContactsRequest(BaseModel):
    device_id: str
    contacts: List[RawContactItem]

class UploadContactsResponse(BaseModel):
    success: bool
    total_received: int
    inserted_new: int
    merged_existing: int

# --- Sync / Search Models ---
class SyncContactItem(BaseModel):
    id: str
    normalized_phone: str
    display_name: str
    sources_count: int
    updated_at: int

class SyncResponse(BaseModel):
    success: bool
    sync_timestamp: int
    contacts: List[SyncContactItem]
