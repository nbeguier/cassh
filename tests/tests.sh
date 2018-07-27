#!/usr/bin/env bash

#set -o errexit
set -o nounset
#set -o pipefail



SCRIPT_NAME=$(basename $(readlink -f ${BASH_SOURCE[0]}))
TEST_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))


echo "===> Tear-up testing env"
pushd $TEST_DIR
    echo "     * Create CASSH-server SSH Keys"
    mkdir -p tmp/test-keys \
    && ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -f tmp/test-keys/id_rsa_ca \
    && ssh-keygen -k -f tmp/test-keys/revoked-keys

    echo "     * Docker-compose"
    docker-compose up -d && sleep 10s 

    echo "===> Run tests"
    ./tests.bats

    echo "===> Tear-down"
    rm -rvf tmp/
    docker-compose down --remove-orphans
popd