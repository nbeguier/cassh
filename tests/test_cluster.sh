#!/bin/bash

RESP=$(curl -s -X GET "${CASSH_SERVER_URL}"/cluster/status)
if [[ "${RESP}" == *"OK"* ]]; then
    echo "[OK] Test cluster status"
else
    echo "[FAIL] Test cluster status : ${RESP}"
fi
