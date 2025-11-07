from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, ForeignKey, Enum as SQLEnum, JSON, Float
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base
import enum


class CampaignStatus(enum.Enum):
    DRAFT = "Draft"
    PREPARING = "Preparing"
    READY = "Ready"
    SENDING = "Sending"
    PAUSED = "Paused"
    COMPLETED = "Completed"
    FAILED = "Failed"


class RecipientStatus(enum.Enum):
    PENDING = "Pending"
    ASSIGNED = "Assigned"
    SENDING = "Sending"
    SENT = "Sent"
    FAILED = "Failed"


class UserStatus(enum.Enum):
    ACTIVE = "Active"
    INACTIVE = "Inactive"
    RATE_LIMITED = "Rate Limited"
    ERROR = "Error"


class Account(Base):
    __tablename__ = "accounts"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    admin_email = Column(String, nullable=False)
    credentials_path = Column(String, nullable=False)  # Path to encrypted credentials file
    active = Column(Boolean, default=True)
    user_count = Column(Integer, default=0)
    daily_quota = Column(Integer, default=2000)  # Daily sending limit per account
    hourly_quota = Column(Integer, default=250)  # Hourly sending limit per account
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    last_sync_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    campaigns = relationship("Campaign", back_populates="account")
    users = relationship("User", back_populates="account", cascade="all, delete-orphan")


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False)
    status = Column(SQLEnum(UserStatus), default=UserStatus.ACTIVE)
    daily_sent_count = Column(Integer, default=0)
    hourly_sent_count = Column(Integer, default=0)
    last_sent_at = Column(DateTime(timezone=True), nullable=True)
    last_error = Column(Text, nullable=True)
    account_id = Column(Integer, ForeignKey("accounts.id"), nullable=False)

    # Relationship
    account = relationship("Account", back_populates="users")
    recipient_assignments = relationship("RecipientAssignment", back_populates="user")


class Campaign(Base):
    __tablename__ = "campaigns"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    from_name = Column(String, nullable=False)
    from_email = Column(String, nullable=False)
    subject = Column(String, nullable=False)
    html_body = Column(Text, nullable=False)
    custom_headers = Column(JSON, nullable=True)  # Custom email headers
    test_email = Column(String, nullable=True)  # Test email address
    selected_accounts = Column(JSON, nullable=True)  # Selected account IDs
    send_rate_per_minute = Column(Integer, default=1000)  # Emails per minute
    status = Column(SQLEnum(CampaignStatus), default=CampaignStatus.DRAFT)
    preparation_started_at = Column(DateTime(timezone=True), nullable=True)
    preparation_completed_at = Column(DateTime(timezone=True), nullable=True)
    sending_started_at = Column(DateTime(timezone=True), nullable=True)
    sending_completed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    recipients = relationship("Recipient", back_populates="campaign", cascade="all, delete-orphan")
    recipient_assignments = relationship("RecipientAssignment", back_populates="campaign", cascade="all, delete-orphan")


class Recipient(Base):
    __tablename__ = "recipients"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False)
    custom_data = Column(JSON, nullable=True)  # For personalization data
    status = Column(SQLEnum(RecipientStatus), default=RecipientStatus.PENDING)
    last_error = Column(Text, nullable=True)
    sent_at = Column(DateTime(timezone=True), nullable=True)
    assigned_at = Column(DateTime(timezone=True), nullable=True)
    
    # Foreign key to campaign
    campaign_id = Column(Integer, ForeignKey("campaigns.id"), nullable=False)
    
    # Relationship
    campaign = relationship("Campaign", back_populates="recipients")


class RecipientAssignment(Base):
    __tablename__ = "recipient_assignments"

    id = Column(Integer, primary_key=True, index=True)
    recipient_id = Column(Integer, ForeignKey("recipients.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    campaign_id = Column(Integer, ForeignKey("campaigns.id"), nullable=False)
    batch_number = Column(Integer, nullable=False)
    priority = Column(Integer, default=0)  # For load balancing
    assigned_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    recipient = relationship("Recipient")
    user = relationship("User", back_populates="recipient_assignments")
    campaign = relationship("Campaign", back_populates="recipient_assignments")


class SendingBatch(Base):
    __tablename__ = "sending_batches"

    id = Column(Integer, primary_key=True, index=True)
    campaign_id = Column(Integer, ForeignKey("campaigns.id"), nullable=False)
    batch_number = Column(Integer, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    recipient_count = Column(Integer, nullable=False)
    status = Column(String, default="pending")  # pending, sending, completed, failed
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    
    # Performance metrics
    send_rate = Column(Float, nullable=True)  # emails per second
    success_rate = Column(Float, nullable=True)  # percentage