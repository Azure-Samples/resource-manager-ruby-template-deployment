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
[here][Template].

### To run this sample, do the following:

You will need to create an Azure service principal either through Azure CLI, PowerShell or the portal. You should gather
each the Tenant Id, Client Id and Client Secret from creating the Service Principal for use below.

- [Create a Service Principal][ServicePrincipalCreation]
- `git clone https://github.com/Azure-Samples/resource-manager-ruby-template-deployment.git`
- `cd resource-manager-ruby-template-deployment`
- `bundle install`
- `export AZURE_TENANT_ID={your tenant id}`
- `export AZURE_CLIENT_ID={your client id}`
- `export AZURE_CLIENT_SECRET={your client secret}`
- `bundle exec ruby azure_deployment.rb`

### What is this azure_deployment.rb Doing?

The entry point for this sample is [azure_deployment.rb][azure_deployment.rb]. This script uses the deployer class
below to deploy a the aforementioned template to the subscription and resource group specified in `my_resource_group`
and `my_subscription_id` respectively. By default the script will use the ssh public key from your default ssh
location.

* Note: you must set each of the below environment variables (AZURE_TENANT_ID, AZURE_CLIENT_ID and AZURE_CLIENT_SECRET) prior to running the script.*

### What is this lib/deployer.rb Doing?

The [Deployer class][Deployer class] does the following:

1. The `initialize` method initializes the class with subscription, resource group and public key. The method also fetches
the Azure Active Directory bearer token, which will be used in each HTTP request to the Azure Management API. The class
will raise an ArgumentError under two conditions, if the public key path does not exist or if there are empty
values for Tenant Id, Client Id or Client Secret environment variables.

2. The `deploy` method does the heavy lifting of creating or updating the resource group, preparing the template,
parameters and deploying the template.

3. The `destroy` method simply deletes the resource group thus deleting all of the resources within that group.

Each of thse methods use the `Azure::ARM::Resources::ResourceManagementClient` class, which resides within the
[azure_mgmt_resources][azure_mgmt_resources] gem ([see the rdocs docs here][rdocs_mgmt_resources]).

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

[Template]: https://github.com/azure-samples/resource-manager-ruby-template-deployment/blob/master/templates/template.json
[ServicePrincipalCreation]: https://azure.microsoft.com/en-us/documentation/articles/resource-group-authenticate-service-principal/#authenticate-with-password---azure-cli
[azure_deployment.rb]: https://github.com/azure-samples/resource-manager-ruby-template-deployment/blob/master/azure_deployment.rb
[Deployer class]: https://github.com/azure-samples/resource-manager-ruby-template-deployment/blob/master/lib/deployer.rb
[azure_mgmt_resources]: https://rubygems.org/gems/azure_mgmt_resources
[rdocs_mgmt_resources]: http://www.rubydoc.info/gems/azure_mgmt_resources/0.2.1
