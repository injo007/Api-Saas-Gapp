from pydantic import BaseModel, EmailStr
from typing import List, Optional, Dict, Any
from datetime import datetime
from models import CampaignStatus, RecipientStatus, UserStatus


# User schemas
class UserBase(BaseModel):
    email: EmailStr
    name: str


class User(UserBase):
    id: int
    status: UserStatus
    daily_sent_count: int
    hourly_sent_count: int
    last_sent_at: Optional[datetime] = None
    last_error: Optional[str] = None

    class Config:
        from_attributes = True


# Account schemas
class AccountBase(BaseModel):
    name: str
    admin_email: EmailStr


class AccountCreate(AccountBase):
    credentials_json: str  # Base64 encoded JSON or raw JSON string


class AccountWithUsers(AccountBase):
    id: int
    active: bool
    user_count: int
    daily_quota: int
    hourly_quota: int
    created_at: datetime
    last_sync_at: Optional[datetime] = None
    users: List[User] = []

    class Config:
        from_attributes = True


class Account(AccountBase):
    id: int
    active: bool
    user_count: int
    daily_quota: int
    hourly_quota: int
    created_at: datetime
    last_sync_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# Recipient schemas
class RecipientBase(BaseModel):
    email: EmailStr
    name: str


class RecipientCreate(RecipientBase):
    pass


class Recipient(RecipientBase):
    id: int
    status: RecipientStatus
    last_error: Optional[str] = None
    sent_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# Campaign schemas
class CampaignBase(BaseModel):
    name: str
    from_name: str
    from_email: EmailStr
    subject: str


class CampaignCreate(CampaignBase):
    html_body: str
    recipients_csv: str  # CSV format: email,name,custom_data per line
    custom_headers: Optional[Dict[str, str]] = None
    test_email: Optional[EmailStr] = None
    selected_accounts: Optional[List[int]] = None
    send_rate_per_minute: Optional[int] = 1000


class CampaignStats(BaseModel):
    total: int
    sent: int
    pending: int
    assigned: int
    sending: int
    failed: int


class Campaign(CampaignBase):
    id: int
    status: CampaignStatus
    custom_headers: Optional[Dict[str, str]] = None
    test_email: Optional[str] = None
    selected_accounts: Optional[List[int]] = None
    send_rate_per_minute: int
    preparation_started_at: Optional[datetime] = None
    preparation_completed_at: Optional[datetime] = None
    sending_started_at: Optional[datetime] = None
    sending_completed_at: Optional[datetime] = None
    created_at: datetime
    stats: CampaignStats

    class Config:
        from_attributes = True


class CampaignDetail(Campaign):
    html_body: str
    recipients: List[Recipient]

    class Config:
        from_attributes = True


class CampaignPreparation(BaseModel):
    campaign_id: int
    selected_accounts: List[int]
    total_recipients: int
    total_users: int
    assignments_per_user: Dict[str, int]  # user_email -> recipient_count
    estimated_send_time: float  # in seconds


# Response schemas
class HealthCheck(BaseModel):
    status: str
    message: str


class AccountUpdate(BaseModel):
    active: Optional[bool] = None
    daily_quota: Optional[int] = None
    hourly_quota: Optional[int] = None


class CampaignUpdate(BaseModel):
    status: Optional[CampaignStatus] = None


class SendTestEmail(BaseModel):
    campaign_id: int
    test_email: EmailStr


class AccountSync(BaseModel):
    account_id: int


class AccountValidation(BaseModel):
    name: str
    admin_email: EmailStr
    credentials_json: str


class AccountValidationResult(BaseModel):
    valid: bool
    email: Optional[str] = None
    messages_total: Optional[int] = None
    threads_total: Optional[int] = None
    user_count: Optional[int] = None
    error: Optional[str] = None


class SendingProgress(BaseModel):
    campaign_id: int
    total_emails: int
    sent_emails: int
    failed_emails: int
    sending_emails: int
    progress_percentage: float
    estimated_completion_time: Optional[datetime] = None
    current_send_rate: float  # emails per second
    errors: List[str] = []