FROM python:3.12-slim

WORKDIR /srv/althea

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY pyproject.toml README.md /srv/althea/
RUN pip install --no-cache-dir .

COPY app /srv/althea/app

EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
