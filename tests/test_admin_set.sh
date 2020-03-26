#!/bin/bash

RESP=$(curl -s -X PATCH "${CASSH_SERVER_URL}"/admin/"${USER2}" -d "expiry=+3d")
if [ "${RESP}" == "OK: expiry=+3d for ${USER2}" ]; then
    echo "[OK] Test set expiry to 3 days for ${USER2}"
else
    echo "[FAIL] Test set expiry to 3 days for ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X PATCH "${CASSH_SERVER_URL}"/admin/"${USER2}" -d "expiry=3d")
if [ "${RESP}" == "Error: invalid expiry." ]; then
    echo "[OK] Test set wrong expiry for ${USER2}"
else
    echo "[FAIL] Test set wrong expiry for ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER2}&realname=test.${USER1}@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
echo "${RESP}" > /tmp/test-cert
if ssh-keygen -L -f /tmp/test-cert >/dev/null 2>&1; then
    echo "[OK] Test signing key when changing expiry"
else
    echo "[FAIL] Test signing key when changing expiry : ${RESP}"
fi
rm -f /tmp/test-cert
