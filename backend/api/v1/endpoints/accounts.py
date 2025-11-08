from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile, Form
from sqlalchemy.orm import Session
from typing import List
import json
import asyncio

import crud
import schemas
from database import get_db
from utils.gmail_service import validate_gmail_credentials, get_workspace_users

router = APIRouter()


@router.post("/accounts", response_model=schemas.Account, status_code=status.HTTP_201_CREATED)
async def create_account(
    name: str = Form(...),
    admin_email: str = Form(...),
    json_file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """Create a new account with JSON file upload (Frontend Compatible)"""
    try:
        # Read the uploaded JSON file
        contents = await json_file.read()
        credentials_json = contents.decode('utf-8')
        
        # Validate JSON format
        try:
            json.loads(credentials_json)
        except json.JSONDecodeError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid JSON file format"
            )
        
        # Create account data object
        account_data = schemas.AccountCreate(
            name=name,
            admin_email=admin_email,
            credentials_json=credentials_json
        )
        
        return crud.create_account(db=db, account=account_data)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to create account: {str(e)}"
        )


@router.get("/accounts", response_model=List[schemas.AccountWithUsers])
def list_accounts(
    skip: int = 0,
    limit: int = 100,
    include_users: bool = True,
    db: Session = Depends(get_db)
):
    """Get all accounts with users"""
    accounts = crud.get_accounts(db=db, skip=skip, limit=limit)
    
    if include_users:
        result = []
        for account in accounts:
            users = crud.get_account_users(db=db, account_id=account.id)
            account_with_users = schemas.AccountWithUsers(
                id=account.id,
                name=account.name,
                admin_email=account.admin_email,
                active=account.active,
                user_count=account.user_count,
                daily_quota=account.daily_quota,
                hourly_quota=account.hourly_quota,
                created_at=account.created_at,
                last_sync_at=account.last_sync_at,
                users=[schemas.User(
                    id=u.id,
                    email=u.email,
                    name=u.name,
                    status=u.status,
                    daily_sent_count=u.daily_sent_count,
                    hourly_sent_count=u.hourly_sent_count,
                    last_sent_at=u.last_sent_at,
                    last_error=u.last_error
                ) for u in users]
            )
            result.append(account_with_users)
        return result
    else:
        return [schemas.Account(
            id=a.id,
            name=a.name,
            admin_email=a.admin_email,
            active=a.active,
            user_count=a.user_count,
            daily_quota=a.daily_quota,
            hourly_quota=a.hourly_quota,
            created_at=a.created_at,
            last_sync_at=a.last_sync_at
        ) for a in accounts]


@router.get("/accounts/{account_id}", response_model=schemas.Account)
def get_account(
    account_id: int,
    db: Session = Depends(get_db)
):
    """Get account by ID"""
    account = crud.get_account(db=db, account_id=account_id)
    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found"
        )
    return account


@router.patch("/accounts/{account_id}", response_model=schemas.Account)
def update_account(
    account_id: int,
    account_update: schemas.AccountUpdate,
    db: Session = Depends(get_db)
):
    """Update account (e.g., toggle active status)"""
    account = crud.update_account(db=db, account_id=account_id, account_update=account_update)
    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found"
        )
    return account


@router.delete("/accounts/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    account_id: int,
    db: Session = Depends(get_db)
):
    """Delete account and its credentials"""
    success = crud.delete_account(db=db, account_id=account_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found"
        )


@router.post("/accounts/validate", response_model=schemas.AccountValidationResult)
def validate_account_credentials(
    validation_data: schemas.AccountValidation,
    db: Session = Depends(get_db)
):
    """Validate account credentials and get user count"""
    result = crud.validate_account_credentials(
        validation_data.credentials_json, 
        validation_data.admin_email
    )
    
    if result.get('valid'):
        # Get user count from workspace
        try:
            credentials_dict = json.loads(validation_data.credentials_json)
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                users_data = loop.run_until_complete(
                    get_workspace_users(credentials_dict, validation_data.admin_email)
                )
                result['user_count'] = len(users_data)
            finally:
                loop.close()
        except Exception as e:
            result['user_count'] = 0
    
    return schemas.AccountValidationResult(**result)


@router.post("/accounts/{account_id}/sync")
def sync_account_users(
    account_id: int,
    db: Session = Depends(get_db)
):
    """Sync users from Google Workspace"""
    result = crud.sync_account_users(db=db, account_id=account_id)
    if not result['success']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result['error']
        )
    return result


@router.get("/accounts/{account_id}/users", response_model=List[schemas.User])
def get_account_users(
    account_id: int,
    db: Session = Depends(get_db)
):
    """Get all users for an account"""
    account = crud.get_account(db=db, account_id=account_id)
    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found"
        )
    
    users = crud.get_account_users(db=db, account_id=account_id)
    return [schemas.User(
        id=u.id,
        email=u.email,
        name=u.name,
        status=u.status,
        daily_sent_count=u.daily_sent_count,
        hourly_sent_count=u.hourly_sent_count,
        last_sent_at=u.last_sent_at,
        last_error=u.last_error
    ) for u in users]