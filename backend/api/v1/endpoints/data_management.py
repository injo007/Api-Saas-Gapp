from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List

import crud
import schemas
from database import get_db
from models import Campaign, Recipient, Account, User

router = APIRouter()


@router.delete("/campaigns/{campaign_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_campaign(
    campaign_id: int,
    db: Session = Depends(get_db)
):
    """Delete a campaign and all its recipients"""
    try:
        campaign = crud.get_campaign(db=db, campaign_id=campaign_id)
        if not campaign:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Campaign not found"
            )
        
        # Delete all recipients first
        db.query(Recipient).filter(Recipient.campaign_id == campaign_id).delete()
        
        # Delete the campaign
        db.delete(campaign)
        db.commit()
        
        return {"message": "Campaign deleted successfully"}
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete campaign: {str(e)}"
        )


@router.delete("/bulk-delete/{data_type}", status_code=status.HTTP_204_NO_CONTENT)
def bulk_delete_data(
    data_type: str,
    db: Session = Depends(get_db)
):
    """Bulk delete campaigns or recipients"""
    try:
        if data_type == "campaigns":
            # Delete all recipients first
            db.query(Recipient).delete()
            # Delete all campaigns
            db.query(Campaign).delete()
            db.commit()
            return {"message": "All campaigns and recipients deleted"}
            
        elif data_type == "recipients":
            # Delete all recipients
            db.query(Recipient).delete()
            db.commit()
            return {"message": "All recipients deleted"}
            
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid data type. Use 'campaigns' or 'recipients'"
            )
            
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to bulk delete: {str(e)}"
        )


@router.get("/database/stats")
def get_database_stats(db: Session = Depends(get_db)):
    """Get detailed database statistics"""
    try:
        # Count records in each table
        stats = {
            "accounts": {
                "total": db.query(func.count(Account.id)).scalar(),
                "active": db.query(func.count(Account.id)).filter(Account.active == True).scalar()
            },
            "users": {
                "total": db.query(func.count(User.id)).scalar(),
                "active": db.query(func.count(User.id)).filter(User.status == "Active").scalar()
            },
            "campaigns": {
                "total": db.query(func.count(Campaign.id)).scalar(),
                "draft": db.query(func.count(Campaign.id)).filter(Campaign.status == "Draft").scalar(),
                "sending": db.query(func.count(Campaign.id)).filter(Campaign.status == "Sending").scalar(),
                "completed": db.query(func.count(Campaign.id)).filter(Campaign.status == "Completed").scalar(),
                "failed": db.query(func.count(Campaign.id)).filter(Campaign.status == "Failed").scalar()
            },
            "recipients": {
                "total": db.query(func.count(Recipient.id)).scalar(),
                "pending": db.query(func.count(Recipient.id)).filter(Recipient.status == "Pending").scalar(),
                "sent": db.query(func.count(Recipient.id)).filter(Recipient.status == "Sent").scalar(),
                "failed": db.query(func.count(Recipient.id)).filter(Recipient.status == "Failed").scalar()
            }
        }
        
        return stats
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get database stats: {str(e)}"
        )


@router.get("/campaigns/{campaign_id}/recipients", response_model=List[schemas.Recipient])
def get_campaign_recipients(
    campaign_id: int,
    skip: int = 0,
    limit: int = 1000,
    db: Session = Depends(get_db)
):
    """Get recipients for a specific campaign"""
    try:
        campaign = crud.get_campaign(db=db, campaign_id=campaign_id)
        if not campaign:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Campaign not found"
            )
        
        recipients = db.query(Recipient).filter(
            Recipient.campaign_id == campaign_id
        ).offset(skip).limit(limit).all()
        
        return recipients
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get campaign recipients: {str(e)}"
        )