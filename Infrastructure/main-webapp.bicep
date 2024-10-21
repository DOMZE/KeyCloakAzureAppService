@description('The location where the resources will be deployed. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('The name of the app service plan')
param appServicePlanName string

@description('The name of the key vault that will store the secrets for the app service configuration')
param keyVaultName string

@description('The name of the resource group where the key vault is located')
param keyVaultResourceGroupName string

@description('The name of the container registry that contains the images for the app service')
param containerRegistryName string

@description('The name of the resource group where the azure container registry is located')
param containerRegistryResourceGroupName string

@description('The name of the container image to deploy to the app service. Should be in the format <registry-name>.azurecr.io/<image-name>:<tag>')
param containerImageName string

@description('The sku of the app service plan. Defaults to P1v3.')
@allowed([
  'B2'
  'B3'
  'P1v3'
  'P1mv3'
  'P2v3'
  'P2mv3'
  'P3v3'
  'P3mv3'
  'P4mv3'
  'P5mv3'
])
param appServicePlanSku string = 'P1v3'

@description('The name of the app service')
param appServiceName string

@description('The fully qualified domain name of the sql server, i.e. <sql-server-name>.database.windows.net')
param sqlServerFQDN string

resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
  scope: (resourceGroup(keyVaultResourceGroupName))
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: containerRegistryName
  scope: (resourceGroup(containerRegistryResourceGroupName))
}

var rbacRoles = loadJsonContent('builtin-roles.json')

module appServicePlan 'br/public:avm/res/web/serverfarm:0.2.3' = {
  name: 'appServicePlanDeployment'
  params: {
    name: appServicePlanName
    location: location
    skuName: appServicePlanSku
    kind: 'Linux'
    zoneRedundant: false
    reserved: true
  }
}

module webApp 'br/public:avm/res/web/site:0.9.0' = {
  name: 'webAppDeployment'
  params: {
    name: appServiceName
    location: location
    serverFarmResourceId: appServicePlan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    kind: 'app,linux,container'
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerImageName}'
      // remove https routing within app service -> container (with --proxy=edge)
      // see https://www.keycloak.org/server/reverseproxy
      appCommandLine: 'start --proxy=edge --optimized'
    }
  }
}

module webAppToKeyVaultRoleAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  name: 'resourceRoleAssignmentWebAppToKeyVaultDeployment'
  params: {
    principalId: webApp.outputs.systemAssignedMIPrincipalId
    resourceId: keyVault.id
    roleDefinitionId: rbacRoles.KeyVaultSecretsUser
    principalType: 'ServicePrincipal'
  }
}

module webAppToAcrRoleAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  name: 'resourceRoleAssignmentWebAppToAcrDeployment'
  params: {
    // Required parameters
    principalId: webApp.outputs.systemAssignedMIPrincipalId
    resourceId: containerRegistry.id
    roleDefinitionId: rbacRoles.ContainersAcrPull
    principalType: 'ServicePrincipal'
  }
}

resource webAppAppSettingsConfigs 'Microsoft.Web/sites/config@2023-12-01' = {
  name: '${appServiceName}/appsettings'
  properties: {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
    WEBSITES_CONTAINER_START_TIME_LIMIT: 180
    WEBSITES_PORT: 8080
    KC_DB: 'mssql'
    // for reference only, in case you do not use managed identity
    // KC_DB_URL: 'jdbc:sqlserver://${sqlServerFQDN}:1433;database=keycloak;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;'
    // KC_DB_USERNAME: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/keycloak-sql-username/)'
    // KC_DB_PASSWORD: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/keycloak-sql-password/)'
    KC_DB_URL: 'jdbc:sqlserver://${sqlServerFQDN}:1433;database=keycloak;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;authentication=ActiveDirectoryMSI'
    KC_HOSTNAME: webApp.outputs.defaultHostname
    KEYCLOAK_ADMIN: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/keycloak-admin-username/)'
    KEYCLOAK_ADMIN_PASSWORD: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/keycloak-admin-password/)'
  }
}

resource webAppWebConfigs 'Microsoft.Web/sites/config@2023-12-01' = {
  name: '${appServiceName}/web'
  properties: {
    acrUseManagedIdentityCreds: true
  }
  dependsOn: [
    webApp
  ]
}
