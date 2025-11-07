import asyncio
import aiohttp
import json
from typing import List, Dict, Optional
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import base64
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from concurrent.futures import ThreadPoolExecutor
import time

from core.config import settings
from utils.encryption import decrypt_data


class GmailServiceManager:
    def __init__(self):
        self.services = {}  # Cache for Gmail services
        self.executor = ThreadPoolExecutor(max_workers=100)  # For concurrent API calls
    
    def get_gmail_service(self, credentials_dict: dict, user_email: str):
        """Create or get cached Gmail service for a user"""
        cache_key = f"{user_email}"
        
        if cache_key not in self.services:
            credentials = Credentials.from_service_account_info(
                credentials_dict,
                scopes=['https://www.googleapis.com/auth/gmail.send']
            )
            
            # Delegate to the user email
            delegated_credentials = credentials.with_subject(user_email)
            service = build('gmail', 'v1', credentials=delegated_credentials, cache_discovery=False)
            self.services[cache_key] = service
        
        return self.services[cache_key]
    
    def create_message(self, sender_email: str, to_email: str, to_name: str, 
                      subject: str, html_body: str, sender_name: str = None, 
                      custom_headers: Dict = None):
        """Create a message for an email with optimized headers"""
        message = MIMEMultipart('alternative')
        message['to'] = f"{to_name} <{to_email}>"
        message['from'] = f"{sender_name} <{sender_email}>" if sender_name else sender_email
        message['subject'] = subject
        
        # Add custom headers for better deliverability
        if custom_headers:
            for key, value in custom_headers.items():
                message[key] = value
        
        # Default headers for better deliverability
        message['Reply-To'] = sender_email
        message['Return-Path'] = sender_email
        message['List-Unsubscribe'] = f"<mailto:{sender_email}?subject=unsubscribe>"
        
        # Personalize content
        personalized_html = html_body.replace("{{name}}", to_name).replace("{{email}}", to_email)
        
        # Create HTML part
        html_part = MIMEText(personalized_html, 'html')
        message.attach(html_part)

        # Encode message
        raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode()
        return {'raw': raw_message}
    
    async def send_email_async(self, service, message_data: dict, user_email: str):
        """Send email asynchronously"""
        loop = asyncio.get_event_loop()
        
        def send_email_sync():
            try:
                result = service.users().messages().send(userId='me', body=message_data).execute()
                return {'success': True, 'message_id': result.get('id'), 'user_email': user_email}
            except HttpError as error:
                return {'success': False, 'error': str(error), 'user_email': user_email, 'retry': error.resp.status in [429, 500, 502, 503, 504]}
            except Exception as error:
                return {'success': False, 'error': str(error), 'user_email': user_email, 'retry': False}
        
        return await loop.run_in_executor(self.executor, send_email_sync)
    
    async def send_batch_emails(self, batch_data: List[Dict], credentials_dict: dict, 
                               custom_headers: Dict = None, max_concurrent: int = 50):
        """Send multiple emails concurrently with rate limiting"""
        semaphore = asyncio.Semaphore(max_concurrent)
        
        async def send_single_email(email_data):
            async with semaphore:
                service = self.get_gmail_service(credentials_dict, email_data['user_email'])
                message = self.create_message(
                    sender_email=email_data['from_email'],
                    to_email=email_data['to_email'],
                    to_name=email_data['to_name'],
                    subject=email_data['subject'],
                    html_body=email_data['html_body'],
                    sender_name=email_data['from_name'],
                    custom_headers=custom_headers
                )
                
                result = await self.send_email_async(service, message, email_data['user_email'])
                result['recipient_id'] = email_data['recipient_id']
                return result
        
        # Create tasks for all emails
        tasks = [send_single_email(email_data) for email_data in batch_data]
        
        # Send emails in batches to avoid overwhelming the API
        results = []
        batch_size = 25  # Process 25 emails at a time
        
        for i in range(0, len(tasks), batch_size):
            batch_tasks = tasks[i:i + batch_size]
            batch_results = await asyncio.gather(*batch_tasks, return_exceptions=True)
            results.extend(batch_results)
            
            # Small delay between batches to respect rate limits
            if i + batch_size < len(tasks):
                await asyncio.sleep(0.1)  # 100ms delay
        
        return results


# Global instance
gmail_service_manager = GmailServiceManager()


async def get_workspace_users(credentials_dict: dict, admin_email: str) -> List[Dict]:
    """Get all users from Google Workspace using Directory API"""
    try:
        credentials = Credentials.from_service_account_info(
            credentials_dict,
            scopes=['https://www.googleapis.com/auth/admin.directory.user.readonly']
        )
        
        # Delegate to the admin email
        delegated_credentials = credentials.with_subject(admin_email)
        service = build('admin', 'directory_v1', credentials=delegated_credentials, cache_discovery=False)
        
        users = []
        page_token = None
        
        while True:
            request = service.users().list(
                domain=admin_email.split('@')[1],
                maxResults=500,
                pageToken=page_token
            )
            
            response = request.execute()
            
            for user in response.get('users', []):
                if user.get('suspended', False) or not user.get('primaryEmail'):
                    continue
                    
                users.append({
                    'email': user['primaryEmail'],
                    'name': user.get('name', {}).get('fullName', user['primaryEmail']),
                    'suspended': user.get('suspended', False)
                })
            
            page_token = response.get('nextPageToken')
            if not page_token:
                break
        
        return users
        
    except Exception as error:
        print(f"Error fetching workspace users: {error}")
        return []


def validate_gmail_credentials(credentials_dict: dict, admin_email: str) -> Dict:
    """Validate Gmail credentials and return account info"""
    try:
        # Test Gmail API access
        credentials = Credentials.from_service_account_info(
            credentials_dict,
            scopes=['https://www.googleapis.com/auth/gmail.send']
        )
        
        delegated_credentials = credentials.with_subject(admin_email)
        service = build('gmail', 'v1', credentials=delegated_credentials, cache_discovery=False)
        
        # Test sending capability by getting profile
        profile = service.users().getProfile(userId='me').execute()
        
        return {
            'valid': True,
            'email': profile.get('emailAddress'),
            'messages_total': profile.get('messagesTotal', 0),
            'threads_total': profile.get('threadsTotal', 0)
        }
        
    except Exception as error:
        return {
            'valid': False,
            'error': str(error)
        }