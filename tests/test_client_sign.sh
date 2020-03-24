#!/bin/bash

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No username option given. Update your CASSH >= 1.3.0' ]; then
    echo "[OK] Test signing key without username"
else
    echo "[FAIL] Test signing key without username: ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER2}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No realname option given.' ]; then
    echo "[OK] Test signing key without realname"
else
    echo "[FAIL] Test signing key without realname: ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER2}&realname=test.${USER1}@domain.fr" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No pubkey given.' ]; then
    echo "[OK] Test signing key with no pubkey"
else
    echo "[FAIL] Test signing key with no pubkey : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER2}&realname=test.${USER1}@domain.fr&pubkey=bad_pubkey" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : Public key unprocessable' ]; then
    echo "[OK] Test signing key with bad pubkey"
else
    echo "[FAIL] Test signing key with bad pubkey : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER2}&realname=test.${USER1}@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : User or Key absent, add your key again.' ]; then
    echo "[OK] Test signing key when wrong public key"
else
    echo "[FAIL] Test signing key when wrong public key : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER2}&realname=test.${USER1}@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Status: PENDING' ]; then
    echo "[OK] Test signing key when PENDING status"
else
    echo "[FAIL] Test signing key when PENDING status : ${RESP}"
fi
