import asyncio
import time
from typing import List, Dict
from sqlalchemy.orm import Session
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

from models import Campaign, RecipientAssignment, Recipient, User, CampaignStatus, RecipientStatus
from utils.gmail_service import gmail_service_manager
import crud


class UltraFastSender:
    """
    Ultra-fast email sender optimized for sending 17k emails in under 20 seconds
    """
    
    def __init__(self, db: Session, campaign_id: int):
        self.db = db
        self.campaign_id = campaign_id
        self.campaign = crud.get_campaign(db, campaign_id)
        self.stats = {
            'sent': 0,
            'failed': 0,
            'start_time': None,
            'end_time': None
        }
        self.stop_sending = False
        
    async def send_campaign_ultra_fast(self) -> Dict:
        """
        Send entire campaign at maximum speed
        Target: 17,000 emails in under 20 seconds
        """
        if not self.campaign or self.campaign.status != CampaignStatus.READY:
            return {'success': False, 'error': 'Campaign not ready for sending'}
        
        try:
            # Update campaign status
            self.campaign.status = CampaignStatus.SENDING
            self.campaign.sending_started_at = crud.func.now()
            self.db.commit()
            
            self.stats['start_time'] = time.time()
            
            # Get all assignments grouped by user
            assignments = crud.get_campaign_assignments(self.db, self.campaign_id)
            if not assignments:
                return {'success': False, 'error': 'No assignments found'}
            
            # Group assignments by user
            user_assignments = {}
            for assignment in assignments:
                user_id = assignment.user_id
                if user_id not in user_assignments:
                    user_assignments[user_id] = []
                user_assignments[user_id].append(assignment)
            
            # Create sending tasks for each user
            sending_tasks = []
            for user_id, user_assignment_list in user_assignments.items():
                task = self.send_user_batch(user_id, user_assignment_list)
                sending_tasks.append(task)
            
            # Execute all sending tasks concurrently
            results = await asyncio.gather(*sending_tasks, return_exceptions=True)
            
            # Process results
            total_sent = 0
            total_failed = 0
            
            for result in results:
                if isinstance(result, dict):
                    total_sent += result.get('sent', 0)
                    total_failed += result.get('failed', 0)
                else:
                    print(f"Task error: {result}")
                    total_failed += 1
            
            self.stats['end_time'] = time.time()
            self.stats['sent'] = total_sent
            self.stats['failed'] = total_failed
            
            # Update campaign status
            if total_failed == 0:
                self.campaign.status = CampaignStatus.COMPLETED
            else:
                self.campaign.status = CampaignStatus.FAILED if total_sent == 0 else CampaignStatus.COMPLETED
            
            self.campaign.sending_completed_at = crud.func.now()
            self.db.commit()
            
            elapsed_time = self.stats['end_time'] - self.stats['start_time']
            send_rate = total_sent / elapsed_time if elapsed_time > 0 else 0
            
            return {
                'success': True,
                'total_sent': total_sent,
                'total_failed': total_failed,
                'elapsed_time': elapsed_time,
                'send_rate': send_rate,
                'emails_per_second': send_rate
            }
            
        except Exception as e:
            self.campaign.status = CampaignStatus.FAILED
            self.db.commit()
            return {'success': False, 'error': str(e)}
    
    async def send_user_batch(self, user_id: int, assignments: List[RecipientAssignment]) -> Dict:
        """
        Send all emails assigned to a specific user using maximum concurrency
        """
        try:
            # Get user and account info
            user = self.db.query(User).filter(User.id == user_id).first()
            if not user:
                return {'sent': 0, 'failed': len(assignments), 'error': 'User not found'}
            
            account = crud.get_account(self.db, user.account_id)
            if not account:
                return {'sent': 0, 'failed': len(assignments), 'error': 'Account not found'}
            
            # Get account credentials
            credentials_dict = crud.get_account_credentials(account)
            
            # Prepare email data for batch sending
            email_batch = []
            for assignment in assignments:
                recipient = self.db.query(Recipient).filter(Recipient.id == assignment.recipient_id).first()
                if recipient:
                    email_data = {
                        'recipient_id': recipient.id,
                        'assignment_id': assignment.id,
                        'user_email': user.email,
                        'from_email': self.campaign.from_email,
                        'from_name': self.campaign.from_name,
                        'to_email': recipient.email,
                        'to_name': recipient.name,
                        'subject': self.campaign.subject,
                        'html_body': self.campaign.html_body,
                    }
                    email_batch.append(email_data)
            
            # Send batch with maximum concurrency (100 concurrent requests per user)
            results = await gmail_service_manager.send_batch_emails(
                email_batch, 
                credentials_dict, 
                custom_headers=self.campaign.custom_headers,
                max_concurrent=100  # Very high concurrency for speed
            )
            
            # Process results and update database
            sent_count = 0
            failed_count = 0
            
            for result in results:
                try:
                    recipient_id = result.get('recipient_id')
                    if result.get('success'):
                        crud.update_recipient_status(self.db, recipient_id, RecipientStatus.SENT)
                        crud.increment_user_sent_count(self.db, user_id)
                        sent_count += 1
                    else:
                        error_msg = result.get('error', 'Unknown error')
                        crud.update_recipient_status(self.db, recipient_id, RecipientStatus.FAILED, error_msg)
                        failed_count += 1
                        
                        # Update user status if needed
                        if not result.get('retry', False):
                            crud.update_user_status(self.db, user_id, crud.UserStatus.ERROR, error_msg)
                except Exception as e:
                    print(f"Error processing result: {e}")
                    failed_count += 1
            
            return {'sent': sent_count, 'failed': failed_count}
            
        except Exception as e:
            print(f"Error in send_user_batch: {e}")
            # Mark all assignments as failed
            for assignment in assignments:
                crud.update_recipient_status(self.db, assignment.recipient_id, RecipientStatus.FAILED, str(e))
            
            return {'sent': 0, 'failed': len(assignments), 'error': str(e)}
    
    def stop_campaign(self):
        """Stop the campaign sending"""
        self.stop_sending = True
        self.campaign.status = CampaignStatus.PAUSED
        self.db.commit()


