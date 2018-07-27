#!/usr/bin/env bats
# vim: ft=sh:sw=2:et


# Variables
load config


@test "/ping" {
    RESP=$(curl -s http://localhost:8080/ping)
    [ "${RESP}" == 'pong' ]
}

@test "/health" {
    curl -s http://localhost:8080/health > tmp/heatlth.json
    run jq .name tmp/heatlth.json
    [ "${status}" -eq 0 ]
}

@test "Status unknown user" {
    RESP=$(curl -s http://localhost:8080/client?realname=test.user@domain.fr)
    [ "${RESP}" == 'None' ]
}

@test "Add user without username" {
    RESP=$(curl -s -X PUT http://localhost:8080/client)
    [ "${RESP}" == 'Error: No username option given.' ]
}

@test "Add user with bad username" {
    RESP=$(curl -s -X PUT http://localhost:8080/client?username=test_user)
    [ "${RESP}" == "Error: Username test_user doesn't match pattern ^([a-z]+)$" ]
}

@test "Add user without realname" {
    RESP=$(curl -s -X PUT http://localhost:8080/client?username=testuser)
    [ "${RESP}" == 'Error: No realname option given.' ]
}

@test "Add user with no pubkey" {
    RESP=$(curl -s -X PUT http://localhost:8080/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Error : Public key unprocessable' ]
}

@test "Add user with bad pubkey" {
    RESP=$(curl -s -X PUT -d "toto" http://localhost:8080/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Error : Public key unprocessable' ]
}

@test "Add user" {
    RESP=$(curl -s -X PUT -d "${PUB_KEY_EXAMPLE}" http://localhost:8080/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Create user=testuser. Pending request.' ]
}

@test "add user named 'all' (should fail)" {
    RESP=$(curl -s -X PUT -d "${PUB_KEY_EXAMPLE}" http://localhost:8080/client?username=all\&realname=test.user@domain.fr)
    [ "${RESP}" == "Error: Username all doesn't match pattern ^([a-z]+)$" ]
}

@test "status pending user" {
    RESP=$(curl -s "http://localhost:8080/client?realname=test.user@domain.fr" | jq .status)
    [ "${RESP}" == '"PENDING"' ]
}

@test "add user with same realname (which is possible)" {
    RESP=$(curl -s -X PUT -d "${PUB_KEY_2_EXAMPLE}" http://localhost:8080/client?username=toto\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Create user=toto. Pending request.' ]
}

@test "updating user" {
    RESP=$(curl -s -X PUT -d "${PUB_KEY_2_EXAMPLE}" http://localhost:8080/client?username=toto\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Update user=toto. Pending request.' ]
}

@test "add user with same username (should fail)" {
    RESP=$(curl -s -X PUT -d "${PUB_KEY_EXAMPLE}" http://localhost:8080/client?username=testuser\&realname=toto123@domain.fr)
    [ "${RESP}" == 'Error : (username, realname) couple mismatch.' ]
}

@test "signing key without username" {
    RESP=$(curl -s -X POST http://localhost:8080/client)
    [ "${RESP}" == 'Error: No username option given. Update your CASSH >= 1.3.0' ]
}

@test "signing key without realname" {
    RESP=$(curl -s -X POST http://localhost:8080/client?username=testuser)
    [ "${RESP}" == 'Error: No realname option given.' ]
}

@test "signing key with no pubkey" {
    RESP=$(curl -s -X POST http://localhost:8080/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Error : Public key unprocessable' ]
}

@test "signing key with bad pubkey" {
    RESP=$(curl -s -X POST -d "toto" http://localhost:8080/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Error : Public key unprocessable' ]
}

@test "signing key when wrong public key" {
    RESP=$(curl -s -X POST -d "${PUB_KEY_2_EXAMPLE}" http://localhost:8080/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Error : User or Key absent, add your key again.' ]
}

@test "signing key when PENDING status" {
    RESP=$(curl -s -X POST -d "${PUB_KEY_EXAMPLE}" http://localhost:8080/client?username=testuser\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Status: PENDING' ]
}

@test "admin revoke 'toto'" {
    RESP=$(curl -s http://localhost:8080/admin/toto?revoke=true)
    [ "${RESP}" == 'Revoke user=toto.' ]
}

@test "admin verify 'toto' status" {
    RESP=$(curl -s http://localhost:8080/admin/toto?status=true | jq .status)
    [ "${RESP}" == '"REVOKED"' ]
}

@test "signing key when revoked" {
    RESP=$(curl -s -X POST -d "${PUB_KEY_2_EXAMPLE}" http://localhost:8080/client?username=toto\&realname=test.user@domain.fr)
    [ "${RESP}" == 'Status: REVOKED' ]
}

@test "delete 'toto'" {
    RESP=$(curl -s -X DELETE http://localhost:8080/admin/toto)
    [ "${RESP}" == 'OK' ]
}

@test "admin active unknown user" {
    RESP=$(curl -s http://localhost:8080/admin/toto)
    [ "${RESP}" == "User 'toto' does not exists." ]
}

@test "admin verify 'testuser' status" {
    RESP=$(curl -s http://localhost:8080/admin/testuser?status=true | jq .status)
    [ "${RESP}" == '"PENDING"' ]
}

@test "admin active testuser" {
    RESP=$(curl -s http://localhost:8080/admin/testuser)
    [ "${RESP}" == "Active user=testuser. SSH Key active but need to be signed." ]
}

@test "admin re-active testuser" {
    RESP=$(curl -s http://localhost:8080/admin/testuser)
    [ "${RESP}" == "user=testuser already active. Nothing done." ]
}

@test "signing key" {
    curl -s -X POST -d "${PUB_KEY_EXAMPLE}" 'http://localhost:8080/client?username=testuser\&realname=test.user@domain.fr' > tmp/test-cert

    run ssh-keygen -L -f tmp/test-cert
    [ "${status}" -eq 0 ]
}

@test "delete 'testuser'" {
    RESP=$(curl -s -X DELETE http://localhost:8080/admin/testuser)
    [ "${RESP}" == 'OK' ]
}

