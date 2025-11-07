from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
import os
import json
import uuid
import asyncio

from models import (Account, Campaign, Recipient, CampaignStatus, RecipientStatus, 
                   User, UserStatus, RecipientAssignment, SendingBatch)
import schemas
from utils.encryption import encrypt_data, decrypt_data
from utils.gmail_service import get_workspace_users, validate_gmail_credentials
from core.config import settings


# Account CRUD operations
def create_account(db: Session, account: schemas.AccountCreate) -> Account:
    """Create a new account with encrypted credentials"""
    # Create uploads directory if it doesn't exist
    os.makedirs(settings.upload_dir, exist_ok=True)
    
    # Generate unique filename for credentials
    credentials_filename = f"account_{uuid.uuid4().hex}.json"
    credentials_path = os.path.join(settings.upload_dir, credentials_filename)
    
    # Encrypt and save credentials
    encrypted_credentials = encrypt_data(account.credentials_json)
    with open(credentials_path, 'w') as f:
        f.write(encrypted_credentials)
    
    db_account = Account(
        name=account.name,
        admin_email=account.admin_email,
        credentials_path=credentials_path,
        active=True
    )
    db.add(db_account)
    db.commit()
    db.refresh(db_account)
    return db_account


def get_account(db: Session, account_id: int) -> Optional[Account]:
    """Get account by ID"""
    return db.query(Account).filter(Account.id == account_id).first()


def get_accounts(db: Session, skip: int = 0, limit: int = 100) -> List[Account]:
    """Get all accounts"""
    return db.query(Account).offset(skip).limit(limit).all()


def update_account(db: Session, account_id: int, account_update: schemas.AccountUpdate) -> Optional[Account]:
    """Update account"""
    db_account = get_account(db, account_id)
    if db_account:
        if account_update.active is not None:
            db_account.active = account_update.active
        db.commit()
        db.refresh(db_account)
    return db_account


def delete_account(db: Session, account_id: int) -> bool:
    """Delete account and its credentials file"""
    db_account = get_account(db, account_id)
    if db_account:
        # Delete credentials file
        if os.path.exists(db_account.credentials_path):
            os.remove(db_account.credentials_path)
        
        db.delete(db_account)
        db.commit()
        return True
    return False


def get_account_credentials(account: Account) -> dict:
    """Decrypt and return account credentials"""
    with open(account.credentials_path, 'r') as f:
        encrypted_data = f.read()
    
    decrypted_json = decrypt_data(encrypted_data)
    return json.loads(decrypted_json)


# Campaign CRUD operations
def create_campaign(db: Session, campaign: schemas.CampaignCreate) -> Campaign:
    """Create a new campaign with recipients"""
    db_campaign = Campaign(
        name=campaign.name,
        from_name=campaign.from_name,
        from_email=campaign.from_email,
        subject=campaign.subject,
        html_body=campaign.html_body,
        status=CampaignStatus.DRAFT
    )
    db.add(db_campaign)
    db.flush()  # Get the ID without committing
    
    # Parse and create recipients
    recipients = []
    for line in campaign.recipients_csv.strip().split('\n'):
        if line.strip():
            parts = line.strip().split(',', 1)
            if len(parts) == 2:
                email, name = parts
                recipient = Recipient(
                    email=email.strip(),
                    name=name.strip(),
                    campaign_id=db_campaign.id,
                    status=RecipientStatus.PENDING
                )
                recipients.append(recipient)
    
    db.add_all(recipients)
    db.commit()
    db.refresh(db_campaign)
    return db_campaign


def get_campaign(db: Session, campaign_id: int) -> Optional[Campaign]:
    """Get campaign by ID"""
    return db.query(Campaign).filter(Campaign.id == campaign_id).first()


def get_campaigns(db: Session, skip: int = 0, limit: int = 100) -> List[Campaign]:
    """Get all campaigns"""
    return db.query(Campaign).offset(skip).limit(limit).all()


