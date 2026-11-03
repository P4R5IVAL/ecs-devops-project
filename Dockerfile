FROM python:3.14-slim AS builder

WORKDIR /app

RUN python -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.14-slim AS runtime

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

COPY app.py .

RUN useradd --create-home appuser

USER appuser

EXPOSE 8080

CMD ["waitress-serve", "--listen=0.0.0.0:8080", "app:app"]