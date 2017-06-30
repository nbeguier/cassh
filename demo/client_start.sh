#!/bin/bash

figlet 'CLIENT'

echo "# ADMIN List all keys"
echo "curl http://localhost:8080/client"

echo ""

echo "# CLIENT Add new client key"
echo "# Name: toto"
echo "curl -X PUT -d @test-keys/test_key.pub http://localhost:8080/client/toto"

echo ""

echo "# ADMIN active key (but not sign)"
echo "curl http://localhost:8080/admin/toto?sign=true"
echo "# or just delete (but don't revoke)"
echo "curl -X DELETE http://localhost:8080/admin/toto"


echo ""

echo "# CLIENT Sign his key for 1 day"
echo "# Name: toto"
echo "curl -X POST -d @test-keys/test_key.pub http://localhost:8080/client/toto"

