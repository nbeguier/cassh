#!/bin/bash

echo 'INIT : LBC - SSH'

echo 'Downloading last version of Postgresql'
docker pull postgres

echo 'Starting Postgresql server'
docker run --rm -p 5432:5432 --name some-postgres -e POSTGRES_PASSWORD=mysecretpassword postgres &

sleep 10

echo "Initialize server database"
python server/init_pg.py
