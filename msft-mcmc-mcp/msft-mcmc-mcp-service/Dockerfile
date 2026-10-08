FROM python:3.12-slim-bookworm

ENV PATH="/app/.venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_SYSTEM_CERTS=true

WORKDIR /app

RUN useradd --create-home --uid 10001 app

COPY pyproject.toml uv.lock ./
RUN pip install --no-cache-dir uv==0.12.16 \
    && uv sync --frozen --no-dev --no-install-project

COPY src ./src
RUN uv sync --frozen --no-dev

COPY container_app.py ./

USER app
EXPOSE 8000

CMD ["uvicorn", "container_app:app", "--host", "0.0.0.0", "--port", "8000"]
