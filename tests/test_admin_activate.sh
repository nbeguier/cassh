#!/bin/bash
# shellcheck disable=SC2128

RESP=$(curl -s -X POST -d 'revoke=true' "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [ "${RESP}" == "Error: No realname option given." ]; then
    echo "[OK] Test admin revoke '${GUEST_A_USERNAME}' without realname,password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin revoke '${GUEST_A_USERNAME}' without realname,password : ${RESP}"
fi

RESP=$(curl -s -X POST -d "revoke=true&realname=${SYSADMIN_REALNAME}" "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [ "${RESP}" == "Error: No password option given." ]; then
    echo "[OK] Test admin revoke '${GUEST_A_USERNAME}' without password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin revoke '${GUEST_A_USERNAME}' without password : ${RESP}"
fi

RESP=$(curl -s -X POST -d "revoke=true&realname=${SYSADMIN_REALNAME}&password=${GUEST_A_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [[ "${RESP}" == *"'desc': 'Invalid credentials'"* ]]; then
    echo "[OK] Test admin revoke '${GUEST_A_USERNAME}' with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin revoke '${GUEST_A_USERNAME}' with invalid credentials : ${RESP}"
fi

RESP=$(curl -s -X POST -d "revoke=true&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [ "${RESP}" == "Error: Not authorized." ]; then
    echo "[OK] Test admin revoke '${GUEST_A_USERNAME}' with unauthorized user"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin revoke '${GUEST_A_USERNAME}' with unauthorized user : ${RESP}"
fi

##########################
## ADMIN REVOKE GUEST A ##
##########################
RESP=$(curl -s -X POST -d "revoke=true&realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [ "${RESP}" == "Revoke user=${GUEST_A_USERNAME}." ]; then
    echo "[OK] Test admin revoke '${GUEST_A_USERNAME}'"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin revoke '${GUEST_A_USERNAME}' : ${RESP}"
fi

RESP=$(curl -s -X POST -d "revoke=true&realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [ "${RESP}" == "user ${GUEST_A_USERNAME} already revoked." ]; then
    echo "[OK] Test admin revoke '${GUEST_A_USERNAME}' again (should fail)"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin revoke '${GUEST_A_USERNAME}' again (should fail) : ${RESP}"
fi

RESP=$(curl -s -X POST -d 'status=true' "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [ "${RESP}" == "Error: No realname option given." ]; then
    echo "[OK] Test admin verify '${GUEST_A_USERNAME}' status without realname,password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin verify '${GUEST_A_USERNAME}' status without realname,password: ${RESP}"
fi

RESP=$(curl -s -X POST -d "status=true&realname=${SYSADMIN_REALNAME}" "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [ "${RESP}" == "Error: No password option given." ]; then
    echo "[OK] Test admin verify '${GUEST_A_USERNAME}' status without password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin verify '${GUEST_A_USERNAME}' status without password: ${RESP}"
fi

RESP=$(curl -s -X POST -d "status=true&realname=${SYSADMIN_REALNAME}&password=${GUEST_A_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [[ "${RESP}" == *"'desc': 'Invalid credentials'"* ]]; then
    echo "[OK] Test admin verify '${GUEST_A_USERNAME}' status with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin verify '${GUEST_A_USERNAME}' status with invalid credentials: ${RESP}"
fi

RESP=$(curl -s -X POST -d "status=true&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [ "${RESP}" == "Error: Not authorized." ]; then
    echo "[OK] Test admin verify '${GUEST_A_USERNAME}' status with unauthorized user"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin verify '${GUEST_A_USERNAME}' status with unauthorized user: ${RESP}"
fi

##########################
## ADMIN STATUS GUEST A ##
##########################
RESP=$(curl -s -X POST -d "status=true&realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}" | jq .status)
if [ "${RESP}" == '"REVOKED"' ]; then
    echo "[OK] Test admin verify '${GUEST_A_USERNAME}' status"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin verify '${GUEST_A_USERNAME}' status: ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_A_USERNAME}&realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}&pubkey=${GUEST_A_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Status: REVOKED' ]; then
    echo "[OK] Test signing key when revoked"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key when revoked: ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_A_USERNAME}&realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_A_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : (username, realname, pubkey) triple mismatch.' ]; then
    echo "[OK] Test signing key when revoked with wrong realname"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key when revoked with wrong realname: ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_A_USERNAME}&realname=${GUEST_A_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_A_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
if [[ "${RESP}" == *"'desc': 'Invalid credentials'"* ]]; then
    echo "[OK] Test signing key when revoked with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key when revoked with invalid credentials : ${RESP}"
fi

##########################
## ADMIN DELETE GUEST A ##
##########################
RESP=$(curl -s -X DELETE -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [ "${RESP}" == 'OK' ]; then
    echo "[OK] Test delete '${GUEST_A_USERNAME}'"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test delete '${GUEST_A_USERNAME}': ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_A_USERNAME}")
if [ "${RESP}" == "User does not exists." ]; then
    echo "[OK] Test admin active unknown user"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin active unknown user : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}")
if [ "${RESP}" == "Error: No realname option given." ]; then
    echo "[OK] Test admin active '${GUEST_B_USERNAME}' status without realname,password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin active '${GUEST_B_USERNAME}' status without realname,password: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}")
if [ "${RESP}" == "Error: No password option given." ]; then
    echo "[OK] Test admin active '${GUEST_B_USERNAME}' status without password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin active '${GUEST_B_USERNAME}' status without password: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${GUEST_A_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}")
if [[ "${RESP}" == *"'desc': 'Invalid credentials'"* ]]; then
    echo "[OK] Test admin active '${GUEST_B_USERNAME}' status with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin active '${GUEST_B_USERNAME}' status with invalid credentials: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}")
if [ "${RESP}" == "Error: Not authorized." ]; then
    echo "[OK] Test admin active '${GUEST_B_USERNAME}' status with unauthorized user"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin active '${GUEST_B_USERNAME}' status with unauthorized user: ${RESP}"
fi

RESP=$(curl -s -X POST -d "status=true&realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}" | jq .status)
if [ "${RESP}" == '"PENDING"' ]; then
    echo "[OK] Test admin verify '${GUEST_B_USERNAME}' status"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin verify '${GUEST_B_USERNAME}' status : ${RESP}"
fi

############################
## ADMIN ACTIVATE GUEST B ##
############################
RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}")
if [ "${RESP}" == "Active user=${GUEST_B_USERNAME}. SSH Key active but need to be signed." ]; then
    echo "[OK] Test admin active ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin active ${GUEST_B_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}")
if [ "${RESP}" == "user=${GUEST_B_USERNAME} already active. Nothing done." ]; then
    echo "[OK] Test admin re-active ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin re-active ${GUEST_B_USERNAME} : ${RESP}"
fi

############################
## ADMIN ACTIVATE GUEST C ##
############################
RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_C_USERNAME}")
if [ "${RESP}" == "Active user=${GUEST_C_USERNAME}. SSH Key active but need to be signed." ]; then
    echo "[OK] Test admin active ${GUEST_C_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin active ${GUEST_C_USERNAME} : ${RESP}"
fi

#############################
## ADMIN ACTIVATE SYSADMIN ##
#############################
RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${SYSADMIN_USERNAME}")
if [ "${RESP}" == "Active user=${SYSADMIN_USERNAME}. SSH Key active but need to be signed." ]; then
    echo "[OK] Test admin active ${SYSADMIN_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin active ${SYSADMIN_USERNAME} : ${RESP}"
fi
