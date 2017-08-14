#!/bin/bash

echo 'INIT : LBC - SSH'

echo 'Starting Postgresql server'
docker run --rm -p 5432:5432 --name demo-postgres -e POSTGRES_PASSWORD=mysecretpassword postgres:latest &

sleep 10

echo "Initialize server database"
python server/init_pg.py

sleep 5

echo 'Starting CA-SSH demo server'
docker run -it --rm -p 8080:8080 nbeguier/cassh-server:latest

echo 'Stoping Postgresql server'
docker stop demo-postgres
