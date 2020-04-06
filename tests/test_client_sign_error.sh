#!/bin/bash
# shellcheck disable=SC2128

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No realname option given.' ]; then
    echo "[OK] Test signing key without username,realname,password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key without username,realname,password: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${GUEST_A_REALNAME}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No password option given.' ]; then
    echo "[OK] Test signing key without username,password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key without username,password: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No username option given.' ]; then
    echo "[OK] Test signing key without username"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key without username: ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_A_USERNAME}&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No pubkey given.' ]; then
    echo "[OK] Test signing key with no pubkey"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key with no pubkey : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_A_USERNAME}&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}&pubkey=bad_pubkey" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : Public key unprocessable' ]; then
    echo "[OK] Test signing key with bad pubkey"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key with bad pubkey : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_A_USERNAME}&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}&pubkey=${GUEST_B_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : User or Key absent, add your key again.' ]; then
    echo "[OK] Test signing key when wrong public key"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key when wrong public key : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_A_USERNAME}&realname=${GUEST_A_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_A_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: {'desc': 'Invalid credentials'}" ]; then
    echo "[OK] Test signing key with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key when PENDING status : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_A_USERNAME}&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}&pubkey=${GUEST_A_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Status: PENDING" ]; then
    echo "[OK] Test signing key when PENDING status"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key when PENDING status : ${RESP}"
fi
