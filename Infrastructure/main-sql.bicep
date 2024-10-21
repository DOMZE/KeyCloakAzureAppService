@description('The location where the resources will be deployed. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('The name of the sql server')
param sqlServerName string

@description('The administrator login for the sql server')
@secure()
param administratorUsername string

@description('The administrator password for the sql server')
@secure()
param administratorPassword string

@description('The object id in entra of the group that will manage the sql server. Leave blank to disable.')
param entraIdAdministratorsGroupId string = ''

var administrators = entraIdAdministratorsGroupId == '' ? {} : {
    // allow classic sql username/password
    azureADOnlyAuthentication: true
    login: 'SQLServerEntraIDAdministrators'
    principalType: 'Group'
    sid: entraIdAdministratorsGroupId
    tenantId: subscription().tenantId
  }

module sqlServer 'br/public:avm/res/sql/server:0.8.0' = {
  name: 'serverDeployment'
  params: {
    name: sqlServerName
    location: location
    administrators: administrators
    administratorLogin: administratorUsername
    administratorLoginPassword: administratorPassword
    // seem to have a bug, that the maxSizeBytes is not being overriden
    // databases: [
    //   {
    //     name: 'keycloak'
    //     collation: 'SQL_Latin1_General_CP1_CI_AS'
    //     // see https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-single-databases?view=azuresql
    //     skuName: 'Standard'
    //     skuTier: 'Standard'
    //     skuSize: 'S1'
    //     maxSizeBytes: 268435456000
    //   }
    // ]
    firewallRules: [
      {
        endIpAddress: '0.0.0.0'
        name: 'AllowAllWindowsAzureIps'
        startIpAddress: '0.0.0.0'
      }
    ]
  }
}

resource sqlServerDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  name: '${sqlServerName}/keycloak'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 268435456000
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
  }
  dependsOn: [
    sqlServer
  ]
}


