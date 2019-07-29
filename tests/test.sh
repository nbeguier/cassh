#!/bin/bash

CASSH_SERVER_URL=${1:-http://localhost:8080}

KEY_1_EXAMPLE=/tmp/.id_rsa
KEY_2_EXAMPLE=/tmp/.id_ecdsa

# Generate random keys
echo -e 'y\n' | ssh-keygen -t rsa -b 4096 -o -a 100 -f "${KEY_1_EXAMPLE}" -q -N "" >/dev/null 2>&1
echo -e 'y\n' | ssh-keygen -t ecdsa -b 521 -f "${KEY_2_EXAMPLE}" -q -N "" >/dev/null 2>&1

PUB_KEY_1_EXAMPLE=$(cat "${KEY_1_EXAMPLE}".pub)
PUB_KEY_2_EXAMPLE=$(cat "${KEY_2_EXAMPLE}".pub)

USER1=$(pwgen -A -0 10)
USER2=$(pwgen -A -0 10)

RESP=$(curl -s "${CASSH_SERVER_URL}"/ping)
if [ "${RESP}" == 'pong' ]; then
    echo "[OK] Test ping"
else
    echo "[FAIL] Test ping : ${RESP}"
fi

curl -s "${CASSH_SERVER_URL}"/health >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "[OK] Test health"
else
    echo "[FAIL] Test health"
fi

RESP=$(curl -s -X POST -d 'realname=test.user@domain.fr' "${CASSH_SERVER_URL}"/client/status)
if [ "${RESP}" == 'None' ]; then
    echo "[OK] Test status unknown user"
else
    echo "[FAIL] Test status unknown user : ${RESP}"
fi

RESP=$(curl -s -X PUT "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No username option given.' ]; then
    echo "[OK] Test add user without username"
else
    echo "[FAIL] Test add user without username : ${RESP}"
fi

RESP=$(curl -s -X PUT -d 'username=test_user' "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: Username doesn't match pattern ^([a-z]+)$" ]; then
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

RESP=$(curl -s -X PUT -d "username=${USER2}&realname=test.user@domain.fr" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No pubkey given.' ]; then
    echo "[OK] Test add user with no pubkey"
else
    echo "[FAIL] Test add user with no pubkey : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER2}&realname=test.user@domain.fr&pubkey=bad_pubkey" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : Public key unprocessable' ]; then
    echo "[OK] Test add user with bad pubkey"
else
    echo "[FAIL] Test add user with bad pubkey : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER2}&realname=(select%20extractvalue(g%3b]%3e')%2c'%2fl')%20from%20dual)&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: Realname doesn't match pattern" ]; then
    echo "[OK] Test add user with bad realname"
else
    echo "[FAIL] Test add user with bad realname : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER2}&realname=test.user@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Create user=${USER2}. Pending request." ]; then
    echo "[OK] Test add user"
else
    echo "[FAIL] Test add user : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=all&realname=test.user@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: Username doesn't match pattern ^([a-z]+)$" ]; then
    echo "[OK] Test add user named 'all' (should fail)"
else
    echo "[FAIL] Test add user named 'all' (should fail): ${RESP}"
fi

RESP=$(curl -s -X POST -d 'realname=test.user@domain.fr' "${CASSH_SERVER_URL}"/client/status | jq .status)
if [ "${RESP}" == '"PENDING"' ]; then
    echo "[OK] Test status pending user"
else
    echo "[FAIL] Test status pending user : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER1}&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Create user=${USER1}. Pending request." ]; then
    echo "[OK] Test add user with same realname (which is possible)"
else
    echo "[FAIL] Test add user with same realname (which is possible): ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=${USER1}&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
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

RESP=$(curl -s -X POST -d "username=${USER2}&realname=test.user@domain.fr" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No pubkey given.' ]; then
    echo "[OK] Test signing key with no pubkey"
else
    echo "[FAIL] Test signing key with no pubkey : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER2}&realname=test.user@domain.fr&pubkey=bad_pubkey" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : Public key unprocessable' ]; then
    echo "[OK] Test signing key with bad pubkey"
else
    echo "[FAIL] Test signing key with bad pubkey : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER2}&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : User or Key absent, add your key again.' ]; then
    echo "[OK] Test signing key when wrong public key"
else
    echo "[FAIL] Test signing key when wrong public key : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER2}&realname=test.user@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Status: PENDING' ]; then
    echo "[OK] Test signing key when PENDING status"
else
    echo "[FAIL] Test signing key when PENDING status : ${RESP}"
fi

RESP=$(curl -s -X POST -d 'revoke=true' "${CASSH_SERVER_URL}"/admin/"${USER1}")
if [ "${RESP}" == "Revoke user=${USER1}." ]; then
    echo "[OK] Test admin revoke '${USER1}'"
else
    echo "[FAIL] Test admin revoke '${USER1}' : ${RESP}"
fi

RESP=$(curl -s -X POST -d 'status=true' "${CASSH_SERVER_URL}"/admin/"${USER1}" | jq .status)
if [ "${RESP}" == '"REVOKED"' ]; then
    echo "[OK] Test admin verify '${USER1}' status"
else
    echo "[FAIL] Test admin verify '${USER1}' status : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER1}&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Status: REVOKED' ]; then
    echo "[OK] Test signing key when revoked"
else
    echo "[FAIL] Test signing key when revoked: ${RESP}"
fi

RESP=$(curl -s -X DELETE "${CASSH_SERVER_URL}"/admin/"${USER1}")
if [ "${RESP}" == 'OK' ]; then
    echo "[OK] Test delete '${USER1}'"
else
    echo "[FAIL] Test delete '${USER1}': ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER1}")
