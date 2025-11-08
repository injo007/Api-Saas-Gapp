from fastapi import APIRouter
from api.v1.endpoints import health, accounts, campaigns

api_router = APIRouter()

# Include ONLY working routers (those that actually exist)
api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(accounts.router, prefix="/accounts", tags=["accounts"]) 
api_router.include_router(campaigns.router, prefix="/campaigns", tags=["campaigns"])