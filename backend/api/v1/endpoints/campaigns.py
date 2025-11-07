from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List
import asyncio

import crud
import schemas
from database import get_db
from models import CampaignStatus
from utils.ultra_fast_sender import UltraFastSender, ThreadedUltraFastSender
from tasks import send_campaign_task

router = APIRouter()


@router.post("/campaigns", response_model=schemas.Campaign, status_code=status.HTTP_201_CREATED)
def create_campaign(
    campaign: schemas.CampaignCreate,
    db: Session = Depends(get_db)
):
    """Create a new advanced campaign"""
    try:
        db_campaign = crud.create_advanced_campaign(db=db, campaign=campaign)
        
        # Get stats for the response
        stats = crud.get_advanced_campaign_stats(db=db, campaign_id=db_campaign.id)
        
        # Convert to response model
        campaign_response = schemas.Campaign(
            id=db_campaign.id,
            name=db_campaign.name,
            from_name=db_campaign.from_name,
            from_email=db_campaign.from_email,
            subject=db_campaign.subject,
            status=db_campaign.status,
            custom_headers=db_campaign.custom_headers,
            test_email=db_campaign.test_email,
            selected_accounts=db_campaign.selected_accounts,
            send_rate_per_minute=db_campaign.send_rate_per_minute,
            preparation_started_at=db_campaign.preparation_started_at,
            preparation_completed_at=db_campaign.preparation_completed_at,
            sending_started_at=db_campaign.sending_started_at,
            sending_completed_at=db_campaign.sending_completed_at,
            created_at=db_campaign.created_at,
            stats=stats
        )
        
        return campaign_response
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to create campaign: {str(e)}"
        )


@router.get("/campaigns", response_model=List[schemas.Campaign])
def list_campaigns(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """Get all campaigns with advanced stats"""
    campaigns = crud.get_campaigns(db=db, skip=skip, limit=limit)
    
    result = []
    for campaign in campaigns:
        stats = crud.get_advanced_campaign_stats(db=db, campaign_id=campaign.id)
        campaign_response = schemas.Campaign(
            id=campaign.id,
            name=campaign.name,
            from_name=campaign.from_name,
            from_email=campaign.from_email,
            subject=campaign.subject,
            status=campaign.status,
            custom_headers=campaign.custom_headers,
            test_email=campaign.test_email,
            selected_accounts=campaign.selected_accounts,
            send_rate_per_minute=campaign.send_rate_per_minute,
            preparation_started_at=campaign.preparation_started_at,
            preparation_completed_at=campaign.preparation_completed_at,
            sending_started_at=campaign.sending_started_at,
            sending_completed_at=campaign.sending_completed_at,
            created_at=campaign.created_at,
            stats=stats
        )
        result.append(campaign_response)
    
    return result


@router.get("/campaigns/{campaign_id}", response_model=schemas.CampaignDetail)
def get_campaign(
    campaign_id: int,
    db: Session = Depends(get_db)
):
    """Get campaign details with recipients"""
    campaign = crud.get_campaign(db=db, campaign_id=campaign_id)
    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )
    
    recipients = crud.get_campaign_recipients(db=db, campaign_id=campaign_id)
    stats = crud.get_campaign_stats(db=db, campaign_id=campaign_id)
    
    return schemas.CampaignDetail(
        id=campaign.id,
        name=campaign.name,
        from_name=campaign.from_name,
        from_email=campaign.from_email,
        subject=campaign.subject,
        html_body=campaign.html_body,
        status=campaign.status,
        created_at=campaign.created_at,
        stats=stats,
        recipients=[schemas.Recipient(
            id=r.id,
            email=r.email,
            name=r.name,
            status=r.status,
            last_error=r.last_error,
            sent_at=r.sent_at
        ) for r in recipients]
    )


@router.post("/campaigns/{campaign_id}/send")
def start_campaign(
    campaign_id: int,
    db: Session = Depends(get_db)
):
    """Start sending a campaign"""
    campaign = crud.get_campaign(db=db, campaign_id=campaign_id)
    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )
    
    if campaign.status != CampaignStatus.DRAFT:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Campaign must be in Draft status to start sending"
        )
    
    # Update status to sending
    crud.update_campaign_status(db=db, campaign_id=campaign_id, status=CampaignStatus.SENDING)
    
    # Start Celery task
    send_campaign_task.delay(campaign_id)
    
    return {"message": "Campaign sending started"}


@router.post("/campaigns/{campaign_id}/pause")
def pause_campaign(
    campaign_id: int,
    db: Session = Depends(get_db)
):
    """Pause a campaign"""
    campaign = crud.get_campaign(db=db, campaign_id=campaign_id)
    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )
    
    if campaign.status != CampaignStatus.SENDING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Campaign must be sending to pause"
        )
    
    crud.update_campaign_status(db=db, campaign_id=campaign_id, status=CampaignStatus.PAUSED)
    
    return {"message": "Campaign paused"}


