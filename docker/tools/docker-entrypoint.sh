#!/bin/bash
set -eou pipefail

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [[ ${!var:-} && ${!fileVar:-} ]]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    local val="$def"
    if [[ ${!var:-} ]]; then
        val="${!var}"
    elif [[ ${!fileVar:-} ]]; then
        val="$(< "${!fileVar}")"
    fi

    if [[ -n $val ]]; then
        export "$var"="$val"
    fi

    unset "$fileVar"
}

SYS_PROPS=""

##################
# Add admin user #
##################

file_env 'KEYCLOAK_USER'
file_env 'KEYCLOAK_PASSWORD'

if [[ -n ${KEYCLOAK_USER:-} && -n ${KEYCLOAK_PASSWORD:-} ]]; then
    /opt/jboss/keycloak/bin/add-user-keycloak.sh --user "$KEYCLOAK_USER" --password "$KEYCLOAK_PASSWORD"
fi

############
# Hostname #
############

if [[ -n ${KEYCLOAK_FRONTEND_URL:-} ]]; then
    SYS_PROPS+="-Dkeycloak.frontendUrl=$KEYCLOAK_FRONTEND_URL"
fi

if [[ -n ${KEYCLOAK_HOSTNAME:-} ]]; then
    SYS_PROPS+=" -Dkeycloak.hostname.provider=fixed -Dkeycloak.hostname.fixed.hostname=$KEYCLOAK_HOSTNAME"

    if [[ -n ${KEYCLOAK_HTTP_PORT:-} ]]; then
        SYS_PROPS+=" -Dkeycloak.hostname.fixed.httpPort=$KEYCLOAK_HTTP_PORT"
    fi

    if [[ -n ${KEYCLOAK_HTTPS_PORT:-} ]]; then
        SYS_PROPS+=" -Dkeycloak.hostname.fixed.httpsPort=$KEYCLOAK_HTTPS_PORT"
    fi

    if [[ -n ${KEYCLOAK_ALWAYS_HTTPS:-} ]]; then
            SYS_PROPS+=" -Dkeycloak.hostname.fixed.alwaysHttps=$KEYCLOAK_ALWAYS_HTTPS"
    fi
fi

################
# Realm import #
################

KEYCLOAK_IMPORT=${KEYCLOAK_IMPORT:-/opt/jboss/tools/realms/meveo-realm.json}
if [[ -n ${KEYCLOAK_IMPORT:-} ]]; then
    SYS_PROPS+=" -Dkeycloak.import=$KEYCLOAK_IMPORT"
fi

########################
# JGroups bind options #
########################

if [[ -z ${BIND:-} ]]; then
    BIND=$(hostname --all-ip-addresses)
fi
if [[ -z ${BIND_OPTS:-} ]]; then
    for BIND_IP in $BIND
    do
        BIND_OPTS+=" -Djboss.bind.address=$BIND_IP -Djboss.bind.address.private=$BIND_IP "
    done
fi
SYS_PROPS+=" $BIND_OPTS"

#########################################
# Expose management console for metrics #
#########################################

if [[ -n ${KEYCLOAK_STATISTICS:-} ]] ; then
    SYS_PROPS+=" -Djboss.bind.address.management=0.0.0.0"
fi

############
# DB setup #
############

file_env 'DB_USER'
file_env 'DB_PASSWORD'
# Lower case DB_VENDOR
if [[ -n ${DB_VENDOR:-} ]]; then
  DB_VENDOR=$(echo "$DB_VENDOR" | tr "[:upper:]" "[:lower:]")
fi

# Detect DB vendor from default host names
if [[ -z ${DB_VENDOR:-} ]]; then
    if (getent hosts postgres &>/dev/null); then
        export DB_VENDOR="postgres"
    fi
fi

# Detect DB vendor from legacy `*_ADDR` environment variables
if [[ -z ${DB_VENDOR:-} ]]; then
    if (printenv | grep '^POSTGRES_ADDR=' &>/dev/null); then
        export DB_VENDOR="postgres"
    fi
fi

# Default to H2 if DB type not detected
if [[ -z ${DB_VENDOR:-} ]]; then
    export DB_VENDOR="h2"
fi

# if the DB_VENDOR is postgres then append port to the DB_ADDR
function append_port_db_addr() {
  local db_host_regex='^[a-zA-Z0-9]([a-zA-Z0-9]|-|.)*:[0-9]{4,5}$'
  IFS=',' read -ra addresses <<< "$DB_ADDR"
  DB_ADDR=""
  for i in "${addresses[@]}"; do
    if [[ $i =~ $db_host_regex ]]; then
        DB_ADDR+=$i;
     else
        DB_ADDR+="${i}:${DB_PORT}";
     fi
        DB_ADDR+=","
  done
  DB_ADDR=$(echo $DB_ADDR | sed 's/.$//') # remove the last comma
}
# Set DB name
case "$DB_VENDOR" in
    postgres)
        DB_NAME="PostgreSQL"
        if [[ -z ${DB_PORT:-} ]] ; then
          DB_PORT="5432"
        fi
        append_port_db_addr
        ;;
    h2)
        DB_NAME="Embedded H2";;
    *)
        echo "Unknown DB vendor $DB_VENDOR"
        exit 1
esac

# Append '?' in the beggining of the string if JDBC_PARAMS value isn't empty
JDBC_PARAMS=$(echo "${JDBC_PARAMS:-}" | sed '/^$/! s/^/?/')
export JDBC_PARAMS

# Convert deprecated DB specific variables
function set_legacy_vars() {
  local suffixes=(ADDR DATABASE USER PASSWORD PORT)
  for suffix in "${suffixes[@]}"; do
    local varname="$1_$suffix"
    if [[ -n ${!varname:-} ]]; then
      echo WARNING: "$varname" variable name is DEPRECATED replace with DB_"$suffix"
      export DB_"$suffix=${!varname}"
    fi
  done
}
set_legacy_vars "$(echo "$DB_VENDOR" | tr "[:upper:]" "[:lower:]")"

# Configure DB

echo "========================================================================="
echo ""
echo "  Using $DB_NAME database"
echo ""
echo "========================================================================="
echo ""

if [ "$DB_VENDOR" != "h2" ]; then
    /bin/sh /opt/jboss/tools/databases/change-database.sh $DB_VENDOR
fi

/opt/jboss/tools/x509.sh
/opt/jboss/tools/autorun.sh
/opt/jboss/tools/vault.sh

##################
# Start Keycloak #
##################

exec /opt/jboss/keycloak/bin/standalone.sh $SYS_PROPS $@
exit $?
