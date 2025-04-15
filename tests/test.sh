#!/bin/bash
# shellcheck disable=SC2128
# shellcheck disable=SC2034
# shellcheck disable=SC2016

CASSH_SERVER_URL=${1:-http://localhost:8080}

KEY_1_EXAMPLE=/tmp/.id_rsa
KEY_2_EXAMPLE=/tmp/.id_ecdsa
KEY_3_EXAMPLE=/tmp/.id_rsa3
KEY_4_EXAMPLE=/tmp/.id_rsa4

# Generate random keys
echo -e 'y\n' | ssh-keygen -t rsa -b 4096 -o -a 100 -f "${KEY_1_EXAMPLE}" -q -N "" >/dev/null 2>&1
echo -e 'y\n' | ssh-keygen -t ecdsa -b 521 -f "${KEY_2_EXAMPLE}" -q -N "" >/dev/null 2>&1
echo -e 'y\n' | ssh-keygen -t rsa -b 2048 -o -a 100 -f "${KEY_3_EXAMPLE}" -q -N "" >/dev/null 2>&1
echo -e 'y\n' | ssh-keygen -t rsa -b 1024 -o -a 100 -f "${KEY_4_EXAMPLE}" -q -N "" >/dev/null 2>&1

# USER: sysadmin
SYSADMIN_PUB_KEY=$(cat "${KEY_1_EXAMPLE}".pub)
SYSADMIN_USERNAME=sysadmin$(pwgen -A -0 10)
SYSADMIN_REALNAME=sysadmin@example.org
SYSADMIN_PASSWORD=b@dt€xt

# USER: guest.a
GUEST_A_PUB_KEY=$(cat "${KEY_2_EXAMPLE}".pub)
GUEST_A_USERNAME=guesta$(pwgen -A -0 10)
GUEST_A_REALNAME=guest.a@example.org
GUEST_A_PASSWORD=hG9%60P%3AJznneDcTfN%7D6KLr%2DV%5Ev%24EKR%3CDrx%22qj%28%5C%2Bf  # urlencoded

# USER: guest.b
GUEST_B_PUB_KEY=$(cat "${KEY_3_EXAMPLE}".pub)
GUEST_B_ALT_PUB_KEY=$(cat "${KEY_3_EXAMPLE}".pub | awk '{print $1" "$2" some-random-comment"}')
GUEST_B_USERNAME=guestb$(pwgen -A -0 10)
GUEST_B_REALNAME=guest.b@example.org
GUEST_B_PASSWORD=ohwie6aegohghaegho2zed2kah6gaajeiV0ThahQu6oogukaevei4eeh9co0aiyeem9baeKeeh1ohphae9ies0ahx0Eechuij4osaej5ahchei1Jo2gaze2ahch3ohpiyie4hai4ohdi0fohx2akae4ooChohce1Thieg4shoosh9epae9ainooy1uepaad1gei1pheongaunie0mohy3Ich9eetohn1ni9johzaiMoan8sha7eish6Gee

# USER: guest.c, same realname as guest.b
GUEST_C_PUB_KEY=$(cat "${KEY_4_EXAMPLE}".pub)
GUEST_C_USERNAME=guestc$(pwgen -A -0 10)
GUEST_C_REALNAME=guest.b@example.org
GUEST_C_PASSWORD=ohwie6aegohghaegho2zed2kah6gaajeiV0ThahQu6oogukaevei4eeh9co0aiyeem9baeKeeh1ohphae9ies0ahx0Eechuij4osaej5ahchei1Jo2gaze2ahch3ohpiyie4hai4ohdi0fohx2akae4ooChohce1Thieg4shoosh9epae9ainooy1uepaad1gei1pheongaunie0mohy3Ich9eetohn1ni9johzaiMoan8sha7eish6Gee

BADTEXT=b@dt€xt

# Clean postgresql database
./tests/postgres/clean_pg.py

RESP=$(curl -s "${CASSH_SERVER_URL}"/ping)
if [ "${RESP}" == 'pong' ]; then
    echo "[OK] Test ping"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test ping : ${RESP}"
fi

curl -s "${CASSH_SERVER_URL}"/health >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "[OK] Test health"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test health"
fi

RESP=$(curl -s -X POST -d "realname=${GUEST_A_REALNAME}&password=${GUEST_A_PASSWORD}" "${CASSH_SERVER_URL}"/client/status)
if [ "${RESP}" == '{}' ]; then
    echo "[OK] Test status unknown user"
else
    echo "[FAIL ${BASH_SOURCE}:+${LINENO}] Test status unknown user : ${RESP}"
fi

. ./tests/test_client_add.sh
. ./tests/test_client_sign_error.sh
. ./tests/test_admin_activate.sh
. ./tests/test_principals.sh
. ./tests/test_principals_search.sh
. ./tests/test_admin_set.sh
. ./tests/test_admin_delete.sh
. ./tests/test_cluster.sh
