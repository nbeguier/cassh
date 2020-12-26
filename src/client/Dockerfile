FROM alpine:latest

# Container options (For layer optim)
WORKDIR /app
ENTRYPOINT ["python3", "/app/cassh"]
CMD ["--help"]

# Install dependencies
RUN apk update \
    && apk add \
        py3-pip

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Include code
COPY cassh ./cassh
