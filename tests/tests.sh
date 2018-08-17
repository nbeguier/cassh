#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail


SCRIPT_NAME=$(basename $(readlink -f ${BASH_SOURCE[0]}))
TEST_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))


echo "===> ${SCRIPT_NAME}: START"
pushd "${TEST_DIR}"
    echo "---> Tear-up"
    echo "     * init client SSH Keys"
    docker-compose run test-runner /bin/bash -c "source ./helpers.bash && init"

    sleep 5s

    echo "---> Run tests"
    echo "     * Test server"
    docker-compose run test-runner /bin/bash -c "./scripts/wait-for-it.sh cassh-server:8080 --timeout=10 --strict -- ./tests_server.bats"

    #echo "     * Test cli"
    #docker-compose run test-runner /bin/bash -c "./scripts/wait-for-it.sh cassh-server:8080 --timeout=10 --strict -- ./tests_cli.bats"

    echo "---> Tear-down"
    echo "     * Delete tmp resources"
    docker-compose run test-runner /bin/bash -c "source ./helpers.bash && clean"
    echo "     * Docker-compose DOWN"
    docker-compose down --remove-orphans --volumes
popd
echo "===> ${SCRIPT_NAME}: DONE"