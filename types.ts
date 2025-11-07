

export enum CampaignStatus {
  DRAFT = 'Draft',
  PREPARING = 'Preparing',
  READY = 'Ready',
  SENDING = 'Sending',
  PAUSED = 'Paused',
  COMPLETED = 'Completed',
  FAILED = 'Failed',
}

export enum RecipientStatus {
  PENDING = 'Pending',
  ASSIGNED = 'Assigned',
  SENDING = 'Sending',
  SENT = 'Sent',
  FAILED = 'Failed',
}

export enum UserStatus {
  ACTIVE = 'Active',
  INACTIVE = 'Inactive',
  RATE_LIMITED = 'Rate Limited',
  ERROR = 'Error',
}

export interface User {
  id: number;
  email: string;
  name: string;
  status: UserStatus;
  daily_sent_count: number;
  hourly_sent_count: number;
  last_sent_at?: string;
  last_error?: string;
}

export interface Account {
  id: number;
  name: string;
  admin_email: string;
  active: boolean;
  user_count: number;
  daily_quota: number;
  hourly_quota: number;
  created_at: string;
  last_sync_at?: string;
}

export interface AccountWithUsers extends Account {
  users: User[];
}

export interface Recipient {
  id: number;
  email: string;
  name: string;
  status: RecipientStatus;
  last_error?: string; // Changed to match backend snake_case
}

export interface CampaignStats {
    total: number;
    sent: number;
    pending: number;
    assigned: number;
    sending: number;
    failed: number;
}

export interface Campaign {
  id: number;
  name: string;
  from_name: string;
  from_email: string;
  subject: string;
  status: CampaignStatus;
  custom_headers?: Record<string, string>;
  test_email?: string;
  selected_accounts?: number[];
  send_rate_per_minute: number;
  preparation_started_at?: string;
  preparation_completed_at?: string;
  sending_started_at?: string;
  sending_completed_at?: string;
  created_at: string;
  stats: CampaignStats;
}

export interface CampaignDetail extends Campaign {
    html_body: string; // Changed to match backend snake_case
    recipients: Recipient[];
}

export interface CampaignCreatePayload {
    name: string;
    from_name: string;
    from_email: string;
    subject: string;
    html_body: string;
    recipients_csv: string;
    custom_headers?: Record<string, string>;
    test_email?: string;
    selected_accounts?: number[];
    send_rate_per_minute?: number;
}

export interface CampaignPreparation {
    campaign_id: number;
    selected_accounts: number[];
    total_recipients: number;
    total_users: number;
    assignments_per_user: Record<string, number>;
    estimated_send_time: number;
}

export interface SendingProgress {
    campaign_id: number;
    total_emails: number;
    sent_emails: number;
    failed_emails: number;
    sending_emails: number;
    progress_percentage: number;
    estimated_completion_time?: string;
    current_send_rate: number;
    errors: string[];
}

export interface AccountValidation {
    name: string;
    admin_email: string;
    credentials_json: string;
}

export interface AccountValidationResult {
    valid: boolean;
    email?: string;
    messages_total?: number;
    threads_total?: number;
    user_count?: number;
    error?: string;
}