FROM leboncoin/cassh-server

WORKDIR /code
ENTRYPOINT ["/bin/bash", "-c"]
SHELL ["/bin/bash", "-c"]

RUN echo "* Install OS dependencies" \
    && apt-get update \
    && apt-get install -qqy python-pip \
    && echo "* Install Python dependencies" \
    && pip install --no-cache-dir pylint \
    && echo "* Clean OS" \
    && apt-get clean -qqy \
    && rm -rf /var/lib/apt
