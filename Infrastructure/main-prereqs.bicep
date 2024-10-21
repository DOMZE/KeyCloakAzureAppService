@description('The location where the resources will be deployed. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('The name of the key vault')
param keyVaultName string

@description('The name of the azure container registry')
param azureContainerRegistryName string

module keyVault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: 'keyVaultDeployment'
  params: {
    name: keyVaultName
    location: location
    enableRbacAuthorization: true
    enableSoftDelete: true   
    enableVaultForDeployment: true
  }
}

module acr 'br/public:avm/res/container-registry/registry:0.5.1' = {
  name: 'acrDeployment'
  params: {
    name: azureContainerRegistryName
    location: location
    acrSku: 'Standard'
  }
}

output containerRegistryName string = acr.outputs.name
output containerRegistryResourceId string = acr.outputs.resourceId
output containerRegistryResourceGroupName string = acr.outputs.resourceGroupName
output keyVaultName string = keyVault.outputs.name
output keyVaultResourceId string = keyVault.outputs.resourceId
output keyVaultResourceGroupName string = keyVault.outputs.resourceGroupName