# Threaded sender for maximum performance
class ThreadedUltraFastSender:
    """
    Alternative implementation using threading for even higher performance
    """
    
    def __init__(self, db: Session, campaign_id: int):
        self.db = db
        self.campaign_id = campaign_id
        self.campaign = crud.get_campaign(db, campaign_id)
        self.stats = {'sent': 0, 'failed': 0}
        self.lock = threading.Lock()
    
    def send_campaign_threaded(self, max_workers: int = 200) -> Dict:
        """
        Send campaign using ThreadPoolExecutor for maximum speed
        """
        if not self.campaign or self.campaign.status != CampaignStatus.READY:
            return {'success': False, 'error': 'Campaign not ready for sending'}
        
        start_time = time.time()
        
        try:
            # Update campaign status
            self.campaign.status = CampaignStatus.SENDING
            self.campaign.sending_started_at = crud.func.now()
            self.db.commit()
            
            # Get all assignments
            assignments = crud.get_campaign_assignments(self.db, self.campaign_id)
            
            # Create thread pool for maximum concurrency
            with ThreadPoolExecutor(max_workers=max_workers) as executor:
                # Submit all email sending tasks
                future_to_assignment = {
                    executor.submit(self.send_single_email_threaded, assignment): assignment 
                    for assignment in assignments
                }
                
                # Process completed tasks
                for future in as_completed(future_to_assignment):
                    assignment = future_to_assignment[future]
                    try:
                        result = future.result()
                        with self.lock:
                            if result['success']:
                                self.stats['sent'] += 1
                            else:
                                self.stats['failed'] += 1
                    except Exception as e:
                        print(f"Email sending error: {e}")
                        with self.lock:
                            self.stats['failed'] += 1
            
            end_time = time.time()
            elapsed_time = end_time - start_time
            
            # Update campaign status
            self.campaign.status = CampaignStatus.COMPLETED
            self.campaign.sending_completed_at = crud.func.now()
            self.db.commit()
            
            return {
                'success': True,
                'total_sent': self.stats['sent'],
                'total_failed': self.stats['failed'],
                'elapsed_time': elapsed_time,
                'emails_per_second': self.stats['sent'] / elapsed_time if elapsed_time > 0 else 0
            }
            
        except Exception as e:
            self.campaign.status = CampaignStatus.FAILED
            self.db.commit()
            return {'success': False, 'error': str(e)}
    
    def send_single_email_threaded(self, assignment: RecipientAssignment) -> Dict:
        """
        Send a single email in a thread
        """
        try:
            # Get required data
            recipient = self.db.query(Recipient).filter(Recipient.id == assignment.recipient_id).first()
            user = self.db.query(User).filter(User.id == assignment.user_id).first()
            account = crud.get_account(self.db, user.account_id)
            
            if not all([recipient, user, account]):
                return {'success': False, 'error': 'Missing data'}
            
            # Get credentials and create service
            credentials_dict = crud.get_account_credentials(account)
            service = gmail_service_manager.get_gmail_service(credentials_dict, user.email)
            
            # Create and send message
            message = gmail_service_manager.create_message(
                sender_email=self.campaign.from_email,
                to_email=recipient.email,
                to_name=recipient.name,
                subject=self.campaign.subject,
                html_body=self.campaign.html_body,
                sender_name=self.campaign.from_name,
                custom_headers=self.campaign.custom_headers
            )
            
            # Send email
            result = service.users().messages().send(userId='me', body=message).execute()
            
            # Update database
            crud.update_recipient_status(self.db, recipient.id, RecipientStatus.SENT)
            crud.increment_user_sent_count(self.db, user.id)
            
            return {'success': True, 'message_id': result.get('id')}
            
        except Exception as e:
            # Update recipient as failed
            crud.update_recipient_status(self.db, assignment.recipient_id, RecipientStatus.FAILED, str(e))
            return {'success': False, 'error': str(e)}