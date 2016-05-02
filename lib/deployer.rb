require 'haikunator'
require 'azure_mgmt_resources'

class Deployer
  DEPLOYMENT_PARAMETERS = {
      dnsLabelPrefix:       Haikunator.haikunate(100),
      vmName:               Haikunator.haikunate(100)
  }

  attr_accessor :resource_group
  attr_accessor :subscription_id

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

  def deploy
    # ensure the resource group is created
    params = Azure::ARM::Resources::Models::ResourceGroup.new.tap do |rg|
      rg.location = location
    end
    client.resource_groups.create_or_update(name, params).value!

    # build the deployment from a json file template from parameters
    template = File.read(File.expand_path(File.join(__dir__, '../templates/template.json')))
    deployment = Azure::ARM::Resources::Models::Deployment.new
    deployment.properties = Azure::ARM::Resources::Models::DeploymentProperties.new
    deployment.properties.template = JSON.parse(template)
    deployment.properties.mode = Azure::ARM::Resources::Models::DeploymentMode::Incremental

    # build the deployment template parameters from Hash to {key: {value: value}} format
    deploy_params = DEPLOYMENT_PARAMETERS.merge(sshKeyData: @pub_ssh_key)
    deploy_params = Hash[*deploy_params.map{ |k, v| [k,  {value: v}] }.flatten]
    deployment.properties.parameters = build_parameters(deploy_params)

    # put the deployment to the resource group
    client.deployments.create_or_update(@resource_group, 'azure-sample', deployment).value!.body
  end

  def destroy
    # delete the resource group and all resources within the group
    client.resource_groups.delete(@resource_group).value!.body
  end

end