from fastapi import APIRouter
from api.v1.endpoints import health, accounts, campaigns

api_router = APIRouter()

# Include routers WITHOUT extra prefixes (routes already have correct paths)
api_router.include_router(health.router, tags=["health"])
api_router.include_router(accounts.router, tags=["accounts"]) 
api_router.include_router(campaigns.router, tags=["campaigns"])