#!/bin/bash

RESP=$(curl -s -X DELETE "${CASSH_SERVER_URL}"/admin/"${USER2}")
if [ "${RESP}" == 'OK' ]; then
    echo "[OK] Test delete '${USER2}'"
else
    echo "[FAIL] Test delete '${USER2}': ${RESP}"
fi
