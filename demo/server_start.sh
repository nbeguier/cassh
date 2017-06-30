#!/bin/bash

figlet 'START : LBC - SSH'

echo "Starting server"
python server/server.py $1

