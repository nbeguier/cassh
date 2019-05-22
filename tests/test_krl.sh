#!/bin/bash

CASSH_SERVER_URL=${1:-http://localhost:8080}
CASSH_SERVER_2_URL=${2:-http://localhost:8081}

KEY_1_EXAMPLE=/tmp/.id_rsa
KEY_2_EXAMPLE=/tmp/.id_ecdsa
USER1=$(pwgen -A -0 10)
USER2=$(pwgen -A -0 10)

# Generate random keys
echo -e 'y\n' | ssh-keygen -t rsa -b 4096 -o -a 100 -f "${KEY_1_EXAMPLE}" -q -N "" >/dev/null 2>&1
echo -e 'y\n' | ssh-keygen -t ecdsa -b 521 -f "${KEY_2_EXAMPLE}" -q -N "" >/dev/null 2>&1

PUB_KEY_1_EXAMPLE=$(cat "${KEY_1_EXAMPLE}".pub)
PUB_KEY_2_EXAMPLE=$(cat "${KEY_2_EXAMPLE}".pub)

# Get the latest krl
curl -s "${CASSH_SERVER_URL}"/krl -o /tmp/.revoked-keys

# Check if USER1 or USER2 is revoked
RESP_1=$(ssh-keygen -Q -f /tmp/.revoked-keys "${KEY_1_EXAMPLE}".pub | awk '{print $NF}')
if [ "${RESP_1}" == 'ok' ]; then
    echo "[OK] Test krl for non-revoked key"
else
    echo "[FAIL] Test krl for non-revoked key : ${RESP_1}"
fi
RESP_2=$(ssh-keygen -Q -f /tmp/.revoked-keys "${KEY_2_EXAMPLE}".pub | awk '{print $NF}')
if [ "${RESP_2}" == 'ok' ]; then
    echo "[OK] Test krl for non-revoked key"
else
    echo "[FAIL] Test krl for non-revoked key : ${RESP_2}"
fi


# Create USER1
RESP=$(curl -s -X PUT -d "username=${USER1}&realname=${USER1}@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Create user=${USER1}. Pending request." ]; then
    echo "[OK] Test add user ${USER1}"
else
    echo "[FAIL] Test add user ${USER1}: ${RESP}"
fi


# Revoke USER1
RESP=$(curl -s -X POST -d 'revoke=true' "${CASSH_SERVER_URL}"/admin/"${USER1}")
if [ "${RESP}" == "Revoke user=${USER1}." ]; then
    echo "[OK] Test admin revoke '${USER1}'"
else
    echo "[FAIL] Test admin revoke '${USER1}' : ${RESP}"
fi

# Check if USER1 is revoked on the second server
RESP=$(curl -s -X POST -d 'status=true' "${CASSH_SERVER_2_URL}"/admin/"${USER1}" | jq .status)
if [ "${RESP}" == '"REVOKED"' ]; then
    echo "[OK] Test admin verify ${USER1} status is revoked on the server ${CASSH_SERVER_2_URL}"
else
    echo "[FAIL] Test admin verify ${USER1} status is revoked on the server ${CASSH_SERVER_2_URL}: ${RESP}"
fi


# Get the latest krl
curl -s "${CASSH_SERVER_URL}"/krl -o /tmp/.revoked-keys

# First user should be in the krl
RESP_1=$(ssh-keygen -Q -f /tmp/.revoked-keys "${KEY_1_EXAMPLE}".pub | awk '{print $NF}')
if [ "${RESP_1}" == 'ok' ]; then
    echo "[FAIL] Test krl for revoked key"
else
    echo "[OK] Test krl for revoked key : ${RESP_1}"
fi
RESP_2=$(ssh-keygen -Q -f /tmp/.revoked-keys "${KEY_2_EXAMPLE}".pub | awk '{print $NF}')
if [ "${RESP_2}" == 'ok' ]; then
    echo "[OK] Test krl for non-revoked key"
else
    echo "[FAIL] Test krl for non-revoked key : ${RESP_2}"
fi



# Get the latest krl on the second server
curl -s "${CASSH_SERVER_2_URL}"/krl -o /tmp/.revoked-keys

# First user should be in the krl
RESP_1=$(ssh-keygen -Q -f /tmp/.revoked-keys "${KEY_1_EXAMPLE}".pub | awk '{print $NF}')
if [ "${RESP_1}" == 'ok' ]; then
    echo "[FAIL] Test krl for revoked key on the server ${CASSH_SERVER_2_URL}"
else
    echo "[OK] Test krl for revoked key on the server ${CASSH_SERVER_2_URL}: ${RESP_1}"
fi
RESP_2=$(ssh-keygen -Q -f /tmp/.revoked-keys "${KEY_2_EXAMPLE}".pub | awk '{print $NF}')
if [ "${RESP_2}" == 'ok' ]; then
    echo "[OK] Test krl for non-revoked key on the server ${CASSH_SERVER_2_URL}"
else
    echo "[FAIL] Test krl for non-revoked key on the server ${CASSH_SERVER_2_URL}: ${RESP_2}"
fi

