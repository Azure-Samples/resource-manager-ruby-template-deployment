require 'spec_helper'
require 'deployer'
require 'dotenv'


describe Deployer do
  let(:subcription_id) { 'subscription_id' }
  let(:resource_group) { Haikunator.haikunate(100) }

  context 'without credential environment vars set' do
    before(:each) do
      %w(AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET).each do |key|
        ENV[key] = nil
      end
    end

    it 'should raise argument error' do
      expect{ described_class.new(subcription_id, resource_group, __FILE__) }.to raise_error(ArgumentError, 'Tenant id cannot be nil')
    end
  end

  context 'with credentials set' do
    before(:each) do
      ENV['AZURE_TENANT_ID'] = 'tenant_id'
      ENV['AZURE_CLIENT_ID'] = 'client_id'
      ENV['AZURE_CLIENT_SECRET'] = 'client_secret'
    end

    it 'should raise an exception if pub ssh_key does not exist' do
      expect{ described_class.new(subcription_id, resource_group, 'blah/foo/bar.pub') }.to raise_error(ArgumentError, 'The path: blah/foo/bar.pub does not exist.')
    end
  end

  describe '#deploy' do

    before(:all) do
      Dotenv.load!(File.expand_path(File.join(__dir__, '../../.env')))
      @deployer = Deployer.new(ENV['AZURE_SUBSCRIPTION_ID'], Haikunator.haikunate(100))
      @deployment = @deployer.deploy
    end

    after(:all) {
      @deployer.destroy
    }

    it 'the deployment should not be nil' do
      @deployment.should_not be_nil
    end
  end

end