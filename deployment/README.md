## Deploy a new environment
Use the `deploy-environment.ps1` script

## Deploy configuration
Use the `deploy-config.ps1` script

This will upload any Superset configuration files to the Azure Storage volume which is mounted to the Superset container.

## Add a Postgres private endpoint to Superset
Use `resource-pg-connection.bicep` to deploy a new Postgres private endpoint to the Superset VNet. This allows Superset to connect to the Postgres database.