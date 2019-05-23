#!/bin/bash

CASSH_SERVER_URL=${1:-http://localhost:8080}

KEY_1_EXAMPLE=/tmp/.id_rsa
KEY_2_EXAMPLE=/tmp/.id_ecdsa

# Generate random keys
echo -e 'y\n' | ssh-keygen -t rsa -b 4096 -o -a 100 -f "${KEY_1_EXAMPLE}" -q -N "" >/dev/null 2>&1
echo -e 'y\n' | ssh-keygen -t ecdsa -b 521 -f "${KEY_2_EXAMPLE}" -q -N "" >/dev/null 2>&1

PUB_KEY_1_EXAMPLE=$(cat "${KEY_1_EXAMPLE}".pub)
PUB_KEY_2_EXAMPLE=$(cat "${KEY_2_EXAMPLE}".pub)


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

RESP=$(curl -s -X GET "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: DEPRECATED option. Update your CASSH >= 1.5.0' ]; then
    echo "[OK] Test deprecated status URL without username"
else
    echo "[FAIL] Test deprecated status URL without username: ${RESP}"
fi

RESP=$(curl -s -X GET "${CASSH_SERVER_URL}"/admin/testuser)
if [ "${RESP}" == "Error: DEPRECATED option. Update your CASSH >= 1.5.0" ]; then
    echo "[OK] Test deprecated admin status URL without username"
else
    echo "[FAIL] Test deprecated status URL without username: ${RESP}"
fi

RESP=$(curl -s -X GET -d 'username=test_user' "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: DEPRECATED option. Update your CASSH >= 1.5.0' ]; then
    echo "[OK] Test deprecated status URL with username"
else
    echo "[FAIL] Test deprecated status URL with username: ${RESP}"
fi

RESP=$(curl -s -X GET -d 'username=test_user' "${CASSH_SERVER_URL}"/admin/testuser)
if [ "${RESP}" == "Error: DEPRECATED option. Update your CASSH >= 1.5.0" ]; then
    echo "[OK] Test deprecated status URL with username"
else
    echo "[FAIL] Test deprecated status URL with username: ${RESP}"
fi

RESP=$(curl -s -X PUT "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No username option given.' ]; then
    echo "[OK] Test add user without username"
else
    echo "[FAIL] Test add user without username : ${RESP}"
fi

RESP=$(curl -s -X PUT -d 'username=test_user' "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: Username test_user doesn't match pattern ^([a-z]+)$" ]; then
    echo "[OK] Test add user with bad username"
else
    echo "[FAIL] Test add user with bad username : ${RESP}"
fi

RESP=$(curl -s -X PUT -d 'username=testuser' "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No realname option given.' ]; then
    echo "[OK] Test add user without realname"
else
    echo "[FAIL] Test add user without realname : ${RESP}"
fi

RESP=$(curl -s -X PUT -d 'username=testuser&realname=test.user@domain.fr' "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No pubkey given.' ]; then
    echo "[OK] Test add user with no pubkey"
else
    echo "[FAIL] Test add user with no pubkey : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=testuser&realname=test.user@domain.fr&pubkey=toto" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : Public key unprocessable' ]; then
    echo "[OK] Test add user with bad pubkey"
else
    echo "[FAIL] Test add user with bad pubkey : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=testuser&realname=test.user@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Create user=testuser. Pending request.' ]; then
    echo "[OK] Test add user"
else
    echo "[FAIL] Test add user : ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=all&realname=test.user@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == "Error: Username all doesn't match pattern ^([a-z]+)$" ]; then
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

RESP=$(curl -s -X PUT -d "username=toto&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Create user=toto. Pending request.' ]; then
    echo "[OK] Test add user with same realname (which is possible)"
else
    echo "[FAIL] Test add user with same realname (which is possible): ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=toto&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Update user=toto. Pending request.' ]; then
    echo "[OK] Test updating user"
else
    echo "[FAIL] Test updating user: ${RESP}"
fi

RESP=$(curl -s -X PUT -d "username=testuser&realname=toto123@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
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

RESP=$(curl -s -X POST -d 'username=testuser' "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No realname option given.' ]; then
    echo "[OK] Test signing key without realname"
else
    echo "[FAIL] Test signing key without realname: ${RESP}"
fi

RESP=$(curl -s -X POST -d 'username=testuser&realname=test.user@domain.fr' "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error: No pubkey given.' ]; then
    echo "[OK] Test signing key with no pubkey"
else
    echo "[FAIL] Test signing key with no pubkey : ${RESP}"
fi

RESP=$(curl -s -X POST -d 'username=testuser&realname=test.user@domain.fr&pubkey=toto' "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : Public key unprocessable' ]; then
    echo "[OK] Test signing key with bad pubkey"
else
    echo "[FAIL] Test signing key with bad pubkey : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=testuser&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Error : User or Key absent, add your key again.' ]; then
    echo "[OK] Test signing key when wrong public key"
else
    echo "[FAIL] Test signing key when wrong public key : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=testuser&realname=test.user@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Status: PENDING' ]; then
    echo "[OK] Test signing key when PENDING status"
else
    echo "[FAIL] Test signing key when PENDING status : ${RESP}"
fi

RESP=$(curl -s -X POST -d 'revoke=true' "${CASSH_SERVER_URL}"/admin/toto)
if [ "${RESP}" == 'Revoke user=toto.' ]; then
    echo "[OK] Test admin revoke 'toto'"
else
    echo "[FAIL] Test admin revoke 'toto' : ${RESP}"
fi

RESP=$(curl -s -X POST -d 'status=true' "${CASSH_SERVER_URL}"/admin/toto | jq .status)
if [ "${RESP}" == '"REVOKED"' ]; then
    echo "[OK] Test admin verify 'toto' status"
else
    echo "[FAIL] Test admin verify 'toto' status : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=toto&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
if [ "${RESP}" == 'Status: REVOKED' ]; then
    echo "[OK] Test signing key when revoked"
else
    echo "[FAIL] Test signing key when revoked: ${RESP}"
fi

RESP=$(curl -s -X DELETE "${CASSH_SERVER_URL}"/admin/toto)
if [ "${RESP}" == 'OK' ]; then
    echo "[OK] Test delete 'toto'"
else
    echo "[FAIL] Test delete 'toto': ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/toto)
if [ "${RESP}" == "User 'toto' does not exists." ]; then
    echo "[OK] Test admin active unknown user"
else
    echo "[FAIL] Test admin active unknown user : ${RESP}"
fi

RESP=$(curl -s -X POST -d 'status=true' "${CASSH_SERVER_URL}"/admin/testuser | jq .status)
if [ "${RESP}" == '"PENDING"' ]; then
    echo "[OK] Test admin verify 'testuser' status"
else
    echo "[FAIL] Test admin verify 'testuser' status : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/testuser)
if [ "${RESP}" == "Active user=testuser. SSH Key active but need to be signed." ]; then
    echo "[OK] Test admin active testuser"
else
    echo "[FAIL] Test admin active testuser : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/testuser)
if [ "${RESP}" == "user=testuser already active. Nothing done." ]; then
    echo "[OK] Test admin re-active testuser"
else
    echo "[FAIL] Test admin re-active testuser : ${RESP}"
fi

RESP=$(curl -s -X POST -d "username=testuser&realname=test.user@domain.fr&pubkey=${PUB_KEY_1_EXAMPLE}" "${CASSH_SERVER_URL}"/client)
echo "${RESP}" > /tmp/test-cert
if ssh-keygen -L -f /tmp/test-cert >/dev/null 2>&1; then
    echo "[OK] Test signing key"
else
    echo "[FAIL] Test signing key : ${RESP}"
fi
rm -f /tmp/test-cert

RESP=$(curl -s -X DELETE "${CASSH_SERVER_URL}"/admin/testuser)
if [ "${RESP}" == 'OK' ]; then
    echo "[OK] Test delete 'testuser'"
else
    echo "[FAIL] Test delete 'testuser': ${RESP}"
fi


RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/cluster/updatekrl)
if [ "${RESP}" == "Unauthorized" ]; then
    echo "[OK] Test updatekrl without parameters"
else
    echo "[FAIL] Test updatekrl without parameters : ${RESP}"
fi
RESP=$(curl -s -X POST -d "clustersecret=bad" "${CASSH_SERVER_URL}"/cluster/updatekrl)
if [ "${RESP}" == "Unauthorized" ]; then
    echo "[OK] Test updatekrl with a bad clustersecret"
else
    echo "[FAIL] Test updatekrl with a bad clustersecret : ${RESP}"
fi

RESP=$(curl -s -X GET "${CASSH_SERVER_URL}"/cluster/status)
if [[ "${RESP}" == *"OK"* ]]; then
    echo "[OK] Test cluster status"
else
    echo "[FAIL] Test cluster status : ${RESP}"
fi
