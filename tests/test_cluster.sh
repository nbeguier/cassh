#!/bin/bash
# shellcheck disable=SC2128

RESP=$(curl -s -X GET "${CASSH_SERVER_URL}"/cluster/status)
if [[ "${RESP}" == *"OK"* ]]; then
    echo "[OK] Test cluster status"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test cluster status : ${RESP}"
fi
