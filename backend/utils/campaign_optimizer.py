import math
from typing import List, Dict, Tuple
from sqlalchemy.orm import Session
from models import Account, User, Recipient, RecipientAssignment, UserStatus
import crud


class CampaignOptimizer:
    """
    Optimizes campaign sending for maximum speed and deliverability
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def calculate_optimal_distribution(self, recipients: List[Recipient], 
                                     selected_accounts: List[int]) -> Dict:
        """
        Calculate optimal distribution of recipients across users
        for maximum sending speed
        """
        # Get active users from selected accounts
        active_users = []
        for account_id in selected_accounts:
            account = crud.get_account(self.db, account_id)
            if account and account.active:
                users = crud.get_account_users(self.db, account_id)
                active_users.extend([u for u in users if u.status == UserStatus.ACTIVE])
        
        if not active_users:
            raise ValueError("No active users available for sending")
        
        total_recipients = len(recipients)
        total_users = len(active_users)
        
        # Calculate base load per user
        base_load = total_recipients // total_users
        extra_load = total_recipients % total_users
        
        # Create distribution plan
        distribution = {}
        user_assignments = {}
        
        for i, user in enumerate(active_users):
            # Some users get one extra recipient to handle remainder
            user_load = base_load + (1 if i < extra_load else 0)
            
            distribution[user.email] = {
                'user_id': user.id,
                'account_id': user.account_id,
                'assigned_count': user_load,
                'daily_sent': user.daily_sent_count,
                'hourly_sent': user.hourly_sent_count,
                'available_daily': 2000 - user.daily_sent_count,  # Assuming 2000 daily limit
                'available_hourly': 250 - user.hourly_sent_count   # Assuming 250 hourly limit
            }
            
            user_assignments[user.email] = user_load
        
        # Calculate estimated sending time
        # Assuming 25 emails per user can be sent in parallel every 2 seconds
        max_user_load = max(user_assignments.values()) if user_assignments else 0
        estimated_time = (max_user_load / 25) * 2  # seconds
        
        return {
            'total_recipients': total_recipients,
            'total_users': total_users,
            'distribution': distribution,
            'assignments_per_user': user_assignments,
            'estimated_send_time': estimated_time,
            'max_concurrent_batches': min(25, max_user_load),
            'recommended_batch_size': 25
        }
    
    def create_recipient_assignments(self, campaign_id: int, recipients: List[Recipient],
                                   distribution: Dict) -> List[RecipientAssignment]:
        """
        Create optimized recipient assignments based on distribution plan
        """
        assignments = []
        recipient_index = 0
        
        for user_email, user_info in distribution['distribution'].items():
            user_id = user_info['user_id']
            assigned_count = user_info['assigned_count']
            
            # Assign recipients to this user
            for i in range(assigned_count):
                if recipient_index < len(recipients):
                    recipient = recipients[recipient_index]
                    
                    assignment = RecipientAssignment(
                        recipient_id=recipient.id,
                        user_id=user_id,
                        campaign_id=campaign_id,
                        batch_number=i // 25,  # 25 emails per batch
                        priority=i % 25  # Priority within batch
                    )
                    assignments.append(assignment)
                    recipient_index += 1
        
        return assignments
    
    def optimize_sending_order(self, assignments: List[RecipientAssignment]) -> List[RecipientAssignment]:
        """
        Optimize the order of sending for maximum speed
        """
        # Group by user and batch
        user_batches = {}
        
        for assignment in assignments:
            user_id = assignment.user_id
            batch_num = assignment.batch_number
            
            if user_id not in user_batches:
                user_batches[user_id] = {}
            
            if batch_num not in user_batches[user_id]:
                user_batches[user_id][batch_num] = []
            
            user_batches[user_id][batch_num].append(assignment)
        
        # Reorder for optimal sending
        optimized_assignments = []
        max_batches = max(
            max(batches.keys()) if batches else 0 
            for batches in user_batches.values()
        ) + 1 if user_batches else 0
        
        # Process batches in parallel across all users
        for batch_num in range(max_batches):
            for user_id in user_batches:
                if batch_num in user_batches[user_id]:
                    optimized_assignments.extend(user_batches[user_id][batch_num])
        
        return optimized_assignments
    
    def validate_account_capacity(self, selected_accounts: List[int], 
                                recipient_count: int) -> Dict:
        """
        Validate that selected accounts have enough capacity
        """
        total_capacity = 0
        account_details = []
        
        for account_id in selected_accounts:
            account = crud.get_account(self.db, account_id)
            if not account or not account.active:
                continue
            
            users = crud.get_account_users(self.db, account_id)
            active_users = [u for u in users if u.status == UserStatus.ACTIVE]
            
            # Calculate available capacity
            account_capacity = 0
            for user in active_users:
                daily_available = 2000 - user.daily_sent_count
                hourly_available = 250 - user.hourly_sent_count
                user_capacity = min(daily_available, hourly_available)
                account_capacity += max(0, user_capacity)
            
            total_capacity += account_capacity
            account_details.append({
                'account_id': account_id,
                'account_name': account.name,
                'active_users': len(active_users),
                'total_users': len(users),
                'capacity': account_capacity
            })
        
        return {
            'total_capacity': total_capacity,
            'required_capacity': recipient_count,
            'sufficient_capacity': total_capacity >= recipient_count,
            'capacity_utilization': (recipient_count / total_capacity * 100) if total_capacity > 0 else 0,
            'account_details': account_details
        }