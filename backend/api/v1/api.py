from fastapi import APIRouter
from api.v1.endpoints import health, accounts, campaigns, analytics, data_management, testing

api_router = APIRouter()

api_router.include_router(health.router, tags=["health"])
api_router.include_router(accounts.router, prefix="/accounts", tags=["accounts"])
api_router.include_router(campaigns.router, prefix="/campaigns", tags=["campaigns"])
api_router.include_router(analytics.router, tags=["analytics"])
api_router.include_router(data_management.router, tags=["data_management"])
api_router.include_router(testing.router, tags=["testing"])