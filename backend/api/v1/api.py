from fastapi import APIRouter
from api.v1.endpoints import health, accounts, campaigns, analytics, data_management, testing

api_router = APIRouter()

# Include all routers with proper prefixes
api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(accounts.router, prefix="/accounts", tags=["accounts"]) 
api_router.include_router(campaigns.router, prefix="/campaigns", tags=["campaigns"])
api_router.include_router(analytics.router, prefix="", tags=["analytics"])  # Analytics routes have their own paths
api_router.include_router(data_management.router, prefix="", tags=["data_management"])  # Data mgmt routes have their own paths
api_router.include_router(testing.router, prefix="", tags=["testing"])  # Testing routes have their own paths