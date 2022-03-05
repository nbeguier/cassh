#!/bin/bash

IP=$1
HOSTNAME=$2

echo "${IP}      ${HOSTNAME}" >> /etc/hosts
