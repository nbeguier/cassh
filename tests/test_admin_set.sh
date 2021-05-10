#!/bin/bash
# shellcheck disable=SC2128

RESP=$(curl -s -X PATCH "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}" -d "expiry=3d")
if [ "${RESP}" == "Error: No realname option given." ]; then
    echo "[OK] Test set expiry without realname,password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test set expiry without realname,password: ${RESP}"
fi

RESP=$(curl -s -X PATCH -d "realname=${SYSADMIN_REALNAME}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}" -d "expiry=3d")
if [ "${RESP}" == "Error: No password option given." ]; then
    echo "[OK] Test set expiry without password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test set expiry without password: ${RESP}"
fi

RESP=$(curl -s -X PATCH -d "realname=${SYSADMIN_REALNAME}&password=${GUEST_B_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}" -d "expiry=3d")
if [ "${RESP}" == "Error: {'desc': 'Invalid credentials'}" ]; then
    echo "[OK] Test set expiry with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test set expiry with invalid credentials: ${RESP}"
fi

RESP=$(curl -s -X PATCH -d "realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}" -d "expiry=3d")
if [ "${RESP}" == "Error: Not authorized." ]; then
    echo "[OK] Test set expiry with unauthorized user"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test set expiry with unauthorized user: ${RESP}"
fi

RESP=$(curl -s -X PATCH -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}" -d "expiry=+3d")
if [ "${RESP}" == "Error: invalid expiry." ]; then
    echo "[OK] Test set wrong expiry for ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test set wrong expiry for ${GUEST_B_USERNAME} : ${RESP}"
fi

##############################
## ADMIN SET GUEST B EXPIRY ##
##############################
RESP=$(curl -s -X PATCH -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}" -d "expiry=3d")
if [ "${RESP}" == "OK: expiry=3d for ${GUEST_B_USERNAME}" ]; then
    echo "[OK] Test set expiry to 3 days for ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test set expiry to 3 days for ${GUEST_B_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_B_USERNAME}&realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_B_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
echo "${RESP}" > /tmp/test-cert
if ssh-keygen -L -f /tmp/test-cert >/dev/null 2>&1; then
    echo "[OK] Test signing key when changing expiry"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key when changing expiry : ${RESP}"
fi
rm -f /tmp/test-cert
