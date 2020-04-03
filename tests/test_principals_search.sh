#!/bin/bash
# shellcheck disable=SC2128


RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=")
if [[ "${RESP}" == "Error: No realname option given." ]]; then
    echo "[OK] Test search principals without realname,password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search all users' principals without realname,password: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=")
if [[ "${RESP}" == "Error: No password option given." ]]; then
    echo "[OK] Test search principals without password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search all users' principals without password: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${GUEST_B_PASSWORD}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=")
if [[ "${RESP}" == "Error: {'desc': 'Invalid credentials'}" ]]; then
    echo "[OK] Test search principals with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search all users' principals with invalid credentials: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=")
if [[ "${RESP}" == "Error: Not authorized." ]]; then
    echo "[OK] Test search principals with unauthorized user"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search all users' principals with unauthorized user: ${RESP}"
fi

#################################
## ADMIN SEARCH ALL PRINCIPALS ##
#################################
RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=")
if [[ "${RESP}" == *"{\""* ]]; then
    echo "[OK] Test search all users' principals"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search all users' principals : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=dontexists")
if [ "${RESP}" == "{}" ]; then
    echo "[OK] Test search unknown principals"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search unknown principals : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=test-multiple-${GUEST_B_USERNAME}")
if [ "${RESP}" == "{\"${GUEST_B_USERNAME}\": [\"test-multiple-${GUEST_B_USERNAME}\"]}" ]; then
    echo "[OK] Test search single principal"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search single principal : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_C_USERNAME}"/principals -d "add=test-multiple-${GUEST_B_USERNAME}")
if [ "${RESP}" == "OK: ${GUEST_C_USERNAME} principals are '${GUEST_C_USERNAME},test-multiple-${GUEST_B_USERNAME}'" ]; then
    echo "[OK] Test add principal 'test-multiple-${GUEST_B_USERNAME}' to ${GUEST_C_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add principal 'test-multiple-${GUEST_B_USERNAME}' to ${GUEST_C_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=test-multiple-${GUEST_B_USERNAME}")
if [[ "${RESP}" == *"\"${GUEST_C_USERNAME}\": [\"test-multiple-${GUEST_B_USERNAME}\""* ]] && [[ "${RESP}" == *"\"${GUEST_B_USERNAME}\": [\"test-multiple-${GUEST_B_USERNAME}\""* ]]; then
    echo "[OK] Test search single principals with multiple users"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search single principals with multiple users : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=test-multiple-${GUEST_B_USERNAME},unknown")
if [[ "${RESP}" == *"\"${GUEST_C_USERNAME}\": [\"test-multiple-${GUEST_B_USERNAME}\""* ]] && [[ "${RESP}" == *"\"${GUEST_B_USERNAME}\": [\"test-multiple-${GUEST_B_USERNAME}\""* ]]; then
    echo "[OK] Test search multiple principals with one unknown"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search multiple principals with one unknown : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=test-multiple-${GUEST_B_USERNAME},${BADTEXT}")
if [ "${RESP}" == "Error: invalid filter." ]; then
    echo "[OK] Test search multiple principals with one bad value"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search multiple principals with one bad value : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_C_USERNAME}"/principals -d "remove=test-multiple-${GUEST_B_USERNAME}")
if [ "${RESP}" == "OK: ${GUEST_C_USERNAME} principals are '${GUEST_C_USERNAME}'" ]; then
    echo "[OK] Test remove principal 'test-multiple-${GUEST_B_USERNAME}' to ${GUEST_C_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test remove principal 'test-multiple-${GUEST_B_USERNAME}' to ${GUEST_C_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=test-multiple-${GUEST_B_USERNAME},${GUEST_C_USERNAME}")
if [[ "${RESP}" == *"\"${GUEST_C_USERNAME}\": [\"${GUEST_C_USERNAME}\""* ]] && [[ "${RESP}" == *"\"${GUEST_B_USERNAME}\": [\"test-multiple-${GUEST_B_USERNAME}\""* ]]; then
    echo "[OK] Test search multiple principals with multiple users"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search multiple principals with multiple users : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "unknown=action")
if [ "${RESP}" == "[ERROR] Unknown action" ]; then
    echo "[OK] Test search with unknown action"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search with unknown action : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/all/principals/search -d "${BADTEXT}")
if [ "${RESP}" == "[ERROR] Unknown action" ]; then
    echo "[OK] Test search with garbage"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test search with garbage : ${RESP}"
fi
