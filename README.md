---
services: azure-resource-manager
platforms: ruby
author: devigned
---

[![Build Status](https://travis-ci.org/Azure-Samples/resource-manager-ruby-template-deployment.svg?branch=master)](https://travis-ci.org/Azure-Samples/resource-manager-ruby-template-deployment)

# Deploy an SSH Enabled VM with a Template in Ruby

This sample explains how to use Azure Resource Manager templates to deploy your Resources to Azure. It shows how to
deploy your Resources by using the Azure SDK for Ruby.

When deploying an application definition with a template, you can provide parameter values to customize how the
resources are created. You specify values for these parameters either inline or in a parameter file.

## Incremental and complete deployments

By default, Resource Manager handles deployments as incremental updates to the resource group. With incremental
deployment, Resource Manager:

- leaves unchanged resources that exist in the resource group but are not specified in the template
- adds resources that are specified in the template but do not exist in the resource group
- does not re-provision resources that exist in the resource group in the same condition defined in the template

With complete deployment, Resource Manager:

- deletes resources that exist in the resource group but are not specified in the template
- adds resources that are specified in the template but do not exist in the resource group
- does not re-provision resources that exist in the resource group in the same condition defined in the template

You specify the type of deployment through the Mode property, as shown in the examples below.

## Deploy with Ruby

In this sample, we are going to deploy a resource template which contains an Ubuntu 16.04 LTS virtual machine using
ssh public key authentication, storage account, and virtual network with public IP address. The virtual network
contains a single subnet with a single network security group rule which allows traffic on port 22 for ssh with a single
network interface belonging to the subnet. The virtual machine is a `Standard_D1` size. You can find the template
[here](https://github.com/azure-samples/resource-manager-ruby-template-deployment/blob/master/templates/template.json).

### To run this sample, do the following:

You will need to create an Azure service principal either through Azure CLI, PowerShell or the portal; gather the 
correct object IDs and authenticators; copy the deployment code; and then execute
over it, as follows:

* [Create a Service Principal](https://azure.microsoft.com/en-us/documentation/articles/resource-group-authenticate-service-principal/#authenticate-with-password---azure-cli)
  * For Azure portal, note: Tenant Id, Client Id and Client Secret
  * For Azure CLI, note: the $tentantID, $appId, and the password used when running `azure ad sp create`
  * For PowerShell, note: the $tenant, the $azureAdApplication.ApplicationId, and the $creds
* Assign the appropriate rights to your principal:, e.g. for Azuze CLI:
```
principalId=$(azure ad sp show --search exampleapp --json  | jq -r '.[0].objectId')
azure role assignment create --objectId $principalId -o Contributor -c /subscriptions/$AZURE_SUBSCRIPTION_ID/
```
* Set your environment variables:
```
export AZURE_SUBSCRIPTION_ID={your subscription id}`
export AZURE_TENANT_ID={your tenant id}
export AZURE_CLIENT_ID={your client id}
export AZURE_CLIENT_SECRET={your client secret}
```
* Clone the deployment template and execute over it:
```
git clone https://github.com/Azure-Samples/resource-manager-ruby-template-deployment.git
cd resource-manager-ruby-template-deployment
bundle install
bundle exec ruby azure_deployment.rb
```

Note: If you don't have your subscriptionId handy, run 
`export AZURE_SUBSCRIPTION_ID=$(azure account show --json | jq -r '.[0].id')`

### What is this azure_deployment.rb Doing?

The entry point for this sample is [azure_deployment.rb](https://github.com/azure-samples/resource-manager-ruby-template-deployment/blob/master/azure_deployment.rb). This script uses the deployer class
below to deploy a the aforementioned template to the subscription and resource group specified in `my_resource_group`
and `my_subscription_id` respectively. By default the script will use the ssh public key from your default ssh
location.

*Note: you must set each of the below environment variables (AZURE_TENANT_ID, AZURE_CLIENT_ID and AZURE_CLIENT_SECRET) prior to
running the script.*

``` ruby
require_relative 'lib/deployer'


# This script expects that the following environment vars are set:
#
# AZURE_TENANT_ID: with your Azure Active Directory tenant id or domain
# AZURE_CLIENT_ID: with your Azure Active Directory Application Client ID
# AZURE_CLIENT_SECRET: with your Azure Active Directory Application Secret

my_subscription_id = ENV['AZURE_SUBSCRIPTION_ID'] || '11111111-1111-1111-1111-111111111111'   # your Azure Subscription Id
my_resource_group = 'azure-ruby-deployment-sample'            # the resource group for deployment
my_pub_ssh_key_path = File.expand_path('~/.ssh/id_rsa.pub')   # the path to your rsa public key file

msg = "\nInitializing the Deployer class with subscription id: #{my_subscription_id}, resource group: #{my_resource_group}"
msg += "\nand public key located at: #{my_pub_ssh_key_path}...\n\n"
puts msg
# Initialize the deployer class
deployer = Deployer.new(my_subscription_id, my_resource_group, my_pub_ssh_key_path)

puts "Beginning the deployment... \n\n"
# Deploy the template
my_deployment = deployer.deploy

puts "Done deploying!!\n\nYou can connect via: `ssh azureSample@#{deployer.dns_prefix}.westus.cloudapp.azure.com`"

# Destroy the resource group which contains the deployment
# deployer.destroy
```

### What is this lib/deployer.rb Doing?

The [Deployer class](https://github.com/azure-samples/resource-manager-ruby-template-deployment/blob/master/lib/deployer.rb) consists of the following:

``` ruby
require 'haikunator'
require 'azure_mgmt_resources'

class Deployer
  DEPLOYMENT_PARAMETERS = {
      dnsLabelPrefix:       Haikunator.haikunate(100),
      vmName:               'azure-deployment-sample-vm'
  }

  # Initialize the deployer class with subscription, resource group and public key. The class will raise an
  # ArgumentError under two conditions, if the public key path does not exist or if there are empty values for
  # Tenant Id, Client Id or Client Secret environment variables.
  #
  # @param [String] subscription_id the subscription to deploy the template
  # @param [String] resource_group the resource group to create or update and then deploy the template
  # @param [String] pub_ssh_key_path the path to the public key to be used to authentication
  def initialize(subscription_id, resource_group, pub_ssh_key_path = File.expand_path('~/.ssh/id_rsa.pub'))
    @resource_group = resource_group
    @subscription_id = subscription_id
    raise ArgumentError.new("The path: #{pub_ssh_key_path} does not exist.") unless File.exist?(pub_ssh_key_path)
    @pub_ssh_key = File.read(pub_ssh_key_path)
    provider = MsRestAzure::ApplicationTokenProvider.new(
        ENV['AZURE_TENANT_ID'],
        ENV['AZURE_CLIENT_ID'],
        ENV['AZURE_CLIENT_SECRET'])
    credentials = MsRest::TokenCredentials.new(provider)
    @client = Azure::ARM::Resources::ResourceManagementClient.new(credentials)
    @client.subscription_id = @subscription_id
  end

  # Deploy the template to a resource group
  def deploy
    # ensure the resource group is created
    params = Azure::ARM::Resources::Models::ResourceGroup.new.tap do |rg|
      rg.location = 'westus'
    end
    @client.resource_groups.create_or_update(@resource_group, params).value!

    # build the deployment from a json file template from parameters
    template = File.read(File.expand_path(File.join(__dir__, '../templates/template.json')))
    deployment = Azure::ARM::Resources::Models::Deployment.new
    deployment.properties = Azure::ARM::Resources::Models::DeploymentProperties.new
    deployment.properties.template = JSON.parse(template)
    deployment.properties.mode = Azure::ARM::Resources::Models::DeploymentMode::Incremental

    # build the deployment template parameters from Hash to {key: {value: value}} format
    deploy_params = DEPLOYMENT_PARAMETERS.merge(sshKeyData: @pub_ssh_key)
    deployment.properties.parameters = Hash[*deploy_params.map{ |k, v| [k,  {value: v}] }.flatten]

    # put the deployment to the resource group
    @client.deployments.create_or_update(@resource_group, 'azure-sample', deployment).value!.body
  end

  # delete the resource group and all resources within the group
  def destroy
    @client.resource_groups.delete(@resource_group).value!.body
  end
end
```

The `initialize` method initializes the class with subscription, resource group and public key. The method also fetches
the Azure Active Directory bearer token, which will be used in each HTTP request to the Azure Management API. The class
will raise an ArgumentError under two conditions, if the public key path does not exist or if there are empty
values for Tenant Id, Client Id or Client Secret environment variables.

The `deploy` method does the heavy lifting of creating or updating the resource group, preparing the template,
parameters and deploying the template.

The `destroy` method simply deletes the resource group thus deleting all of the resources within that group.

Each of the above methods use the `Azure::ARM::Resources::ResourceManagementClient` class, which resides within the
[azure_mgmt_resources](https://rubygems.org/gems/azure_mgmt_resources) gem ([see the rdocs docs here](http://www.rubydoc.info/gems/azure_mgmt_resources/0.2.1)).

After the script runs, you should see something like the following in your output:

```
$ bundle exec ruby azure_deployment.rb

Initializing the Deployer class with subscription id: 11111111-1111-1111-1111-111111111111, resource group: azure-ruby-deployment-sample
and public key located at: /Users/you/.ssh/id_rsa.pub...

Beginning the deployment...

Done deploying!!

You can connect via: `ssh azureSample@damp-dew-79.westus.cloudapp.azure.com`
```

You should be able to run `ssh azureSample@{your dns value}.westus.cloudapp.azure.com` to connect to your new VM.
