require 'spec_helper'
require 'deployer'

describe Deployer do
  let(:subcription_id) { 'subscription_id' }
  let(:resource_group) { 'falling-dust-38' }

  context 'without credential environment vars set' do
    before(:each) do
      @env_clone = ENV.clone
      %w(AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET).each do |key|
        ENV[key] = nil
      end
    end

    after(:each) do
      @env_clone.keys.each do |key|
        ENV[key] = @env_clone[key]
      end
    end

    it 'should raise error that the Tenant id was not specified' do
      expect{ described_class.new(subcription_id, resource_group, __FILE__) }.to raise_error(ArgumentError, 'Tenant id cannot be nil')
    end
  end

  context 'with credentials set' do
    before(:each) do
      @env_clone = ENV.clone
      ENV['AZURE_TENANT_ID'] = 'tenant_id'
      ENV['AZURE_CLIENT_ID'] = 'client_id'
      ENV['AZURE_CLIENT_SECRET'] = 'client_secret'
    end

    after(:each) do
      @env_clone.keys.each do |key|
        ENV[key] = @env_clone[key]
      end
    end

    it 'should raise an exception if pub ssh_key does not exist' do
      expect{ described_class.new(subcription_id, resource_group, 'blah/foo/bar.pub') }.to raise_error(ArgumentError, 'The path: blah/foo/bar.pub does not exist.')
    end
  end

  describe '#deploy' do
    before(:each) do
      pub_path = File.expand_path(File.join(__dir__, '../fixtures/id_rsa.pub'))
      @deployer = described_class.new(ENV['AZURE_SUBSCRIPTION_ID'], resource_group, pub_path)
    end

    after(:each) do
      @deployer.destroy if @deployer
    end

    it 'the deployment should not be nil' do
      expect(@deployer.deploy).not_to be_nil
    end
  end

end