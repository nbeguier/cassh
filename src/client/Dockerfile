FROM alpine:latest

# Container options (For layer optim)
WORKDIR /app
ENTRYPOINT ["python", "/app/cassh"]
CMD ["--help"]

# Install dependencies
RUN apk update \
    && apk add \
        py2-pip

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Include code
COPY cassh ./cassh