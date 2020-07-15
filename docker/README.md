# Keycloak Docker image

Keycloak Server Docker image.



## Build a docker image

To build a keycloak docker image

    docker build -t manaty/keycloak:<tag> .



## Usage

To boot in standalone mode

    docker run manaty/keycloak



## Expose on localhost

To be able to open Keycloak on localhost map port 8080 locally

    docker run -p 8080:8080 manaty/keycloak



## Creating admin account

By default there is no admin user created so you won't be able to login to the admin console. To create an admin account
you need to use environment variables to pass in an initial username and password. This is done by running:

    docker run -e KEYCLOAK_USER=<USERNAME> -e KEYCLOAK_PASSWORD=<PASSWORD> manaty/keycloak

You can also create an account on an already running container by running:

    docker exec <CONTAINER> /opt/jboss/keycloak/bin/add-user-keycloak.sh -u <USERNAME> -p <PASSWORD>

Then restarting the container:

    docker restart <CONTAINER>

### Providing the username and password via files

By appending `_FILE` to the two environment variables used above (`KEYCLOAK_USER_FILE` and `KEYCLOAK_PASSWORD_FILE`),
the information can be provided via files instead of plain environment variable values.
The configuration and secret support in Docker Swarm is a perfect match for this use case. 


## Importing a realm

To create an admin account and import a previously exported realm run:

    docker run -e KEYCLOAK_USER=<USERNAME> -e KEYCLOAK_PASSWORD=<PASSWORD> \
        -e KEYCLOAK_IMPORT=/tmp/example-realm.json -v /tmp/example-realm.json:/tmp/example-realm.json manaty/keycloak


## Exporting a realm

If you want to export a realm that you have created/updated, on an instance of Keycloak running within a docker container. You'll need to ensure the container running Keycloak has a volume mapped. 
For example you can start Keycloak via docker with: 

	docker run -d -p 8180:8080 -e KEYCLOAK_USER=admin -e \
	KEYCLOAK_PASSWORD=admin -v $(pwd):/tmp --name kc \
	manaty/keycloak

You can then get the export from this instance by running (notice we use `-Djboss.socket.binding.port-offset=100` so that the export runs on a different port than Keycloak itself):

	docker exec -it kc /opt/jboss/keycloak/bin/standalone.sh \
	-Djboss.socket.binding.port-offset=100 -Dkeycloak.migration.action=export \
	-Dkeycloak.migration.provider=singleFile \
	-Dkeycloak.migration.realmName=my_realm \
	-Dkeycloak.migration.usersExportStrategy=REALM_FILE \
	-Dkeycloak.migration.file=/tmp/my_realm.json

There is more detail on the options you can user for export functionality on Keycloak's main documentation site at: [Export and Import](https://www.keycloak.org/docs/latest/server_admin/index.html#_export_import)



## Adding a custom theme

To add a custom theme extend the Keycloak image add the theme to the `/opt/jboss/keycloak/themes` directory.

To set the welcome theme, use the following environment value :

* `KEYCLOAK_WELCOME_THEME`: Specify the theme to use for welcome page (must be non empty and must match an existing theme name)

To set your custom theme as the default global theme, use the following environment value :
* `KEYCLOAK_DEFAULT_THEME`: Specify the theme to use as the default global theme (must match an existing theme name, if empty will use keycloak)


## Adding a custom provider

To add a custom provider extend the Keycloak image and add the provider to the `/opt/jboss/keycloak/standalone/deployments/`
directory.


## Running custom scripts on startup

**Warning**: Custom scripts have no guarantees. The directory layout within the image may change at any time.

To run custom scripts on container startup place a file in the `/opt/jboss/startup-scripts` directory.

Two types of scripts are supported:

* WildFly `.cli` [scripts](https://docs.jboss.org/author/display/WFLY/Command+Line+Interface). In most of the cases, the scripts should operate in [offline mode](https://wildfly.org/news/tags/CLI/) (using `embed-server` instruction). 

* Any executable (`chmod +x`) script

Scripts are ran in alphabetical order.

### Adding custom script using Dockerfile

A custom script can be added by creating your own `Dockerfile`:

```
FROM manaty/keycloak
COPY custom-scripts/ /opt/jboss/startup-scripts/
```

### Adding custom script using volumes

A single custom script can be added as a volume: `docker run -v /some/dir/my-script.cli:/opt/jboss/startup-scripts/my-script.cli`
Or you can volume the entire directory to supply a directory of scripts.

Note that when combining the approach of extending the image and `volume`ing the entire directory, the volume will override
all scripts shipped in the image.


## Misc

### Specify frontend base URL

To set a fixed base URL for frontend requests use the following environment value (this is highly recommended in production):

* `KEYCLOAK_FRONTEND_URL`: Specify base URL for Keycloak (optional, default is retrieved from request)

### Specify log level

There are two environment variables available to control the log level for Keycloak:

* `KEYCLOAK_LOGLEVEL`: Specify log level for Keycloak (optional, default is `INFO`)
* `ROOT_LOGLEVEL`: Specify log level for underlying container (optional, default is `INFO`)

Supported log levels are `ALL`, `DEBUG`, `ERROR`, `FATAL`, `INFO`, `OFF`, `TRACE` and `WARN`.

Log level can also be changed at runtime, for example (assuming docker exec access):

    ./keycloak/bin/jboss-cli.sh --connect --command='/subsystem=logging/console-handler=CONSOLE:change-log-level(level=DEBUG)'
    ./keycloak/bin/jboss-cli.sh --connect --command='/subsystem=logging/root-logger=ROOT:change-root-log-level(level=DEBUG)'
    ./keycloak/bin/jboss-cli.sh --connect --command='/subsystem=logging/logger=org.keycloak:write-attribute(name=level,value=DEBUG)'

### Enabling proxy address forwarding

When running Keycloak behind a proxy, you will need to enable proxy address forwarding.

    docker run -e PROXY_ADDRESS_FORWARDING=true manaty/keycloak

### Setting up TLS(SSL)

Keycloak image allows you to specify both a private key and a certificate for serving HTTPS. In that case you need to provide two files:

* tls.crt - a certificate
* tls.key - a private key

Those files need to be mounted in `/etc/x509/https` directory. The image will automatically convert them into a Java keystore and reconfigure Wildfly to use it.

It is also possible to provide an additional CA bundle and setup Mutual TLS this way. In that case, you need to mount an additional volume (or multiple volumes) to the image. These volumes should contain all necessary `crt` files. The final step is to configure the `X509_CA_BUNDLE` environment variable to contain a list of the locations of the various CA certificate bundle files specified before, separated by space (` `). In case of an OpenShift environment, that could be `/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt /var/run/secrets/kubernetes.io/serviceaccount/ca.crt`.