@router.post("/campaigns/{campaign_id}/prepare", response_model=schemas.CampaignPreparation)
def prepare_campaign(
    campaign_id: int,
    selected_accounts: List[int],
    db: Session = Depends(get_db)
):
    """Prepare campaign for ultra-fast sending"""
    result = crud.prepare_campaign_for_sending(db=db, campaign_id=campaign_id, selected_accounts=selected_accounts)
    
    if not result['success']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result['error']
        )
    
    return schemas.CampaignPreparation(
        campaign_id=result['campaign_id'],
        selected_accounts=selected_accounts,
        total_recipients=result['total_recipients'],
        total_users=result['total_users'],
        assignments_per_user=result['assignments_per_user'],
        estimated_send_time=result['estimated_send_time']
    )


@router.post("/campaigns/{campaign_id}/send-ultra-fast")
async def send_campaign_ultra_fast(
    campaign_id: int,
    background_tasks: BackgroundTasks,
    use_threading: bool = True,
    db: Session = Depends(get_db)
):
    """Send campaign using ultra-fast method"""
    campaign = crud.get_campaign(db=db, campaign_id=campaign_id)
    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )
    
    if campaign.status != CampaignStatus.READY:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Campaign must be prepared (READY status) before sending"
        )
    
    # Choose sending method based on preference
    if use_threading:
        # Use threaded sender for maximum performance
        def send_threaded():
            sender = ThreadedUltraFastSender(db, campaign_id)
            result = sender.send_campaign_threaded(max_workers=200)
            return result
        
        background_tasks.add_task(send_threaded)
    else:
        # Use async sender
        async def send_async():
            sender = UltraFastSender(db, campaign_id)
            result = await sender.send_campaign_ultra_fast()
            return result
        
        background_tasks.add_task(send_async)
    
    return {"message": "Ultra-fast sending started", "method": "threaded" if use_threading else "async"}


@router.post("/campaigns/{campaign_id}/test-email")
def send_test_email(
    test_data: schemas.SendTestEmail,
    db: Session = Depends(get_db)
):
    """Send a test email"""
    campaign = crud.get_campaign(db=db, campaign_id=test_data.campaign_id)
    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )
    
    # Get first available account and user for testing
    if campaign.selected_accounts:
        account_id = campaign.selected_accounts[0]
        account = crud.get_account(db=db, account_id=account_id)
        if account:
            users = crud.get_account_users(db=db, account_id=account_id)
            if users:
                user = users[0]
                
                try:
                    # Send test email using the ultra-fast sender logic
                    from utils.gmail_service import gmail_service_manager
                    
                    credentials_dict = crud.get_account_credentials(account)
                    service = gmail_service_manager.get_gmail_service(credentials_dict, user.email)
                    
                    message = gmail_service_manager.create_message(
                        sender_email=campaign.from_email,
                        to_email=test_data.test_email,
                        to_name="Test User",
                        subject=f"[TEST] {campaign.subject}",
                        html_body=campaign.html_body,
                        sender_name=campaign.from_name,
                        custom_headers=campaign.custom_headers
                    )
                    
                    result = service.users().messages().send(userId='me', body=message).execute()
                    
                    return {
                        "success": True,
                        "message": f"Test email sent to {test_data.test_email}",
                        "message_id": result.get('id'),
                        "sender_user": user.email
                    }
                    
                except Exception as e:
                    raise HTTPException(
                        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                        detail=f"Failed to send test email: {str(e)}"
                    )
    
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="No available accounts or users for testing"
    )


@router.get("/campaigns/{campaign_id}/progress", response_model=schemas.SendingProgress)
def get_campaign_progress(
    campaign_id: int,
    db: Session = Depends(get_db)
):
    """Get real-time campaign sending progress"""
    campaign = crud.get_campaign(db=db, campaign_id=campaign_id)
    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )
    
    return crud.get_sending_progress(db=db, campaign_id=campaign_id)


@router.get("/campaigns/{campaign_id}/assignments")
def get_campaign_assignments(
    campaign_id: int,
    db: Session = Depends(get_db)
):
    """Get campaign assignments breakdown"""
    campaign = crud.get_campaign(db=db, campaign_id=campaign_id)
    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )
    
    assignments = crud.get_campaign_assignments(db=db, campaign_id=campaign_id)
    
    # Group assignments by user
    user_assignments = {}
    for assignment in assignments:
        user_id = assignment.user_id
        if user_id not in user_assignments:
            user = crud.get_account_users(db, assignment.user.account_id)
            user_info = next((u for u in user if u.id == user_id), None)
            if user_info:
                user_assignments[user_id] = {
                    'user_email': user_info.email,
                    'user_name': user_info.name,
                    'account_id': user_info.account_id,
                    'assignments': []
                }
        
        if user_id in user_assignments:
            user_assignments[user_id]['assignments'].append({
                'recipient_id': assignment.recipient_id,
                'batch_number': assignment.batch_number,
                'priority': assignment.priority,
                'assigned_at': assignment.assigned_at
            })
    
    return {
        'campaign_id': campaign_id,
        'total_assignments': len(assignments),
        'users': user_assignments
    }