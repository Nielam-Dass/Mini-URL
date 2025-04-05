FROM python:3.11-alpine3.21

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONBUFFERED=1

RUN adduser \
    --disabled-password \
    --gecos "" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "1001" \
    appuser

USER appuser

WORKDIR /app

COPY requirements.txt requirements.txt

USER root

RUN \
    apk add --no-cache postgresql-libs && \
    apk add --no-cache --virtual .build-deps postgresql-dev && \
    pip3 install -r requirements.txt --no-cache-dir && \
    apk del --purge .build-deps

USER appuser

COPY mini_url/ mini_url/

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "mini_url.app:app"]