def update_campaign_status(db: Session, campaign_id: int, status: CampaignStatus) -> Optional[Campaign]:
    """Update campaign status"""
    db_campaign = get_campaign(db, campaign_id)
    if db_campaign:
        db_campaign.status = status
        db.commit()
        db.refresh(db_campaign)
    return db_campaign


def get_campaign_stats(db: Session, campaign_id: int) -> schemas.CampaignStats:
    """Get campaign statistics"""
    stats = db.query(
        func.count(Recipient.id).label('total'),
        func.sum(func.case((Recipient.status == RecipientStatus.SENT, 1), else_=0)).label('sent'),
        func.sum(func.case((Recipient.status == RecipientStatus.PENDING, 1), else_=0)).label('pending'),
        func.sum(func.case((Recipient.status == RecipientStatus.FAILED, 1), else_=0)).label('failed')
    ).filter(Recipient.campaign_id == campaign_id).first()
    
    return schemas.CampaignStats(
        total=stats.total or 0,
        sent=stats.sent or 0,
        pending=stats.pending or 0,
        failed=stats.failed or 0
    )


def get_campaign_recipients(db: Session, campaign_id: int) -> List[Recipient]:
    """Get all recipients for a campaign"""
    return db.query(Recipient).filter(Recipient.campaign_id == campaign_id).all()


def update_recipient_status(db: Session, recipient_id: int, status: RecipientStatus, error: str = None):
    """Update recipient status"""
    recipient = db.query(Recipient).filter(Recipient.id == recipient_id).first()
    if recipient:
        recipient.status = status
        if error:
            recipient.last_error = error
        if status == RecipientStatus.SENT:
            recipient.sent_at = func.now()
        db.commit()


def get_pending_recipients(db: Session, campaign_id: int, limit: int = 100) -> List[Recipient]:
    """Get pending recipients for a campaign"""
    return db.query(Recipient).filter(
        Recipient.campaign_id == campaign_id,
        Recipient.status == RecipientStatus.PENDING
    ).limit(limit).all()


def get_active_accounts(db: Session) -> List[Account]:
    """Get all active accounts"""
    return db.query(Account).filter(Account.active == True).all()


# User CRUD operations
def create_users_for_account(db: Session, account_id: int, users_data: List[dict]) -> List[User]:
    """Create users for an account"""
    users = []
    for user_data in users_data:
        user = User(
            email=user_data['email'],
            name=user_data['name'],
            account_id=account_id,
            status=UserStatus.ACTIVE
        )
        users.append(user)
    
    db.add_all(users)
    db.commit()
    
    # Update account user count
    account = get_account(db, account_id)
    if account:
        account.user_count = len(users_data)
        account.last_sync_at = func.now()
        db.commit()
    
    return users


def get_account_users(db: Session, account_id: int) -> List[User]:
    """Get all users for an account"""
    return db.query(User).filter(User.account_id == account_id).all()


def update_user_status(db: Session, user_id: int, status: UserStatus, error: str = None):
    """Update user status"""
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.status = status
        if error:
            user.last_error = error
        db.commit()


def increment_user_sent_count(db: Session, user_id: int):
    """Increment user's sent count"""
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.daily_sent_count += 1
        user.hourly_sent_count += 1
        user.last_sent_at = func.now()
        db.commit()


def reset_hourly_counts(db: Session):
    """Reset hourly sent counts for all users"""
    db.query(User).update({User.hourly_sent_count: 0})
    db.commit()


def reset_daily_counts(db: Session):
    """Reset daily sent counts for all users"""
    db.query(User).update({User.daily_sent_count: 0})
    db.commit()


