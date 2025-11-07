"""
Email sending utilities for SpeedSend with user delegation and load distribution
"""
import asyncio
import logging
from typing import Dict, List, Any
from concurrent.futures import ThreadPoolExecutor
import time
import json

from utils.gmail_service import GmailServiceManager, distribute_recipients_across_users
from models import Campaign, Recipient, User, Account
from database import SessionLocal
from utils.encryption import decrypt_data

logger = logging.getLogger(__name__)


class EmailSender:
    """
    Handles email sending with proper user delegation and load distribution
    """
    
    def __init__(self):
        self.gmail_manager = GmailServiceManager()
        self.executor = ThreadPoolExecutor(max_workers=50)
    
    async def send_campaign_emails(self, campaign_id: int, selected_account_ids: List[int]) -> Dict:
        """
        Send campaign emails using selected accounts and their users
        
        Args:
            campaign_id: ID of the campaign to send
            selected_account_ids: List of account IDs to use for sending
            
        Returns:
            Dictionary with sending results
        """
        db = SessionLocal()
        try:
            # Get campaign details
            campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
            if not campaign:
                raise ValueError(f"Campaign {campaign_id} not found")
            
            # Get recipients for this campaign
            recipients = db.query(Recipient).filter(
                Recipient.campaign_id == campaign_id,
                Recipient.status == 'Pending'
            ).all()
            
            if not recipients:
                return {
                    'success': True,
                    'message': 'No pending recipients to send',
                    'sent_count': 0,
                    'failed_count': 0
                }
            
            # Get selected accounts and their users
            accounts = db.query(Account).filter(
                Account.id.in_(selected_account_ids),
                Account.active == True
            ).all()
            
            if not accounts:
                raise ValueError("No active accounts found from selected accounts")
            
            # Collect all active users from selected accounts
            all_users = []
            account_credentials = {}
            
            for account in accounts:
                # Decrypt and load credentials
                credentials_data = decrypt_data(account.credentials_path)
                credentials_dict = json.loads(credentials_data)
                account_credentials[account.id] = credentials_dict
                
                # Get users for this account
                account_users = db.query(User).filter(
                    User.account_id == account.id,
                    User.status == 'Active'
                ).all()
                
                for user in account_users:
                    all_users.append({
                        'email': user.email,
                        'name': user.name,
                        'status': user.status,
                        'account_id': account.id,
                        'daily_sent_count': user.daily_sent_count,
                        'hourly_sent_count': user.hourly_sent_count
                    })
            
            if not all_users:
                raise ValueError("No active users found in selected accounts")
            
            # Convert recipients to proper format
            recipient_list = []
            for recipient in recipients:
                recipient_list.append({
                    'id': recipient.id,
                    'email': recipient.email,
                    'name': recipient.name,
                    'custom_data': recipient.custom_data or {}
                })
            
            # Distribute recipients across users
            user_assignments = distribute_recipients_across_users(
                recipient_list, all_users, campaign_id
            )
            
            logger.info(f"Distributed {len(recipient_list)} recipients across {len(user_assignments)} users")
            
            # Send emails concurrently
            send_results = await self._send_emails_concurrently(
                campaign, user_assignments, account_credentials
            )
            
            # Update database with results
            await self._update_sending_results(db, send_results)
            
            # Calculate final stats
            sent_count = sum(1 for result in send_results if result.get('success'))
            failed_count = len(send_results) - sent_count
            
            return {
                'success': True,
                'campaign_id': campaign_id,
                'sent_count': sent_count,
                'failed_count': failed_count,
                'total_recipients': len(recipient_list),
                'users_used': len(user_assignments),
                'accounts_used': len(accounts),
                'send_results': send_results
            }
            
        except Exception as e:
            logger.error(f"Error sending campaign {campaign_id}: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'campaign_id': campaign_id
            }
        finally:
            db.close()
    
    async def _send_emails_concurrently(self, campaign: Campaign, 
                                      user_assignments: Dict[str, List[Dict]],
                                      account_credentials: Dict[int, Dict]) -> List[Dict]:
        """
        Send emails concurrently using multiple users
        """
        send_tasks = []
        
        for user_email, recipients in user_assignments.items():
            if not recipients:
                continue
            
            # Find the account for this user
            user_account_id = recipients[0].get('account_id') if recipients else None
            if user_account_id in account_credentials:
                credentials_dict = account_credentials[user_account_id]
                
                # Create task for this user's recipients
                task = self._send_user_emails(
                    campaign, user_email, recipients, credentials_dict
                )
                send_tasks.append(task)
        
        # Execute all sending tasks concurrently
        if send_tasks:
            results = await asyncio.gather(*send_tasks, return_exceptions=True)
            
            # Flatten results
            all_results = []
            for result in results:
                if isinstance(result, Exception):
                    logger.error(f"Sending task failed: {str(result)}")
                    continue
                if isinstance(result, list):
                    all_results.extend(result)
                else:
                    all_results.append(result)
            
            return all_results
        
        return []
    
    async def _send_user_emails(self, campaign: Campaign, user_email: str, 
                              recipients: List[Dict], credentials_dict: Dict) -> List[Dict]:
        """
        Send emails for a specific user with rate limiting
        """
        results = []
        
        try:
            # Get Gmail service for this user
            service = self.gmail_manager.get_gmail_service(credentials_dict, user_email)
            
            for recipient in recipients:
                try:
                    # Create email message
                    message = self.gmail_manager.create_message(
                        sender_email=user_email,
                        to_email=recipient['email'],
                        to_name=recipient['name'],
                        subject=campaign.subject,
                        html_body=self._process_template(campaign.html_body, recipient['custom_data']),
                        sender_name=campaign.from_name,
                        custom_headers=campaign.custom_headers
                    )
                    
                    # Send email
                    sent_message = service.users().messages().send(
                        userId='me', body={'raw': message}
                    ).execute()
                    
                    results.append({
                        'success': True,
                        'recipient_id': recipient['id'],
                        'recipient_email': recipient['email'],
                        'sender_user': user_email,
                        'message_id': sent_message.get('id'),
                        'sent_at': time.time()
                    })
                    
                    logger.info(f"Email sent to {recipient['email']} via {user_email}")
                    
                    # Rate limiting - respect Gmail API limits
                    await asyncio.sleep(0.1)  # 10 emails per second max per user
                    
                except Exception as e:
                    logger.error(f"Failed to send email to {recipient['email']} via {user_email}: {str(e)}")
                    results.append({
                        'success': False,
                        'recipient_id': recipient['id'],
                        'recipient_email': recipient['email'],
                        'sender_user': user_email,
                        'error': str(e),
                        'sent_at': time.time()
                    })
            
        except Exception as e:
            logger.error(f"Failed to initialize sending for user {user_email}: {str(e)}")
            # Mark all recipients for this user as failed
            for recipient in recipients:
                results.append({
                    'success': False,
                    'recipient_id': recipient['id'],
                    'recipient_email': recipient['email'],
                    'sender_user': user_email,
                    'error': f"User setup failed: {str(e)}",
                    'sent_at': time.time()
                })
        
        return results
    
    def _process_template(self, html_body: str, custom_data: Dict) -> str:
        """
        Process email template with recipient-specific data
        
        Args:
            html_body: HTML template with {{variable}} placeholders
            custom_data: Dictionary with variable values
            
        Returns:
            Processed HTML content
        """
        if not custom_data:
            return html_body
        
        processed = html_body
        for key, value in custom_data.items():
            placeholder = f"{{{{{key}}}}}"
            processed = processed.replace(placeholder, str(value))
        
        return processed
    
    async def _update_sending_results(self, db, send_results: List[Dict]):
        """
        Update database with sending results
        """
        try:
            for result in send_results:
                recipient_id = result.get('recipient_id')
                if recipient_id:
                    recipient = db.query(Recipient).filter(
                        Recipient.id == recipient_id
                    ).first()
                    
                    if recipient:
                        if result.get('success'):
                            recipient.status = 'Sent'
                            recipient.sent_at = result.get('sent_at')
                        else:
                            recipient.status = 'Failed'
                            recipient.last_error = result.get('error', 'Unknown error')
            
            db.commit()
            logger.info(f"Updated {len(send_results)} recipient statuses")
            
        except Exception as e:
            logger.error(f"Error updating sending results: {str(e)}")
            db.rollback()


# Global email sender instance
email_sender = EmailSender()