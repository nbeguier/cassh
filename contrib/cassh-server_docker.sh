#!/usr/bin/env bash

docker run --rm \
  --volume=/etc/cassh-server/cassh.conf:/opt/cassh/server/conf/cassh.conf \
  --volume=${CASSH_KEYS_DIR}:${CASSH_KEYS_DIR} \
  --publish "8080:8080"
  leboncoin/cassh-sever
