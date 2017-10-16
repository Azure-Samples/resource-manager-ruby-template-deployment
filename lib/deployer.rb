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

    options = {
        credentials: credentials,
        subscription_id: @subscription_id
    }
    @client = Azure::Resources::Profiles::Latest::Mgmt::Client.new(options)
  end

  # Deploy the template to a resource group
  def deploy
    # ensure the resource group is created
    params = @client.model_classes.resource_group.new.tap do |rg|
      rg.location = 'westus'
    end
    @client.resource_groups.create_or_update(@resource_group, params)

    # build the deployment from a json file template from parameters
    template = File.read(File.expand_path(File.join(__dir__, '../templates/template.json')))
    deployment = @client.model_classes.deployment.new
    deployment.properties = @client.model_classes.deployment_properties.new
    deployment.properties.template = JSON.parse(template)
    deployment.properties.mode = Azure::Resources::Profiles::Latest::Mgmt::Models::DeploymentMode::Incremental

    # build the deployment template parameters from Hash to {key: {value: value}} format
    deploy_params = DEPLOYMENT_PARAMETERS.merge(sshKeyData: @pub_ssh_key)
    deployment.properties.parameters = Hash[*deploy_params.map{ |k, v| [k,  {value: v}] }.flatten]

    # log the request and response contents of Template Deployment.
    # By default, ARM does not log any content. By logging information about the request or response, you could
    # potentially expose sensitive data that is retrieved through the deployment operations.
    debug_settings = @client.model_classes.debug_setting.new
    debug_settings.detail_level = 'requestContent, responseContent'
    deployment.properties.debug_setting = debug_settings

    # put the deployment to the resource group
    @client.deployments.create_or_update(@resource_group, 'azure-sample', deployment)

    # See logged information related to the deployment operations
    operation_results = @client.deployment_operations.list(@resource_group, 'azure-sample')
    unless operation_results.nil?
      operation_results.each do |operation_result|
        puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        puts "operation_id = #{operation_result.operation_id}"
        unless operation_result.properties.nil?
          puts "provisioning_state = #{operation_result.properties.provisioning_state}"
          puts "status_code = #{operation_result.properties.status_code}"
          puts "status_message = #{operation_result.properties.status_message}"
          puts "target_resource = #{operation_result.properties.target_resource.id}" unless operation_result.properties.target_resource.nil?
          puts "request = #{operation_result.properties.request.content}" unless operation_result.properties.request.nil?
          puts "response = #{operation_result.properties.response.content}" unless operation_result.properties.response.nil?
        end
      end
    end
  end

  # delete the resource group and all resources within the group
  def destroy
    @client.resource_groups.delete(@resource_group)
  end

  def dns_prefix
    DEPLOYMENT_PARAMETERS[:dnsLabelPrefix]
  end

  def print_properties(resource)
    puts "\tProperties:"
    resource.instance_variables.sort.each do |ivar|
      str = ivar.to_s.gsub /^@/, ''
      if resource.respond_to? str.to_sym
        puts "\t\t#{str}: #{resource.send(str.to_sym)}"
      end
    end
    puts "\n\n"
  end

end