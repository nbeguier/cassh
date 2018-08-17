FROM nbeguier/cassh-client

WORKDIR /code
ENTRYPOINT ["/bin/sh", "-c"]
RUN pip install --upgrade pip \
    && pip install --no-cache-dir pylint