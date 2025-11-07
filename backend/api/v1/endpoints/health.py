from fastapi import APIRouter
import schemas

router = APIRouter()


@router.get("/health", response_model=schemas.HealthCheck)
def health_check():
    """Health check endpoint"""
    return schemas.HealthCheck(
        status="healthy",
        message="Speed-Send API is running"
    )