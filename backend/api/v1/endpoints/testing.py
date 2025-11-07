from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Dict, Any
import json
import re

import crud
import schemas
from database import get_db
from utils.gmail_service import validate_gmail_credentials

router = APIRouter()


class TemplateValidation(BaseModel):
    template: str
    test_data: Dict[str, Any]


class TestConnectionResponse(BaseModel):
    success: bool
    message: str
    details: Dict[str, Any] = {}


@router.post("/templates/validate")
def validate_template(
    validation: TemplateValidation,
    db: Session = Depends(get_db)
):
    """Validate and render an email template"""
    try:
        template = validation.template
        test_data = validation.test_data
        
        # Find all template variables in the format {{variable}}
        variables = re.findall(r'{{\s*(\w+)\s*}}', template)
        
        # Check if all variables have corresponding test data
        missing_variables = [var for var in variables if var not in test_data]
        
        if missing_variables:
            return {
                "valid": False,
                "error": f"Missing test data for variables: {', '.join(missing_variables)}",
                "required_variables": variables,
                "missing_variables": missing_variables
            }
        
        # Render the template
        rendered = template
        for var, value in test_data.items():
            pattern = r'{{\s*' + re.escape(var) + r'\s*}}'
            rendered = re.sub(pattern, str(value), rendered)
        
        # Check for unresolved variables
        unresolved = re.findall(r'{{\s*\w+\s*}}', rendered)
        
        if unresolved:
            return {
                "valid": False,
                "error": f"Unresolved template variables: {', '.join(unresolved)}",
                "rendered": rendered,
                "unresolved_variables": unresolved
            }
        
        return {
            "valid": True,
            "rendered": rendered,
            "variables_used": variables,
            "message": "Template validated successfully"
        }
        
    except Exception as e:
        return {
            "valid": False,
            "error": f"Template validation error: {str(e)}"
        }


@router.post("/accounts/{account_id}/test-connection", response_model=TestConnectionResponse)
def test_account_connection(
    account_id: int,
    db: Session = Depends(get_db)
):
    """Test connection to a Gmail account"""
    try:
        account = crud.get_account(db=db, account_id=account_id)
        if not account:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Account not found"
            )
        
        # Load credentials from file
        try:
            with open(account.credentials_path, 'r') as f:
                credentials_data = f.read()
            
            # Test the credentials
            validation_result = validate_gmail_credentials(credentials_data, account.admin_email)
            
            if validation_result.get('valid'):
                # Try to sync users to test the connection further
                sync_result = crud.sync_account_users(db=db, account_id=account_id)
                
                return TestConnectionResponse(
                    success=True,
                    message=f"Connection successful. Found {validation_result.get('user_count', 0)} workspace users.",
                    details={
                        "account_email": validation_result.get('email'),
                        "user_count": validation_result.get('user_count'),
                        "sync_result": sync_result,
                        "gmail_stats": {
                            "messages_total": validation_result.get('messages_total'),
                            "threads_total": validation_result.get('threads_total')
                        }
                    }
                )
            else:
                return TestConnectionResponse(
                    success=False,
                    message=f"Connection failed: {validation_result.get('error', 'Unknown error')}",
                    details={"validation_result": validation_result}
                )
                
        except FileNotFoundError:
            return TestConnectionResponse(
                success=False,
                message="Credentials file not found",
                details={"credentials_path": account.credentials_path}
            )
        except json.JSONDecodeError:
            return TestConnectionResponse(
                success=False,
                message="Invalid credentials file format",
                details={"credentials_path": account.credentials_path}
            )
            
    except Exception as e:
        return TestConnectionResponse(
            success=False,
            message=f"Connection test failed: {str(e)}",
            details={"error": str(e)}
        )


@router.post("/campaigns/{campaign_id}/test-send")
def test_campaign_send(
    campaign_id: int,
    test_email: str,
    db: Session = Depends(get_db)
):
    """Send a test email for a campaign"""
    try:
        campaign = crud.get_campaign(db=db, campaign_id=campaign_id)
        if not campaign:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Campaign not found"
            )
        
        # Create a test recipient
        test_recipient = {
            "email": test_email,
            "name": "Test User",
            "custom_data": {}
        }
        
        # Here you would normally send the actual email
        # For now, we'll just validate the setup
        
        return {
            "success": True,
            "message": f"Test email would be sent to {test_email}",
            "campaign_details": {
                "campaign_id": campaign.id,
                "campaign_name": campaign.name,
                "subject": campaign.subject,
                "from_email": campaign.from_email,
                "from_name": campaign.from_name
            },
            "test_recipient": test_recipient
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Test send failed: {str(e)}"
        )


@router.get("/system/health")
def get_system_health(db: Session = Depends(get_db)):
    """Get system health status"""
    try:
        # Test database connection
        db.execute("SELECT 1").scalar()
        
        # Get basic stats
        accounts_count = db.query(crud.Account).count()
        campaigns_count = db.query(crud.Campaign).count()
        
        return {
            "status": "healthy",
            "database": "connected",
            "api": "operational",
            "accounts": accounts_count,
            "campaigns": campaigns_count,
            "timestamp": crud.datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {
            "status": "unhealthy",
            "database": "error",
            "api": "degraded",
            "error": str(e),
            "timestamp": crud.datetime.utcnow().isoformat()
        }