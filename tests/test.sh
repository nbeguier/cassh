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
USER3=$(pwgen -A -0 10)

BADTEXT=b@dt€xt

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

RESP=$(curl -s -X POST -d "realname=test.${USER1}@domain.fr" "${CASSH_SERVER_URL}"/client/status)
if [ "${RESP}" == 'None' ]; then
    echo "[OK] Test status unknown user"
else
    echo "[FAIL] Test status unknown user : ${RESP}"
fi

. ./tests/test_client_add.sh
. ./tests/test_client_sign.sh
. ./tests/test_admin_activate.sh
. ./tests/test_principals.sh
. ./tests/test_principals_search.sh
. ./tests/test_admin_set.sh
. ./tests/test_admin_delete.sh
. ./tests/test_cluster.sh
