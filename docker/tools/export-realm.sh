#!/bin/bash -e

# set -o errexit
# set -o errtrace
# set -o nounset
# set -o pipefail

REALM_NAME=$1

usage() {
    echo -en "\nUsage:\n"
    echo -en "\n$0 <REALM-NAME>\n"
    exit 1
}


EXPORT_DIR=/opt/jboss/keycloak
LOG_DIR=/opt/jboss/keycloak/standalone/log

SCRIPT_NAME="$(basename ${BASH_SOURCE[0]})"
SCRIPT_NAME="${SCRIPT_NAME%.*}"  ## Without an extension
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

if [[ -z ${REALM_NAME} ]]; then
    usage
fi

EXPORT_FILE=${EXPORT_DIR}/${REALM_NAME}-realm.json

if [ -f ${EXPORT_FILE} ]; then
    rm -f ${EXPORT_FILE}
fi
if [ -f ${LOG_FILE} ]; then
    rm -f ${LOG_FILE}
fi

# If something goes wrong, this script does not run forever but times out
TIMEOUT_SECONDS=300

# Start a new keycloak instance with exporting options enabled.
# Use port offset to prevent port conflicts with the "real" keycloak instance.
timeout ${TIMEOUT_SECONDS}s \
    /opt/jboss/keycloak/bin/standalone.sh \
        -Dkeycloak.migration.action=export \
        -Dkeycloak.migration.provider=singleFile \
        -Dkeycloak.migration.realmName=${REALM_NAME} \
        -Dkeycloak.migration.usersExportStrategy=REALM_FILE \
        -Dkeycloak.migration.file=${EXPORT_FILE} \
        -Djboss.socket.binding.port-offset=99 \
    > ${LOG_FILE} &

# Grab the keycloak-export instance process id
PID="${!}"

# Wait for finishing of the export
timeout ${TIMEOUT_SECONDS}s \
    grep -m 1 "Export finished successfully" <(tail -f ${LOG_FILE})

# Stop the keycloak-export instance
kill ${PID}
