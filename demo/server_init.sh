#!/bin/bash

figlet 'INIT : LBC - SSH'

echo "Starting Postgresql"
docker run --rm -p 5432:5432 --name some-postgres -e POSTGRES_PASSWORD=mysecretpassword -d postgres

sleep 5

echo "Init database"
python server/init_pg.py
