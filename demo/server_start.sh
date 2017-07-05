#!/bin/bash

echo 'START : LBC - SSH'

echo 'Starting server'
python server/server.py --ca $1
