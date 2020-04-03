#!/bin/bash
# shellcheck disable=SC2128

RESP=$(curl -s -X PUT "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No realname option given.' ]; then
    echo "[OK] Test add user without username,realname,password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user without username,realname,password : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "realname=${GUEST_A_REALNAME}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No password option given.' ]; then
    echo "[OK] Test add user without username,password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user without username,password : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No username option given.' ]; then
    echo "[OK] Test add user without username"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user without username : ${RESP}"
fi

RESP=$(curl -s -X PUT -d 'username=test_user' "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: invalid username." ]; then
    echo "[OK] Test add user with bad username"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user with bad username : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${GUEST_A_USERNAME}&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No pubkey given.' ]; then
    echo "[OK] Test add user with no pubkey"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user with no pubkey : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${GUEST_A_USERNAME}&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}&pubkey=bad_pubkey" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : Public key unprocessable' ]; then
    echo "[OK] Test add user with bad pubkey"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user with bad pubkey : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${GUEST_A_USERNAME}&realname=${BADTEXT}&pubkey=${GUEST_A_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: invalid realname." ]; then
    echo "[OK] Test add user with bad realname"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user with bad realname : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${GUEST_A_USERNAME}&realname=${GUEST_A_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_A_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: {'desc': 'Invalid credentials'}" ]; then
    echo "[OK] Test add user with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user with invalid credentials : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=all&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}&pubkey=${GUEST_A_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: username not valid." ]; then
    echo "[OK] Test add user named 'all'"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user named 'all' : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${BADTEXT}&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}&pubkey=${GUEST_A_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: invalid username." ]; then
    echo "[OK] Test add bad username"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add bad username : ${RESP}"
fi

#################
## ADD GUEST A ##
#################
RESP=$(curl -s -X PUT -d "username=${GUEST_A_USERNAME}&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}&pubkey=${GUEST_A_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Create user=${GUEST_A_USERNAME}. Pending request." ]; then
    echo "[OK] Test add user ${GUEST_A_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user ${GUEST_A_USERNAME} : ${RESP}"
fi

#################
## ADD GUEST B ##
#################
RESP=$(curl -s -X PUT -d "username=${GUEST_B_USERNAME}&realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_B_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Create user=${GUEST_B_USERNAME}. Pending request." ]; then
    echo "[OK] Test add user ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user ${GUEST_B_USERNAME}: ${RESP}"
fi

#################
## ADD GUEST C ##
#################
RESP=$(curl -s -X PUT -d "username=${GUEST_C_USERNAME}&realname=${GUEST_C_REALNAME}&password=${GUEST_C_PASSWORD}&pubkey=${GUEST_C_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Create user=${GUEST_C_USERNAME}. Pending request." ]; then
    echo "[OK] Test add user with same realname (which is possible)"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user with same realname (which is possible): ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${GUEST_A_REALNAME}&password=${GUEST_B_PASSWORD}" "${CASSH_SERVER_URL}"/client/status)
if [ "${RESP}" == "Error: {'desc': 'Invalid credentials'}" ]; then
    echo "[OK] Test status with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test status with invalid credentials : ${RESP}"
fi

####################
## STATUS GUEST A ##
####################
RESP=$(curl -s -X POST -d "realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}" "${CASSH_SERVER_URL}"/client/status | jq .status)
if [ "${RESP}" == '"PENDING"' ]; then
    echo "[OK] Test status pending user"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test status pending user : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${GUEST_C_USERNAME}&realname=${GUEST_C_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_B_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: {'desc': 'Invalid credentials'}" ]; then
    echo "[OK] Test updating user with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test updating user with invalid credentials: ${RESP}"
fi

####################
## UPDATE GUEST C ##
####################
RESP=$(curl -s -X PUT -d "username=${GUEST_C_USERNAME}&realname=${GUEST_C_REALNAME}&password=${GUEST_C_PASSWORD}&pubkey=${GUEST_B_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Update user=${GUEST_C_USERNAME}. Pending request." ]; then
    echo "[OK] Test updating user "
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test updating user: ${RESP}"
fi

#####################
## RESTORE GUEST C ##
#####################
RESP=$(curl -s -X PUT -d "username=${GUEST_C_USERNAME}&realname=${GUEST_C_REALNAME}&password=${GUEST_C_PASSWORD}&pubkey=${GUEST_C_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Update user=${GUEST_C_USERNAME}. Pending request." ]; then
    echo "[OK] Test updating user (restore original pub key)"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test updating user (restore original pub key): ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${GUEST_A_USERNAME}&realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_A_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : (username, realname) couple mismatch.' ]; then
    echo "[OK] Test add user with same username (should fail)"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user with same username (should fail): ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${GUEST_A_USERNAME}&realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_B_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : (username, realname) couple mismatch.' ]; then
    echo "[OK] Test add user with same username (should fail)"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add user with same username (should fail): ${RESP}"
fi
