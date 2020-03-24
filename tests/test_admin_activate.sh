#!/bin/bash

RESP=$(curl -s -X POST -d 'revoke=true' "${CASSH_SERVER_URL}"/admin/"${USER1}")
if [ "${RESP}" == "Revoke user=${USER1}." ]; then
    echo "[OK] Test admin revoke '${USER1}'"
else
    echo "[FAIL] Test admin revoke '${USER1}' : ${RESP}"
fi

RESP=$(curl -s -X POST -d 'status=true' "${CASSH_SERVER_URL}"/admin/"${USER1}" | jq .status)
if [ "${RESP}" == '"REVOKED"' ]; then
    echo "[OK] Test admin verify '${USER1}' status"
else
    echo "[FAIL] Test admin verify '${USER1}' status : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER1}&realname=test.${USER1}@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Status: REVOKED' ]; then
    echo "[OK] Test signing key when revoked"
else
    echo "[FAIL] Test signing key when revoked: ${RESP}"
fi

RESP=$(curl -s -X DELETE "${CASSH_SERVER_URL}"/admin/"${USER1}")
if [ "${RESP}" == 'OK' ]; then
    echo "[OK] Test delete '${USER1}'"
else
    echo "[FAIL] Test delete '${USER1}': ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER1}")
if [ "${RESP}" == "User does not exists." ]; then
    echo "[OK] Test admin active unknown user"
else
    echo "[FAIL] Test admin active unknown user : ${RESP}"
fi

RESP=$(curl -s -X POST -d 'status=true' "${CASSH_SERVER_URL}"/admin/"${USER2}" | jq .status)
if [ "${RESP}" == '"PENDING"' ]; then
    echo "[OK] Test admin verify '${USER2}' status"
else
    echo "[FAIL] Test admin verify '${USER2}' status : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}")
if [ "${RESP}" == "Active user=${USER2}. SSH Key active but need to be signed." ]; then
    echo "[OK] Test admin active ${USER2}"
else
    echo "[FAIL] Test admin active ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}")
if [ "${RESP}" == "user=${USER2} already active. Nothing done." ]; then
    echo "[OK] Test admin re-active ${USER2}"
else
    echo "[FAIL] Test admin re-active ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER3}")
if [ "${RESP}" == "Active user=${USER3}. SSH Key active but need to be signed." ]; then
    echo "[OK] Test admin active ${USER3}"
else
    echo "[FAIL] Test admin active ${USER3} : ${RESP}"
fi
