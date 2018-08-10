FROM alpine:latest

WORKDIR /app

RUN apk update && apk add \
    py2-pip

COPY requirements.txt ./
COPY cassh ./cassh

RUN pip install --no-cache-dir -r requirements.txt

ENTRYPOINT ["python", "/app/cassh"]

CMD ["--help"]

