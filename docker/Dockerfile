FROM openjdk:11.0.7-jdk-slim-buster

### ------------------------- base ------------------------- ###
# Install packages necessary
# procps : for 'free' command
# iputils-ping : for 'ping' command
RUN apt-get update \
    && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl jsvc unzip procps iputils-ping \
    && apt autoremove -y && rm -rf /var/lib/apt/lists/*

# Set the timezone
ENV TZ Europe/Paris
RUN echo "Europe/Paris" > /etc/timezone \
    && rm /etc/localtime && ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata

# Create a user and group used to launch processes
# The user ID 1000 is the default for the first "regular" user on Fedora/RHEL,
# so there is a high chance that this ID will be equal to the current user
# making it easier to use volumes (no permission issues)
RUN groupadd -r jboss -g 2002 \
    && useradd -u 2002 -r -g jboss -m -d /opt/jboss -s /sbin/nologin -c "JBoss user" jboss \
    && chmod 755 /opt/jboss

# Set the working directory to jboss' user home directory
WORKDIR /opt/jboss

### ------------------------- base-end ------------------------- ###


### ------------------------- Keycloak ------------------------- ###
# Ref: https://github.com/keycloak/keycloak-containers/blob/10.0.2/server/Dockerfile

ENV KEYCLOAK_VERSION 10.0.2
ENV JDBC_POSTGRES_VERSION 42.2.5

ENV LAUNCH_JBOSS_IN_BACKGROUND 1
ENV PROXY_ADDRESS_FORWARDING false
ENV JBOSS_HOME /opt/jboss/keycloak
ENV LANG en_US.UTF-8

ARG KEYCLOAK_DIST=https://downloads.jboss.org/keycloak/$KEYCLOAK_VERSION/keycloak-$KEYCLOAK_VERSION.tar.gz

ADD tools /opt/jboss/tools
RUN /opt/jboss/tools/install-keycloak.sh

USER jboss
WORKDIR ${JBOSS_HOME}

EXPOSE 8080
EXPOSE 8443

ENTRYPOINT [ "/opt/jboss/tools/docker-entrypoint.sh" ]

CMD ["-b", "0.0.0.0"]
