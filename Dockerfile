FROM python:3.11-slim

# Prevent Python from writing .pyc files and buffer stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_HOME=/app \
    PORT=8765

WORKDIR $APP_HOME

# Install minimal runtime tools (curl is used by the healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user and give it ownership of the app directory
RUN useradd --create-home --shell /bin/bash studio && \
    chown -R studio:studio $APP_HOME

USER studio

# Install Python dependencies
COPY --chown=studio:studio requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy application source code
COPY --chown=studio:studio src/ ./src/

# Expose the Studio server port
EXPOSE 8765

# Healthcheck for the Studio server
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/api/health || exit 1

# Start the Studio server
CMD ["python", "-m", "src.server"]
