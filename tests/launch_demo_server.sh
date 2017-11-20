#!/bin/bash

ENTRYPOINT=
MOUNT_VOL=

function usage()
{
    echo "Usage:"
    echo "$0 [-d|--debug] [-h|---help] [-s|--server_file <filepath>]"
    echo ""
    exit 0
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -s|--server_file)
    SERVER_FILE="$2"
    if ! [ -f "/${SERVER_FILE}" ]; then
        echo "Server file /${SERVER_FILE} doesn't exist."
        exit 1
    fi
    MOUNT_VOL="-v ${SERVER_FILE}:/opt/cassh/server/server.py"
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

echo 'INIT : LBC - SSH'

echo 'Starting Postgresql server'
docker run --rm -p 5432:5432 --name demo-postgres -e POSTGRES_PASSWORD=mysecretpassword postgres:latest &

sleep 10

echo "Initialize server database"
python server/init_pg.py

sleep 5

echo 'Starting CA-SSH demo server'
docker run -it --rm -p 8080:8080 ${MOUNT_VOL} ${ENTRYPOINT} nbeguier/cassh-server:latest

echo 'Stoping Postgresql server'
docker stop demo-postgres
