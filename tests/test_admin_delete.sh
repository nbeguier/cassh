#!/bin/bash
# shellcheck disable=SC2128

RESP=$(curl -s -X DELETE -d 'status=true' "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}")
if [ "${RESP}" == "Error: No realname option given." ]; then
    echo "[OK] Test admin delete '${GUEST_B_USERNAME}' status without realname,password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin delete '${GUEST_B_USERNAME}' status without realname,password: ${RESP}"
fi

RESP=$(curl -s -X DELETE -d "status=true&realname=${SYSADMIN_REALNAME}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}")
if [ "${RESP}" == "Error: No password option given." ]; then
    echo "[OK] Test admin delete '${GUEST_B_USERNAME}' status without password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin delete '${GUEST_B_USERNAME}' status without password: ${RESP}"
fi

RESP=$(curl -s -X DELETE -d "status=true&realname=${SYSADMIN_REALNAME}&password=${GUEST_B_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}")
if [[ "${RESP}" == *"'desc': 'Invalid credentials'"* ]]; then
    echo "[OK] Test admin delete '${GUEST_B_USERNAME}' status with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin delete '${GUEST_B_USERNAME}' status with invalid credentials: ${RESP}"
fi

RESP=$(curl -s -X DELETE -d "status=true&realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}")
if [ "${RESP}" == "Error: Not authorized." ]; then
    echo "[OK] Test admin delete '${GUEST_B_USERNAME}' status with unauthorized user"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test admin delete '${GUEST_B_USERNAME}' status with unauthorized user: ${RESP}"
fi

##########################
## ADMIN DELETE GUEST B ##
##########################
RESP=$(curl -s -X DELETE -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}")
if [ "${RESP}" == 'OK' ]; then
    echo "[OK] Test delete '${GUEST_B_USERNAME}'"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test delete '${GUEST_B_USERNAME}': ${RESP}"
fi

##########################
## ADMIN DELETE GUEST B ##
##########################
RESP=$(curl -s -X DELETE -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_C_USERNAME}")
if [ "${RESP}" == 'OK' ]; then
    echo "[OK] Test delete '${GUEST_C_USERNAME}'"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test delete '${GUEST_C_USERNAME}': ${RESP}"
fi
