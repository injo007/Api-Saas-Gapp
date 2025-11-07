import os
from typing import Optional
try:
    from pydantic_settings import BaseSettings
except ImportError:
    from pydantic import BaseSettings


class Settings(BaseSettings):
    # Database
    database_url: str = os.getenv("DATABASE_URL", "postgresql://speedsend_user:password@localhost:5432/speedsend_db")
    
    # Redis
    redis_url: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    
    # Security
    secret_key: str = os.getenv("SECRET_KEY", "your_secret_key_here")
    encryption_key: str = os.getenv("ENCRYPTION_KEY", "your_encryption_key_here")
    
    # Gmail API
    gmail_rate_limit_per_hour: int = int(os.getenv("GMAIL_RATE_LIMIT_PER_HOUR", "1800"))
    
    # Celery
    celery_worker_concurrency: int = int(os.getenv("CELERY_WORKER_CONCURRENCY", "50"))
    celery_task_timeout: int = int(os.getenv("CELERY_TASK_TIMEOUT", "300"))
    
    # Application
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"
    environment: str = os.getenv("ENVIRONMENT", "development")
    
    # Upload directory
    upload_dir: str = "uploads"
    
    class Config:
        case_sensitive = False


settings = Settings()