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


# == Deprecated
#
@test "DEPRECATED status URL without username" {
    RESP=$(curl -s -X GET ${CASSH_URL}/client)
    [ "${RESP}" == 'Error: DEPRECATED option. Update your CASSH >= 1.5.0' ]
}

@test "DEPRECATED admin status URL without username" {
    RESP=$(curl -s -X GET ${CASSH_URL}/admin/testuser)
    [ "${RESP}" == "Error: DEPRECATED option. Update your CASSH >= 1.5.0" ]
}

@test "DEPRECATED status URL with username" {
    RESP=$(curl -s -X GET -d 'username=test_user' ${CASSH_URL}/client)
    [ "${RESP}" == 'Error: DEPRECATED option. Update your CASSH >= 1.5.0' ]
}

@test "DEPRECATED status URL with username" {
    RESP=$(curl -s -X GET -d 'username=test_user' ${CASSH_URL}/admin/testuser)
    [ "${RESP}" == "Error: DEPRECATED option. Update your CASSH >= 1.5.0" ]
}


# == Client actions
#
@test "CLIENT: Status unknown user" {
    RESP=$(curl -s -X POST -d 'realname=test.user@domain.fr' ${CASSH_URL}/client/status)
    [ "${RESP}" == 'None' ]
}


# == Add user
#
@test "CLIENT: Add user without username" {
    RESP=$(curl -s -X PUT ${CASSH_URL}/client)
    [ "${RESP}" == 'Error: No username option given.' ]
}

@test "CLIENT: Add user with bad username" {
    RESP=$(curl -s -X PUT -d 'username=test_user' ${CASSH_URL}/client)
    [ "${RESP}" == "Error: Username doesn't match pattern ^([a-z]+)$" ]
}

@test "CLIENT: Add user without realname" {
    RESP=$(curl -s -X PUT -d 'username=testuser' ${CASSH_URL}/client)
    [ "${RESP}" == 'Error: No realname option given.' ]
}

@test "CLIENT: Add user with no pubkey" {
    RESP=$(curl -s -X PUT -d 'username=testuser&realname=test.user@domain.fr' ${CASSH_URL}/client)
    [ "${RESP}" == 'Error: No pubkey given.' ]
}

@test "CLIENT: Add user with bad pubkey" {
    RESP=$(curl -s -X PUT -d "username=testuser&realname=test.user@domain.fr&pubkey=toto" ${CASSH_URL}/client)
    [ "${RESP}" == 'Error : Public key unprocessable' ]
}

@test "CLIENT: Add user" {
    RESP=$(curl -s -X PUT -d "username=testuser&realname=test.user@domain.fr&pubkey=${PUB_KEY_EXAMPLE}" ${CASSH_URL}/client)
    [ "${RESP}" == 'Create user=testuser. Pending request.' ]
}

@test "CLIENT: Add user named 'all' (should fail)" {
    RESP=$(curl -s -X PUT -d "username=all&realname=test.user@domain.fr&pubkey=${PUB_KEY_EXAMPLE}" ${CASSH_URL}/client)
    [ "${RESP}" == "Error: Username doesn't match pattern ^([a-z]+)$" ]
}

@test "CLIENT: Add user with same username (should fail)" {
    RESP=$(curl -s -X PUT -d "username=testuser&realname=toto123@domain.fr&pubkey=${PUB_KEY_EXAMPLE}" ${CASSH_URL}/client)
    [ "${RESP}" == 'Error : (username, realname) couple mismatch.' ]
}

@test "CLIENT: Add user with same realname (which is possible)" {
    RESP=$(curl -s -X PUT -d "username=toto&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" ${CASSH_URL}/client)
    [ "${RESP}" == 'Create user=toto. Pending request.' ]
}


# == Update user
#
@test "CLIENT: Status pending user" {
    RESP=$(curl -s -X POST -d 'realname=test.user@domain.fr' "${CASSH_URL}/client/status" | jq .status)
    [ "${RESP}" == '"PENDING"' ]
}

@test "CLIENT: Updating user" {
    RESP=$(curl -s -X PUT -d "username=toto&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" ${CASSH_URL}/client)
    [ "${RESP}" == 'Update user=toto. Pending request.' ]
}