def sync_account_users(db: Session, account_id: int) -> dict:
    """Sync users from Google Workspace"""
    account = get_account(db, account_id)
    if not account:
        return {'success': False, 'error': 'Account not found'}
    
    try:
        # Get credentials
        credentials_dict = get_account_credentials(account)
        
        # Fetch users from Google Workspace
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            users_data = loop.run_until_complete(
                get_workspace_users(credentials_dict, account.admin_email)
            )
        finally:
            loop.close()
        
        if not users_data:
            return {'success': False, 'error': 'No users found or API error'}
        
        # Delete existing users
        db.query(User).filter(User.account_id == account_id).delete()
        
        # Create new users
        users = create_users_for_account(db, account_id, users_data)
        
        return {
            'success': True,
            'user_count': len(users),
            'users': [{'email': u.email, 'name': u.name} for u in users]
        }
    
    except Exception as e:
        return {'success': False, 'error': str(e)}


def validate_account_credentials(credentials_json: str, admin_email: str) -> dict:
    """Validate account credentials and return info"""
    try:
        credentials_dict = json.loads(credentials_json)
        return validate_gmail_credentials(credentials_dict, admin_email)
    except Exception as e:
        return {'valid': False, 'error': str(e)}


# Advanced Campaign CRUD operations
def create_advanced_campaign(db: Session, campaign: schemas.CampaignCreate) -> Campaign:
    """Create a campaign with advanced features"""
    db_campaign = Campaign(
        name=campaign.name,
        from_name=campaign.from_name,
        from_email=campaign.from_email,
        subject=campaign.subject,
        html_body=campaign.html_body,
        custom_headers=campaign.custom_headers,
        test_email=campaign.test_email,
        selected_accounts=campaign.selected_accounts,
        send_rate_per_minute=campaign.send_rate_per_minute or 1000,
        status=CampaignStatus.DRAFT
    )
    db.add(db_campaign)
    db.flush()
    
    # Parse and create recipients with custom data
    recipients = []
    for line in campaign.recipients_csv.strip().split('\n'):
        if line.strip():
            parts = line.strip().split(',')
            if len(parts) >= 2:
                email = parts[0].strip()
                name = parts[1].strip()
                custom_data = json.loads(parts[2]) if len(parts) > 2 and parts[2].strip() else None
                
                recipient = Recipient(
                    email=email,
                    name=name,
                    custom_data=custom_data,
                    campaign_id=db_campaign.id,
                    status=RecipientStatus.PENDING
                )
                recipients.append(recipient)
    
    db.add_all(recipients)
    db.commit()
    db.refresh(db_campaign)
    return db_campaign


def prepare_campaign_for_sending(db: Session, campaign_id: int, selected_accounts: List[int]) -> dict:
    """Prepare campaign for ultra-fast sending"""
    from utils.campaign_optimizer import CampaignOptimizer
    
    campaign = get_campaign(db, campaign_id)
    if not campaign:
        return {'success': False, 'error': 'Campaign not found'}
    
    if campaign.status != CampaignStatus.DRAFT:
        return {'success': False, 'error': 'Campaign must be in Draft status'}
    
    try:
        # Update campaign status to preparing
        campaign.status = CampaignStatus.PREPARING
        campaign.preparation_started_at = func.now()
        campaign.selected_accounts = selected_accounts
        db.commit()
        
        # Get recipients
        recipients = get_campaign_recipients(db, campaign_id)
        if not recipients:
            return {'success': False, 'error': 'No recipients found'}
        
        # Initialize optimizer
        optimizer = CampaignOptimizer(db)
        
        # Validate account capacity
        capacity_check = optimizer.validate_account_capacity(selected_accounts, len(recipients))
        if not capacity_check['sufficient_capacity']:
            return {
                'success': False, 
                'error': 'Insufficient capacity',
                'details': capacity_check
            }
        
        # Calculate optimal distribution
        distribution = optimizer.calculate_optimal_distribution(recipients, selected_accounts)
        
        # Clear existing assignments
        db.query(RecipientAssignment).filter(RecipientAssignment.campaign_id == campaign_id).delete()
        
        # Create optimized assignments
        assignments = optimizer.create_recipient_assignments(campaign_id, recipients, distribution)
        optimized_assignments = optimizer.optimize_sending_order(assignments)
        
        # Save assignments
        db.add_all(optimized_assignments)
        
        # Update campaign status to ready
        campaign.status = CampaignStatus.READY
        campaign.preparation_completed_at = func.now()
        db.commit()
        
        return {
            'success': True,
            'campaign_id': campaign_id,
            'total_recipients': len(recipients),
            'total_users': distribution['total_users'],
            'assignments_per_user': distribution['assignments_per_user'],
            'estimated_send_time': distribution['estimated_send_time'],
            'capacity_details': capacity_check
        }
    
    except Exception as e:
        # Revert campaign status on error
        campaign.status = CampaignStatus.DRAFT
        db.commit()
        return {'success': False, 'error': str(e)}


