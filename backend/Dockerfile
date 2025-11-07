# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry with specific version
RUN pip install --no-cache-dir poetry==1.6.1

# Copy dependency files
COPY pyproject.toml requirements.txt ./

# Try Poetry first, fallback to pip if it fails
RUN poetry config virtualenvs.create false && \
    poetry config virtualenvs.in-project false && \
    (poetry install --only=main --no-interaction --no-ansi --no-cache || \
     pip install --no-cache-dir -r requirements.txt)

# Copy application code
COPY . /app/

# Create uploads directory
RUN mkdir -p /app/uploads

# Expose port
EXPOSE 8000

# Default command (can be overridden in docker-compose)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]