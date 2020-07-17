# Keycloak Docker image

Keycloak Server Docker image.



## Build a docker image

To build a keycloak docker image

    docker build -t manaty/keycloak:<tag> .



## How to use with meveo container on localhost

Run Keycloak container using [docker-compose.yml](docker-compose.yml) on localhost, and it will map keycloak server port to 8081 locally

    docker-compose up -d

Add an host entry for local keycloak server to hosts file. `/etc/hosts` in Linux system, `C:/Windows/System32/drivers/etc/hosts` in Windows system.

    127.0.0.1 kc-server

Add an environment varaible to meveo container. 

    KEYCLOAK_URL: http://kc-server:8081/auth



## Creating admin account

By default there is no admin user created so you won't be able to login to the admin console. To create an admin account
you need to use environment variables to pass in an initial username and password. This is done by running:

    docker run -e KEYCLOAK_USER=<USERNAME> -e KEYCLOAK_PASSWORD=<PASSWORD> manaty/keycloak

You can also create an account on an already running container by running:

    docker exec <CONTAINER> /opt/jboss/keycloak/bin/add-user-keycloak.sh -u <USERNAME> -p <PASSWORD>

Then restarting the container:

    docker restart <CONTAINER>



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



## Misc

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