def get_advanced_campaign_stats(db: Session, campaign_id: int) -> schemas.CampaignStats:
    """Get advanced campaign statistics"""
    stats = db.query(
        func.count(Recipient.id).label('total'),
        func.sum(func.case((Recipient.status == RecipientStatus.SENT, 1), else_=0)).label('sent'),
        func.sum(func.case((Recipient.status == RecipientStatus.PENDING, 1), else_=0)).label('pending'),
        func.sum(func.case((Recipient.status == RecipientStatus.ASSIGNED, 1), else_=0)).label('assigned'),
        func.sum(func.case((Recipient.status == RecipientStatus.SENDING, 1), else_=0)).label('sending'),
        func.sum(func.case((Recipient.status == RecipientStatus.FAILED, 1), else_=0)).label('failed')
    ).filter(Recipient.campaign_id == campaign_id).first()
    
    return schemas.CampaignStats(
        total=stats.total or 0,
        sent=stats.sent or 0,
        pending=stats.pending or 0,
        assigned=stats.assigned or 0,
        sending=stats.sending or 0,
        failed=stats.failed or 0
    )


def get_campaign_assignments(db: Session, campaign_id: int) -> List[RecipientAssignment]:
    """Get all assignments for a campaign"""
    return db.query(RecipientAssignment).filter(
        RecipientAssignment.campaign_id == campaign_id
    ).all()


def get_user_assignments(db: Session, user_id: int, campaign_id: int) -> List[RecipientAssignment]:
    """Get assignments for a specific user in a campaign"""
    return db.query(RecipientAssignment).filter(
        RecipientAssignment.user_id == user_id,
        RecipientAssignment.campaign_id == campaign_id
    ).all()


def update_assignment_status(db: Session, assignment_id: int, recipient_status: RecipientStatus):
    """Update assignment and recipient status"""
    assignment = db.query(RecipientAssignment).filter(RecipientAssignment.id == assignment_id).first()
    if assignment:
        # Update recipient status
        recipient = db.query(Recipient).filter(Recipient.id == assignment.recipient_id).first()
        if recipient:
            recipient.status = recipient_status
            if recipient_status == RecipientStatus.SENT:
                recipient.sent_at = func.now()
            db.commit()


def get_sending_progress(db: Session, campaign_id: int) -> schemas.SendingProgress:
    """Get real-time sending progress"""
    stats = get_advanced_campaign_stats(db, campaign_id)
    campaign = get_campaign(db, campaign_id)
    
    progress_percentage = (stats.sent / stats.total * 100) if stats.total > 0 else 0
    
    # Calculate current send rate (simplified)
    current_send_rate = 0.0
    if campaign and campaign.sending_started_at:
        elapsed_seconds = (func.now() - campaign.sending_started_at).total_seconds()
        if elapsed_seconds > 0:
            current_send_rate = stats.sent / elapsed_seconds
    
    return schemas.SendingProgress(
        campaign_id=campaign_id,
        total_emails=stats.total,
        sent_emails=stats.sent,
        failed_emails=stats.failed,
        sending_emails=stats.sending,
        progress_percentage=progress_percentage,
        current_send_rate=current_send_rate,
        errors=[]  # Could be populated with recent errors
    )