# == Signing
#
@test "CLIENT: Signing key without username" {
    RESP=$(curl -s -X POST ${CASSH_URL}/client)
    [ "${RESP}" == 'Error: No username option given. Update your CASSH >= 1.3.0' ]
}

@test "CLIENT: Signing key without realname" {
    RESP=$(curl -s -X POST -d 'username=testuser' ${CASSH_URL}/client)
    [ "${RESP}" == 'Error: No realname option given.' ]
}

@test "CLIENT: Signing key with no pubkey" {
    RESP=$(curl -s -X POST -d 'username=testuser&realname=test.user@domain.fr' ${CASSH_URL}/client)
    [ "${RESP}" == 'Error: No pubkey given.' ]
}

@test "CLIENT: Signing key with bad pubkey" {
    RESP=$(curl -s -X POST -d 'username=testuser&realname=test.user@domain.fr&pubkey=toto' ${CASSH_URL}/client)
    [ "${RESP}" == 'Error : Public key unprocessable' ]
}

@test "CLIENT: Signing key when wrong public key" {
    RESP=$(curl -s -X POST -d "username=testuser&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" ${CASSH_URL}/client)
    [ "${RESP}" == 'Error : User or Key absent, add your key again.' ]
}

@test "CLIENT: Signing key when PENDING status" {
    RESP=$(curl -s -X POST -d "username=testuser&realname=test.user@domain.fr&pubkey=${PUB_KEY_EXAMPLE}" ${CASSH_URL}/client)
    [ "${RESP}" == 'Status: PENDING' ]
}


# == Revokation
#
@test "ADMIN: Revoke 'toto'" {
    RESP=$(curl -s -X POST -d 'revoke=true' ${CASSH_URL}/admin/toto)
    [ "${RESP}" == 'Revoke user=toto.' ]
}

@test "ADMIN: Verify 'toto' status" {
    RESP=$(curl -s -X POST -d 'status=true' ${CASSH_URL}/admin/toto | jq .status)
    [ "${RESP}" == '"REVOKED"' ]
}

@test "CLIENT: Signing key when revoked" {
    RESP=$(curl -s -X POST -d "username=toto&realname=test.user@domain.fr&pubkey=${PUB_KEY_2_EXAMPLE}" ${CASSH_URL}/client)
    [ "${RESP}" == 'Status: REVOKED' ]
}


# == Admin Delete & active a user
#
@test "ADMIN: Delete 'toto'" {
    RESP=$(curl -s -X DELETE ${CASSH_URL}/admin/toto)
    [ "${RESP}" == 'OK' ]
}

@test "ADMIN: Active unknown user" {
    RESP=$(curl -s -X POST ${CASSH_URL}/admin/toto)
    [ "${RESP}" == "User does not exists." ]
}


# == Active a user
#
@test "ADMIN: Verify 'testuser' status" {
    RESP=$(curl -s -X POST -d 'status=true' ${CASSH_URL}/admin/testuser | jq .status)
    [ "${RESP}" == '"PENDING"' ]
}

@test "ADMIN: Active 'testuser'" {
    RESP=$(curl -s -X POST ${CASSH_URL}/admin/testuser)
    [ "${RESP}" == "Active user=testuser. SSH Key active but need to be signed." ]
}

@test "ADMIN: Re-active testuser" {
    RESP=$(curl -s -X POST ${CASSH_URL}/admin/testuser)
    [ "${RESP}" == "user=testuser already active. Nothing done." ]
}

@test "CLIENT: Signing key for reactivated testuser" {
    curl -s -X POST -d "username=testuser&realname=test.user@domain.fr&pubkey=${PUB_KEY_EXAMPLE}" ${CASSH_URL}/client > tmp/test-cert
    run ssh-keygen -L -f tmp/test-cert
    [ "${status}" -eq 0 ]
}


# == Cleanup
#
@test "ADMIN: Delete 'testuser'" {
    RESP=$(curl -s -X DELETE ${CASSH_URL}/admin/testuser)
    [ "${RESP}" == 'OK' ]
}

