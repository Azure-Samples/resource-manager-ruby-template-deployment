# encoding: utf-8
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.

$: << File.expand_path('../lib')
require 'vcr'
require 'dotenv'
require 'climate_control'
Dotenv.load(File.expand_path(File.join(__dir__, '../.env')))

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.configure_rspec_metadata!
  c.allow_http_connections_when_no_cassette = true
  c.default_cassette_options = {:record => :once, :allow_playback_repeats => true}
  c.hook_into :faraday

  c.filter_sensitive_data('<AZURE_TENANT_ID>') { ENV['AZURE_TENANT_ID'] }
  c.filter_sensitive_data('<AZURE_CLIENT_ID>') { ENV['AZURE_CLIENT_ID'] }
  c.filter_sensitive_data('<AZURE_CLIENT_SECRET>') { ENV['AZURE_CLIENT_SECRET'] }
  c.filter_sensitive_data('<AZURE_SUBSCRIPTION_ID>') { ENV['AZURE_SUBSCRIPTION_ID'] }

  # This will be overridden with dummy values when running in travis-ci
  if ENV['CI']
    ENV['AZURE_TENANT_ID'] = '11111111-1111-1111-1111-111111111111'
    ENV['AZURE_CLIENT_ID'] = '11111111-1111-1111-1111-111111111111'
    ENV['AZURE_CLIENT_SECRET'] = 'SECRET'
    ENV['AZURE_SUBSCRIPTION_ID'] = '11111111-1111-1111-1111-111111111111'
    ENV['RETRY_TIMEOUT'] = '0'
  end

  c.before_record do |interaction|
    interaction.request.headers.delete('authorization')
    interaction.response.body.sub!(/\"access_token\":\".*\"}$/, '"access_token":"<ACCESS_TOKEN>"}')
    # Reduce number of interaction by ignoring 'InProgress' operations
    if interaction.request.uri =~ /^https:\/\/management.azure.com\/subscriptions\/<AZURE_SUBSCRIPTION_ID>\/operationresults\/.*/
      if interaction.response.status.code == 202
        interaction.ignore!
      end
    elsif interaction.request.uri =~ /^https:\/\/management.azure.com\/subscriptions\/<AZURE_SUBSCRIPTION_ID>\/providers\/Microsoft.Storage\/operations\/.*/ then
      if interaction.response.status.code == 202
        interaction.ignore!
      end
    end

    # Override the 'Retry-After' header before recording cassette to speed-up
    unless interaction.response.nil?
      if !interaction.response.headers['Retry-After'].nil?
        interaction.response.headers['Retry-After'] = '1'
      elsif !interaction.response.headers['retry-after'].nil?
        interaction.response.headers['retry-after'] = '1'
      end
    end
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed

  config.around(:each) do |example|
    options = example.metadata[:vcr] || {}
    if options[:record] == :skip
      VCR.turned_off(&example)
    else
      name = example.metadata[:description].gsub(/\s+/,'_').gsub(/\./,'/').gsub(/[^\w\/]+/, '_').gsub(/\/$/, '')
      VCR.use_cassette(name, options, &example)
    end
  end
end
