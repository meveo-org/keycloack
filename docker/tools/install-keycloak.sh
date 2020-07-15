#!/bin/bash -e

#####################
# Download Keycloak #
#####################

echo "Keycloak from [download]: $KEYCLOAK_DIST"
cd /opt/jboss/
curl -L $KEYCLOAK_DIST | tar zx
mv /opt/jboss/keycloak-* /opt/jboss/keycloak

#####################
# Create DB modules #
#####################

mkdir -p /opt/jboss/keycloak/modules/system/layers/base/org/postgresql/jdbc/main
cd /opt/jboss/keycloak/modules/system/layers/base/org/postgresql/jdbc/main
curl -L https://repo1.maven.org/maven2/org/postgresql/postgresql/$JDBC_POSTGRES_VERSION/postgresql-$JDBC_POSTGRES_VERSION.jar > postgres-jdbc.jar
cp /opt/jboss/tools/databases/postgres/module.xml .

######################
# Configure Keycloak #
######################

cd /opt/jboss/keycloak

bin/jboss-cli.sh --file=/opt/jboss/tools/cli/standalone-configuration.cli
rm -rf /opt/jboss/keycloak/standalone/configuration/standalone_xml_history

# Create the H2 database location in advance, for docker volume mapping.
mkdir -p /opt/jboss/keycloak/standalone/data/keycloakdb

###########
# Garbage #
###########

rm -rf /opt/jboss/keycloak/standalone/tmp/auth
rm -rf /opt/jboss/keycloak/domain/tmp/auth

###################
# Set permissions #
###################

chown -R jboss:root /opt/jboss
chmod -R g+rwX /opt/jboss
