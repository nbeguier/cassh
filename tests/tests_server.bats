#!/usr/bin/env bats
# vim: ft=sh:sw=2:et


# Variables
load helpers


# == Test the server
#
@test "SERVER: /ping" {
    RESP=$(curl -s ${CASSH_URL}/ping)
    [ "${RESP}" == 'pong' ]
}

@test "SERVER: /health" {
    curl -s ${CASSH_URL}/health > tmp/heatlth.json
    run jq .name tmp/heatlth.json
    [ "${status}" -eq 0 ]
}


# == Client actions
#
@test "CLIENT: Status unknown user" {
    RESP=$(curl -s ${CASSH_URL}/client?realname=test.user@domain.fr)
    [ "${RESP}" == 'None' ]
}

@test "CLIENT: Add user without username" {
    RESP=$(curl -s -X PUT ${CASSH_URL}/client)
    [ "${RESP}" == 'Error: No username option given.' ]
}

@test "CLIENT: Add user with bad username" {
    RESP=$(curl -s -X PUT ${CASSH_URL}/client?username=test_user)
    [ "${RESP}" == "Error: Username test_user doesn't match pattern ^([a-z]+)$" ]
}

@test "CLIENT: Add user without realname" {
    RESP=$(curl -s -X PUT ${CASSH_URL}/client?username=testuser)
    [ "${RESP}" == 'Error: No realname option given.' ]
}

@test "CLIENT: Add user with no pubkey" {
    RESP=$(curl -s -X PUT ${CASSH_URL}/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Error : Public key unprocessable' ]
}

@test "CLIENT: Add user with bad pubkey" {
    RESP=$(curl -s -X PUT -d "toto" ${CASSH_URL}/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Error : Public key unprocessable' ]
}

@test "CLIENT: Add user" {
    RESP=$(curl -s -X PUT -d "${PUB_KEY_EXAMPLE}" ${CASSH_URL}/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Create user=testuser. Pending request.' ]
}

@test "CLIENT: Add user named 'all' (should fail)" {
    RESP=$(curl -s -X PUT -d "${PUB_KEY_EXAMPLE}" ${CASSH_URL}/client?username=all\&realname=test.user@domain.fr)
    [ "${RESP}" == "Error: Username all doesn't match pattern ^([a-z]+)$" ]
}

@test "CLIENT: Status pending user" {
    RESP=$(curl -s "${CASSH_URL}/client?realname=test.user@domain.fr" | jq .status)
    [ "${RESP}" == '"PENDING"' ]
}

@test "CLIENT: Add user with same realname (which is possible)" {
    RESP=$(curl -s -X PUT -d "${PUB_KEY_EXAMPLE}" ${CASSH_URL}/client?username=toto\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Create user=toto. Pending request.' ]
}

@test "CLIENT: Updating user" {
    RESP=$(curl -s -X PUT -d "${PUB_KEY_2_EXAMPLE}" ${CASSH_URL}/client?username=toto\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Update user=toto. Pending request.' ]
}

@test "CLIENT: Add user with same username (should fail)" {
    RESP=$(curl -s -X PUT -d "${PUB_KEY_EXAMPLE}" ${CASSH_URL}/client?username=testuser\&realname=toto123@domain.fr)
    [ "${RESP}" == 'Error : (username, realname) couple mismatch.' ]
}

@test "CLIENT: Signing key without username" {
    RESP=$(curl -s -X POST ${CASSH_URL}/client)
    [ "${RESP}" == 'Error: No username option given. Update your CASSH >= 1.3.0' ]
}

@test "CLIENT: Signing key without realname" {
    RESP=$(curl -s -X POST ${CASSH_URL}/client?username=testuser)
    [ "${RESP}" == 'Error: No realname option given.' ]
}

@test "CLIENT: Signing key with no pubkey" {
    RESP=$(curl -s -X POST ${CASSH_URL}/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Error : Public key unprocessable' ]
}

@test "CLIENT: Signing key with bad pubkey" {
    RESP=$(curl -s -X POST -d "toto" ${CASSH_URL}/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Error : Public key unprocessable' ]
}

@test "CLIENT: Signing key when wrong public key" {
    RESP=$(curl -s -X POST -d "${PUB_KEY_2_EXAMPLE}" ${CASSH_URL}/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Error : User or Key absent, add your key again.' ]
}

@test "CLIENT: Signing key when PENDING status" {
    RESP=$(curl -s -X POST -d "${PUB_KEY_EXAMPLE}" ${CASSH_URL}/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Status: PENDING' ]
}

@test "ADMIN: Revoke 'toto'" {
    RESP=$(curl -s ${CASSH_URL}/admin/toto?revoke=true)
    [ "${RESP}" == 'Revoke user=toto.' ]
}

@test "ADMIN: Verify 'toto' status" {
    RESP=$(curl -s ${CASSH_URL}/admin/toto?status=true | jq .status)
    [ "${RESP}" == '"REVOKED"' ]
}

@test "CLIENT: Signing key when revoked" {
    RESP=$(curl -s -X POST -d "${PUB_KEY_2_EXAMPLE}" ${CASSH_URL}/client?username=toto\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Status: REVOKED' ]
}


# == Admin specific actions
#
@test "ADMIN: Delete 'toto'" {
    RESP=$(curl -s -X DELETE ${CASSH_URL}/admin/toto)
    [ "${RESP}" == 'OK' ]
}

@test "ADMIN: Active unknown user" {
    RESP=$(curl -s ${CASSH_URL}/admin/toto)
    [ "${RESP}" == "User 'toto' does not exists." ]
}

@test "ADMIN: Verify 'testuser' status" {
    RESP=$(curl -s ${CASSH_URL}/admin/testuser?status=true | jq .status)
    [ "${RESP}" == '"PENDING"' ]
}

@test "ADMIN: Active testuser" {
    RESP=$(curl -s ${CASSH_URL}/admin/testuser)
    [ "${RESP}" == "Active user=testuser. SSH Key active but need to be signed." ]
}

@test "ADMIN: Re-active testuser" {
    RESP=$(curl -s ${CASSH_URL}/admin/testuser)
    [ "${RESP}" == "user=testuser already active. Nothing done." ]
}

@test "CLIENT: Signing key" {
    curl -s -X POST -d "${PUB_KEY_EXAMPLE}" "${CASSH_URL}/client?username=testuser&realname=test.user@domain.fr" > tmp/test-cert
    run ssh-keygen -L -f tmp/test-cert
    [ "${status}" -eq 0 ]
}

@test "ADMIN: Delete 'testuser'" {
    RESP=$(curl -s -X DELETE ${CASSH_URL}/admin/testuser)
    [ "${RESP}" == 'OK' ]
}

