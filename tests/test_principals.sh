#!/bin/bash
# shellcheck disable=SC2128

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "add=test-single")
if [ "${RESP}" == "Error: No realname option given." ]; then
    echo "[OK] Test add principal without realname,password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add principal without realname,password: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "add=test-single")
if [ "${RESP}" == "Error: No password option given." ]; then
    echo "[OK] Test add principal without password"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add principal without password: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${GUEST_B_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "add=test-single")
if [ "${RESP}" == "Error: {'desc': 'Invalid credentials'}" ]; then
    echo "[OK] Test add principal with invalid credentials"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add principal with invalid credentials: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "add=test-single")
if [ "${RESP}" == "Error: Not authorized." ]; then
    echo "[OK] Test add principal with unauthorized user"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add principal with unauthorized user: ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/unknown/principals -d "add=test-single")
if [ "${RESP}" == "ERROR: unknown doesn't exist" ]; then
    echo "[OK] Test add principal 'test-single' to unknown user"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add principal 'test-single' to unknown user : ${RESP}"
fi

#################################
## ADMIN ADD PRINCIPAL GUEST B ##
#################################
RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "add=test-single")
if [ "${RESP}" == "OK: ${GUEST_B_USERNAME} principals are '${GUEST_B_USERNAME},test-single,guest-everywhere'" ]; then
    echo "[OK] Test add principal 'test-single' to ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add principal 'test-single' to ${GUEST_B_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_B_USERNAME}&realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_B_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
echo "${RESP}" > /tmp/test-cert
OUTPUT=$(echo $(echo -n "$(ssh-keygen -L -f /tmp/test-cert 2>&1)"))
if [[ "${OUTPUT}" == *"Principals: ${GUEST_B_USERNAME} test-single guest-everywhere Critical"* ]]; then
    echo "[OK] Test signing key with updated principals"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key with updated principals: ${OUTPUT}"
fi
rm -f /tmp/test-cert

RESP=$(curl -s -X POST -d "username=${GUEST_B_USERNAME}&realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_B_ALT_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
echo "${RESP}" > /tmp/test-cert
OUTPUT=$(echo $(echo -n "$(ssh-keygen -L -f /tmp/test-cert 2>&1)"))
if [[ "${OUTPUT}" == *"Principals: ${GUEST_B_USERNAME} test-single guest-everywhere Critical"* ]]; then
    echo "[OK] Test signing key with altered public key"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key with altered public key: ${OUTPUT}"
fi
rm -f /tmp/test-cert

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "add=test-single")
if [ "${RESP}" == "OK: ${GUEST_B_USERNAME} principals are '${GUEST_B_USERNAME},test-single,guest-everywhere'" ]; then
    echo "[OK] Test add duplicate principal 'test-single' to ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add duplicate principal 'test-single' to ${GUEST_B_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "remove=test-single")
if [ "${RESP}" == "OK: ${GUEST_B_USERNAME} principals are '${GUEST_B_USERNAME},guest-everywhere'" ]; then
    echo "[OK] Test remove principal 'test-single' to ${GUEST_B_USERNAME} which doesn't exists"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test remove principal 'test-single' to ${GUEST_B_USERNAME} which doesn't exists : ${RESP}"
fi

####################################
## ADMIN REMOVE PRINCIPAL GUEST B ##
####################################
RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "remove=test-single")
if [ "${RESP}" == "OK: ${GUEST_B_USERNAME} principals are '${GUEST_B_USERNAME},guest-everywhere'" ]; then
    echo "[OK] Test remove principal 'test-single' to ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test remove principal 'test-single' to ${GUEST_B_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_B_USERNAME}&realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_B_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
echo "${RESP}" > /tmp/test-cert
OUTPUT=$(echo $(echo -n "$(ssh-keygen -L -f /tmp/test-cert 2>&1)"))
if [[ "${OUTPUT}" == *"Principals: ${GUEST_B_USERNAME} guest-everywhere Critical"* ]]; then
    echo "[OK] Test signing key with updated principals"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key with updated principals: ${OUTPUT}"
fi
rm -f /tmp/test-cert

###################################
## ADMIN PURGE PRINCIPAL GUEST B ##
###################################
RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "purge=true")
if [ "${RESP}" == "OK: ${GUEST_B_USERNAME} principals are '${GUEST_B_USERNAME},guest-everywhere'" ]; then
    echo "[OK] Test purge principals to ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test purge principals to ${GUEST_B_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_B_USERNAME}&realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_B_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
echo "${RESP}" > /tmp/test-cert
OUTPUT=$(echo $(echo -n "$(ssh-keygen -L -f /tmp/test-cert 2>&1)"))
if [[ "${OUTPUT}" == *"Principals: ${GUEST_B_USERNAME} guest-everywhere Critical"* ]]; then
    echo "[OK] Test signing key with updated principals"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key with updated principals: ${OUTPUT}"
