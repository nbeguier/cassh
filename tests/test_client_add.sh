#!/bin/bash

RESP=$(curl -s -X PUT "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No username option given.' ]; then
    echo "[OK] Test add user without username"
else
    echo "[FAIL] Test add user without username : ${RESP}"
fi

RESP=$(curl -s -X PUT -d 'username=test_user' "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: invalid username." ]; then
    echo "[OK] Test add user with bad username"
else
    echo "[FAIL] Test add user with bad username : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER2}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No realname option given.' ]; then
    echo "[OK] Test add user without realname"
else
    echo "[FAIL] Test add user without realname : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER2}&realname=test.${USER1}@domain.fr" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No pubkey given.' ]; then
    echo "[OK] Test add user with no pubkey"
else
    echo "[FAIL] Test add user with no pubkey : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER2}&realname=test.${USER1}@domain.fr&pubkey=bad_pubkey" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : Public key unprocessable' ]; then
    echo "[OK] Test add user with bad pubkey"
else
    echo "[FAIL] Test add user with bad pubkey : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER2}&realname=${BADTEXT}&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: invalid realname." ]; then
    echo "[OK] Test add user with bad realname"
else
    echo "[FAIL] Test add user with bad realname : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER2}&realname=test.${USER1}@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Create user=${USER2}. Pending request." ]; then
    echo "[OK] Test add user ${USER2}"
else
    echo "[FAIL] Test add user ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER3}&realname=test.${USER3}@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Create user=${USER3}. Pending request." ]; then
    echo "[OK] Test add user ${USER3}"
else
    echo "[FAIL] Test add user ${USER3}: ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=all&realname=test.${USER1}@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: username not valid." ]; then
    echo "[OK] Test add user named 'all'"
else
    echo "[FAIL] Test add user named 'all' : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${BADTEXT}&realname=test.${USER1}@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: invalid username." ]; then
    echo "[OK] Test add bad username"
else
    echo "[FAIL] Test add bad username : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=test.${USER1}@domain.fr" "${CASSH_SERVER_URL}"/client/status | jq .status)
if [ "${RESP}" == '"PENDING"' ]; then
    echo "[OK] Test status pending user"
else
    echo "[FAIL] Test status pending user : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER1}&realname=test.${USER1}@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Create user=${USER1}. Pending request." ]; then
    echo "[OK] Test add user with same realname (which is possible)"
else
    echo "[FAIL] Test add user with same realname (which is possible): ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER1}&realname=test.${USER1}@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Update user=${USER1}. Pending request." ]; then
    echo "[OK] Test updating user"
else
    echo "[FAIL] Test updating user: ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER2}&realname=${USER2}@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : (username, realname) couple mismatch.' ]; then
    echo "[OK] Test add user with same username (should fail)"
else
    echo "[FAIL] Test add user with same username (should fail): ${RESP}"
fi