if [ "${RESP}" == "User does not exists." ]; then
    echo "[OK] Test admin active unknown user"
else
    echo "[FAIL] Test admin active unknown user : ${RESP}"
fi

RESP=$(curl -s -X POST -d 'status=true' "${CASSH_SERVER_URL}"/admin/"${USER2}" | jq .status)
if [ "${RESP}" == '"PENDING"' ]; then
    echo "[OK] Test admin verify '${USER2}' status"
else
    echo "[FAIL] Test admin verify '${USER2}' status : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}")
if [ "${RESP}" == "Active user=${USER2}. SSH Key active but need to be signed." ]; then
    echo "[OK] Test admin active ${USER2}"
else
    echo "[FAIL] Test admin active ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}")
if [ "${RESP}" == "user=${USER2} already active. Nothing done." ]; then
    echo "[OK] Test admin re-active ${USER2}"
else
    echo "[FAIL] Test admin re-active ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X PATCH "${CASSH_SERVER_URL}"/admin/"${USER2}" -d "principals=${USER2},test")
if [ "${RESP}" == "OK: principals=${USER2},test for ${USER2}" ]; then
    echo "[OK] Test add principal 'test' to ${USER2}"
else
    echo "[FAIL] Test add principal 'test' to ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X PATCH "${CASSH_SERVER_URL}"/admin/"${USER2}" -d "principals=${USER2},test-with-dash")
if [ "${RESP}" == "OK: principals=${USER2},test-with-dash for ${USER2}" ]; then
    echo "[OK] Test add principal 'test-with-dash' to ${USER2}"
else
    echo "[FAIL] Test add principal 'test-with-dash' to ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X PATCH "${CASSH_SERVER_URL}"/admin/"${USER2}" -d "principals=${USER2},b@dt€xt")
if [ "${RESP}" == 'ERROR: Value b@dt€xt is malformed. Should match pattern ^([a-zA-Z-]+)$' ]; then
    echo "[OK] Test add wrong principal 'b@dt€xt' to ${USER2}"
else
    echo "[FAIL] Test add wrong principal 'b@dt€xt' to ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X PATCH "${CASSH_SERVER_URL}"/admin/"${USER2}" -d "expiry=+3d")
if [ "${RESP}" == "OK: expiry=+3d for ${USER2}" ]; then
    echo "[OK] Test set expiry to 3 days for ${USER2}"
else
    echo "[FAIL] Test set expiry to 3 days for ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X PATCH "${CASSH_SERVER_URL}"/admin/"${USER2}" -d "expiry=3d")
if [ "${RESP}" == 'ERROR: Value 3d is malformed. Should match pattern ^\+([0-9]+)+[dh]$' ]; then
    echo "[OK] Test set wrong expiry for ${USER2}"
else
    echo "[FAIL] Test set wrong expiry for ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=${USER2}&realname=test.user@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
echo "${RESP}" > /tmp/test-cert
if ssh-keygen -L -f /tmp/test-cert >/dev/null 2>&1; then
    echo "[OK] Test signing key"
else
    echo "[FAIL] Test signing key : ${RESP}"
fi
rm -f /tmp/test-cert

RESP=$(curl -s -X DELETE "${CASSH_SERVER_URL}"/admin/"${USER2}")
if [ "${RESP}" == 'OK' ]; then
    echo "[OK] Test delete '${USER2}'"
else
    echo "[FAIL] Test delete '${USER2}': ${RESP}"
fi

RESP=$(curl -s -X GET "${CASSH_SERVER_URL}"/cluster/status)
if [[ "${RESP}" == *"OK"* ]]; then
    echo "[OK] Test cluster status"
else
    echo "[FAIL] Test cluster status : ${RESP}"
fi