fi
rm -f /tmp/test-cert

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "add=test-multiple-a,test-multiple-b")
if [ "${RESP}" == "OK: ${GUEST_B_USERNAME} principals are '${GUEST_B_USERNAME},test-multiple-a,test-multiple-b,guest-everywhere'" ]; then
    echo "[OK] Test add principals 'test-multiple-a,test-multiple-b' to ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add principals 'test-multiple-a,test-multiple-b' to ${GUEST_B_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "remove=test-multiple-a,${BADTEXT}")
if [ "${RESP}" == "Error: invalid principals." ]; then
    echo "[OK] Test remove principals 'test-multiple-a,${BADTEXT}' to ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test remove principals 'test-multiple-a,test-multiple-b' to ${GUEST_B_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "remove=test-multiple-a,test-multiple-b")
if [ "${RESP}" == "OK: ${GUEST_B_USERNAME} principals are '${GUEST_B_USERNAME},guest-everywhere'" ]; then
    echo "[OK] Test remove principals 'test-multiple-a,test-multiple-b' to ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test remove principals 'test-multiple-a,test-multiple-b' to ${GUEST_B_USERNAME} : ${RESP}"
fi

####################################
## ADMIN UPDATE PRINCIPAL GUEST B ##
####################################
RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "update=test-multiple-c,test-multiple-${GUEST_B_USERNAME}")
if [ "${RESP}" == "OK: ${GUEST_B_USERNAME} principals are 'test-multiple-c,test-multiple-${GUEST_B_USERNAME},guest-everywhere'" ]; then
    echo "[OK] Test update principals 'test-multiple-c,test-multiple-${GUEST_B_USERNAME}' to ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test update principals 'test-multiple-c,test-multiple-${GUEST_B_USERNAME}' to ${GUEST_B_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${GUEST_B_USERNAME}&realname=${GUEST_B_REALNAME}&password=${GUEST_B_PASSWORD}&pubkey=${GUEST_B_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
echo "${RESP}" > /tmp/test-cert
OUTPUT=$(echo $(echo -n "$(ssh-keygen -L -f /tmp/test-cert 2>&1)"))
if [[ "${OUTPUT}" == *"Principals: test-multiple-c test-multiple-${GUEST_B_USERNAME} guest-everywhere Critical"* ]]; then
    echo "[OK] Test signing key with updated principals"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing key with updated principals: ${OUTPUT}"
fi
rm -f /tmp/test-cert

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "update=test-multiple-c,test-multiple-c,test-multiple-${GUEST_B_USERNAME}")
if [ "${RESP}" == "OK: ${GUEST_B_USERNAME} principals are 'test-multiple-c,test-multiple-${GUEST_B_USERNAME},guest-everywhere'" ]; then
    echo "[OK] Test update with duplicate principals 'test-multiple-c,test-multiple-${GUEST_B_USERNAME}' to ${GUEST_B_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test update with duplicate principals 'test-multiple-c,test-multiple-${GUEST_B_USERNAME}' to ${GUEST_B_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${GUEST_B_USERNAME}"/principals -d "unknown=action")
if [ "${RESP}" == "[ERROR] Unknown action" ]; then
    echo "[OK] Test unknown action"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test unknown action : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${SYSADMIN_USERNAME}&realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}&pubkey=${SYSADMIN_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
echo "${RESP}" > /tmp/test-cert
OUTPUT=$(echo $(echo -n "$(ssh-keygen -L -f /tmp/test-cert 2>&1)"))
if [[ "${OUTPUT}" == *"Principals: ${SYSADMIN_USERNAME} root-everywhere guest-everywhere Critical"* ]]; then
    echo "[OK] Test signing sysadmin key"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing sysadmin key: ${OUTPUT}"
fi
rm -f /tmp/test-cert

RESP=$(curl -s -X POST -d "realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}" "${CASSH_SERVER_URL}"/admin/"${SYSADMIN_USERNAME}"/principals -d "add=root-everywhere")
if [ "${RESP}" == "OK: ${SYSADMIN_USERNAME} principals are '${SYSADMIN_USERNAME},root-everywhere,guest-everywhere'" ]; then
    echo "[OK] Test add duplicate principal 'root-everywhere' to ${SYSADMIN_USERNAME}"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test add duplicate principal 'root-everywhere' to ${SYSADMIN_USERNAME} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${SYSADMIN_USERNAME}&realname=${SYSADMIN_REALNAME}&password=${SYSADMIN_PASSWORD}&pubkey=${SYSADMIN_PUB_KEY}" "${CASSH_SERVER_URL}"/client)
echo "${RESP}" > /tmp/test-cert
OUTPUT=$(echo $(echo -n "$(ssh-keygen -L -f /tmp/test-cert 2>&1)"))
if [[ "${OUTPUT}" == *"Principals: ${SYSADMIN_USERNAME} root-everywhere guest-everywhere Critical"* ]]; then
    echo "[OK] Test signing sysadmin key without duplicates"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test signing sysadmin key without duplicates: ${OUTPUT}"
fi
rm -f /tmp/test-cert
