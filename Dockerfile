FROM python:3.11-alpine3.21

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONBUFFERED=1

WORKDIR /app

COPY requirements.txt requirements.txt

RUN \
    apk add --no-cache postgresql-libs && \
    apk add --no-cache --virtual .build-deps postgresql-dev && \
    pip3 install -r requirements.txt --no-cache-dir && \
    apk del --purge .build-deps

COPY . .

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
