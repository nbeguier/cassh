#!/usr/bin/env bash
#
# To be installed as ~/.local/bin/cassh
#

# == Vars
#
# Docker Hub
REGISTRY='leboncoin'
IMAGE_NAME='cassh'
IMAGE_VERSION="${CASSH_VERSION:-latest}"

CASSH_CONFIG=${CASSH_CONFIG:-${HOME}/.cassh}


# == Bash options
#
set -o nounset


# == Run
#
LDAP_PASSWORD=$(zenity --password --title="CASSH - sign" --text="Enter your AD/LDAP password" --timeout=30 2>/dev/null)

OUTPUT=$(
docker run --rm -i \
  --log-driver="none" \
  -u $(id -u) \
  -e HOME=${HOME} \
  --volume=${CASSH_CONFIG}:${HOME}/.cassh:ro \
  --volume=${HOME}/.ssh:${HOME}/.ssh \
  --workdir=${HOME} \
  ${REGISTRY}/${IMAGE_NAME}:${IMAGE_VERSION} "$@" 2>/dev/null <<< $(echo $LDAP_PASSWORD)
)

if [[ $? -eq 0 ]]; then
  zenity --info \
         --title="CASSH - sign"\
         --text "${OUTPUT}"
else
  zenity --error \
         --title="CASSH - sign"\
         --text "${OUTPUT}"
fi
