#!/bin/bash

CARRY_POSTGRES=false
ENTRYPOINT=
MOUNT_VOL=
PORT=8080

function usage()
{
    echo "Usage:"
    echo "$0 [-d|--debug] [-h|---help] [-p|--port <port>] [-s|--server_code_path <filepath>]"
    echo ""
    exit 0
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -s|--server_code_path)
    SERVER_CODE_PATH="$2"
    if ! [ -d "/${SERVER_CODE_PATH}" ]; then
        echo "Server code path /${SERVER_CODE_PATH} doesn't exist."
        exit 1
    fi
    MOUNT_VOL="-v ${SERVER_CODE_PATH}:/opt/cassh/"
    shift # past argument
    shift # past value
    ;;
    -p|--port)
    PORT="$2"
    shift # past argument
    shift # past value
    ;;
    -d|--debug)
    ENTRYPOINT='--entrypoint /bin/bash'
    shift # past argument
    ;;
    -h|--help)
    usage
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

echo 'INIT : CASSH Server'

if [ ! "$(docker ps -q -f name=demo-postgres)" ]; then
    CARRY_POSTGRES=true

    echo 'Starting Postgresql server'
    docker run --rm -p 5432:5432 --name demo-postgres -e POSTGRES_PASSWORD=mysecretpassword postgres:latest &

    sleep 10

    echo "Initialize Postgresql server"
    python tests/postgres/init_pg.py

    sleep 5
fi

echo 'Starting OpenLDAP server'
docker run --rm -d -v ${PWD}/tests/openldap/:/tmp/openldap/ -p 389:389 -p 636:636 --name demo-openldap osixia/openldap:1.3.0
sleep 3
echo 'Initialize OpenLDAP server'
docker exec demo-openldap ldapadd -x -f /tmp/openldap/add-users.ldif -D "cn=admin,dc=example,dc=org" -w admin


echo 'Starting CA-SSH demo server'
docker run -it -d --rm -p "${PORT}":8080 ${MOUNT_VOL} ${ENTRYPOINT} --name demo-cassh nbeguier/cassh-server:latest

echo "POSTGRESQL IP: $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' demo-postgres)"
echo "OPENLDAP IP: $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' demo-openldap)"
echo "CASSH IP: $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' demo-cassh)"
echo ''
echo '> /opt/cassh/src/server/server.py --config /opt/cassh/tests/cassh/cassh.conf'

docker attach demo-cassh

if $CARRY_POSTGRES; then
    echo 'Stoping Postgresql server'
    docker stop demo-postgres
fi
docker stop demo-openldap
    