# Setup
This is the steps to deploy KeyCloak into Azure App Service along with Azure SQL. It refers to my blog post [Running KeyCloak on Azure App Service and Azure SQL using managed identities](https://www.domstamand.com/running-keycloak-on-azure-app-service-and-azure-sql-using-managed-identities/). You can also find this blog post useful: [How to push an image from docker registry to azure container registry](https://www.domstamand.com/how-to-push-an-image-from-docker-registry-to-azure-container-registry/).

## Prerequisites
* Bicep. Can be downloaded at the GitHub repo: https://github.com/Azure/bicep
* [Azure Cmdlets](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell?view=azps-12.4.0) or [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) to deploy the infrastructure. The README here makes use of the Az Cmdlets.
* A KeyCloak custom container image, containing the necessary components to run Managed Identities. You can build the container image using the Dockerfile provided.
```shell
docker build -f ./Docker/Dockerfile -t keycloak/keycloak-msi:<tag> --no-cache ./Docker
```
* A Microsoft Entra Security Group for the Azure SQL Administrators. You should be a member of that group.

## Components
* Azure KeyVault for the secrets:
    * Azure SQL admin username and password
    * Azure App Service KeyVault references for the KeyCloak admininistrator username and password
* Azure Container Registry (ACR) for the KeyCloak custom image
* Azure SQL for the datastore of KeyCloak
* Azure App Service to host the KeyCloak app

## Provision the prerequisites resources
Run the `main-prereqs.bicep`. Use the parameters file (`prereqs.params.jsonc`) to fill in the necessary values.
This will provision a KeyVault and an Azure Container Registry (ACR).<br/>
Using Az Cmdlets:
```powershell
New-AzResourceGroupDeployment -ResourceGroupName "rg-KeyCloak" -TemplateFile "./main-prereqs.bicep" -TemplateParameterFile "./params/prereqs.params.jsonc" -Verbose
```

### RBAC and secrets setup
Give yourself the [KeyVault administrator role](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#security) on the KeyVault so you can administer the KeyVault on the dataplane level.<br/>
Once done, add the following secrets:<br/>
| Secret | Description 	|
|---	|---	|
| sql-admin-username  	    | The SQL SA account username |
| sql-admin-password   	    | The SQL SA account password |
| keycloak-admin-username  	| KeyCloak admin username to login to the UI |
| keycloak-admin-password  	| KeyCloak admin password to login to the UI |

## Provision the Azure SQL Instance
Run the `main-sql.bicep`. Use the parameters file (`sql.params.jsonc`) to fill in the necessary values.<br/>
Using Az Cmdlets:
```powershell
New-AzResourceGroupDeployment -ResourceGroupName "rg-KeyCloak" -TemplateFile "./main-sql.bicep" -TemplateParameterFile "./params/sql.params.jsonc" -Verbose
```

## Provision the Azure Web App
Run the `main-sql.bicep`. Use the parameters file (`sql.params.jsonc`) to fill in the necessary values.<br/>
Using Az Cmdlets:
```powershell
New-AzResourceGroupDeployment -ResourceGroupName "rg-KeyCloak" -TemplateFile "./main-sql.bicep" -TemplateParameterFile "./params/sql.params.jsonc" -Verbose
```

## Give the proper permission to the Database to the Web App Identity
* Download SQLCMD binary from the GitHub repository [here](https://github.com/microsoft/go-sqlcmd/releases/latest).
* Run SQLCMD to connect to the database. The authentication will be interactive. Replace `<servername>` with your Azure SQL server name and `<user@upn>` with the upn in your Entra security group.
```shell
sqlcmd -S <servername>.database.windows.net -d KeyCloak -U "<user@upn>" -G -l 30 --authentication-method=ActiveDirectoryInteractive
```
* Run the following T-SQL in the SQLCMD CLI. Replace `<webappname>` with the name of your webapp:
```sql
CREATE USER [<webappname>] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [<webappname>];
ALTER ROLE db_datawriter ADD MEMBER [<webappname>];
ALTER ROLE db_ddladmin ADD MEMBER [<webappname>];
GO
```

## Restart the Web App
Since you modified the permission, restart the webapp so that the authentication can be successful.<br/>
Login with the username and password you set in the keyvault for KeyCloak.