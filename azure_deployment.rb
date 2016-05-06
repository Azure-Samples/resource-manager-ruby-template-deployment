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