import time
import json
from celery import Celery
from sqlalchemy.orm import sessionmaker
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import base64
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from core.config import settings
from database import engine
from models import CampaignStatus, RecipientStatus
import crud

# Create Celery app
celery_app = Celery(
    "speed_send",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=["tasks"]
)

# Configure Celery
celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=settings.celery_task_timeout,
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=1000,
)

# Create database session
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_gmail_service(credentials_dict: dict, admin_email: str):
    """Create Gmail service with domain-wide delegation"""
    credentials = Credentials.from_service_account_info(
        credentials_dict,
        scopes=['https://www.googleapis.com/auth/gmail.send']
    )
    
    # Delegate to the admin email
    delegated_credentials = credentials.with_subject(admin_email)
    
    service = build('gmail', 'v1', credentials=delegated_credentials)
    return service


def create_message(sender_email: str, to_email: str, subject: str, html_body: str, sender_name: str = None):
    """Create a message for an email"""
    message = MIMEMultipart('alternative')
    message['to'] = to_email
    message['from'] = f"{sender_name} <{sender_email}>" if sender_name else sender_email
    message['subject'] = subject

    # Create HTML part
    html_part = MIMEText(html_body, 'html')
    message.attach(html_part)

    # Encode message
    raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode()
    return {'raw': raw_message}


@celery_app.task(bind=True, autoretry_for=(Exception,), retry_kwargs={'max_retries': 3, 'countdown': 60})
def send_email_task(self, recipient_id: int, campaign_id: int, account_id: int):
    """Send individual email task"""
    db = SessionLocal()
    
    try:
        # Get recipient, campaign, and account
        recipient = db.query(crud.Recipient).filter(crud.Recipient.id == recipient_id).first()
        campaign = crud.get_campaign(db, campaign_id)
        account = crud.get_account(db, account_id)
        
        if not recipient or not campaign or not account:
            raise Exception("Recipient, campaign, or account not found")
        
        if not account.active:
            raise Exception("Account is not active")
        
        # Get account credentials
        credentials_dict = crud.get_account_credentials(account)
        
        # Create Gmail service
        service = get_gmail_service(credentials_dict, account.admin_email)
        
        # Create message
        message = create_message(
            sender_email=campaign.from_email,
            to_email=recipient.email,
            subject=campaign.subject,
            html_body=campaign.html_body,
            sender_name=campaign.from_name
        )
        
        # Send email
        result = service.users().messages().send(userId='me', body=message).execute()
        
        # Update recipient status
        crud.update_recipient_status(db, recipient_id, RecipientStatus.SENT)
        
        return f"Email sent successfully to {recipient.email}"
        
    except HttpError as error:
        error_msg = f"Gmail API error: {error}"
        crud.update_recipient_status(db, recipient_id, RecipientStatus.FAILED, error_msg)
        
        # Retry on rate limit errors
        if error.resp.status in [429, 500, 502, 503, 504]:
            raise self.retry(countdown=60 * (self.request.retries + 1))
        
        raise Exception(error_msg)
        
    except Exception as error:
        error_msg = f"Failed to send email: {str(error)}"
        crud.update_recipient_status(db, recipient_id, RecipientStatus.FAILED, error_msg)
        raise Exception(error_msg)
        
    finally:
        db.close()


@celery_app.task
def send_campaign_task(campaign_id: int):
    """Send entire campaign task"""
    db = SessionLocal()
    
    try:
        campaign = crud.get_campaign(db, campaign_id)
        if not campaign:
            raise Exception("Campaign not found")
        
        # Get active accounts for load balancing
        accounts = crud.get_active_accounts(db)
        if not accounts:
            raise Exception("No active accounts available")
        
        # Get pending recipients
        recipients = crud.get_pending_recipients(db, campaign_id, limit=10000)
        
        if not recipients:
            # No pending recipients, mark campaign as completed
            crud.update_campaign_status(db, campaign_id, CampaignStatus.COMPLETED)
            return "Campaign completed - no pending recipients"
        
        # Distribute recipients across accounts
        account_index = 0
        batch_delay = 0
        
        for i, recipient in enumerate(recipients):
            # Check if campaign is still in sending status
            campaign = crud.get_campaign(db, campaign_id)
            if campaign.status != CampaignStatus.SENDING:
                break
            
            # Round-robin account selection
            account = accounts[account_index % len(accounts)]
            account_index += 1
            
            # Schedule email task with staggered delays for rate limiting
            send_email_task.apply_async(
                args=[recipient.id, campaign_id, account.id],
                countdown=batch_delay
            )
            
            # Add delay every 10 emails to respect rate limits
            if (i + 1) % 10 == 0:
                batch_delay += 2  # 2 second delay between batches
        
        # Schedule periodic check for campaign completion
        check_campaign_completion.apply_async(
            args=[campaign_id],
            countdown=60  # Check after 1 minute
        )
        
        return f"Queued {len(recipients)} emails for campaign {campaign_id}"
        
    except Exception as error:
        crud.update_campaign_status(db, campaign_id, CampaignStatus.FAILED)
        raise Exception(f"Failed to process campaign: {str(error)}")
        
    finally:
        db.close()


@celery_app.task
def check_campaign_completion(campaign_id: int):
    """Check if campaign is completed and update status"""
    db = SessionLocal()
    
    try:
        campaign = crud.get_campaign(db, campaign_id)
        if not campaign or campaign.status != CampaignStatus.SENDING:
            return
        
        # Check if there are any pending recipients
        pending_recipients = crud.get_pending_recipients(db, campaign_id, limit=1)
        
        if not pending_recipients:
            # No pending recipients, mark as completed
            crud.update_campaign_status(db, campaign_id, CampaignStatus.COMPLETED)
            return "Campaign marked as completed"
        else:
            # Still has pending recipients, schedule another check
            check_campaign_completion.apply_async(
                args=[campaign_id],
                countdown=60  # Check again in 1 minute
            )
            return "Campaign still in progress"
            
    except Exception as error:
        return f"Error checking campaign completion: {str(error)}"
        
    finally:
        db.close()


# Periodic tasks can be configured here
celery_app.conf.beat_schedule = {
    'check-stalled-campaigns': {
        'task': 'tasks.check_stalled_campaigns',
        'schedule': 300.0,  # Every 5 minutes
    },
}


@celery_app.task
def check_stalled_campaigns():
    """Check for campaigns that might be stalled and restart them"""
    db = SessionLocal()
    
    try:
        # This is a placeholder for more sophisticated logic
        # You could check for campaigns that have been "SENDING" for too long
        # and have pending recipients that haven't been processed
        pass
        
    finally:
        db.close()