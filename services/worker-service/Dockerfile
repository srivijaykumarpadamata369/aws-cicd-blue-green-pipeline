# Multi-stage build keeps the final image small — matters for ECR storage
# costs (free tier: 500MB/month) and faster ECS task startup.

FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim
WORKDIR /app

# Run as non-root — a real security control, and something a
# hiring manager will specifically check for in a Dockerfile.
RUN useradd --create-home --shell /bin/bash appuser
COPY --from=builder /root/.local /home/appuser/.local
COPY . .
RUN chown -R appuser:appuser /app

USER appuser
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
