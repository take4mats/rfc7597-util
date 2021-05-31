require 'simplecov'
SimpleCov.start do
  add_filter '/.bundle/'
end
ENV['RACK_ENV'] ||= 'test'

require 'rack/test'
require 'rspec'
require_relative '../main'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Rack::Test mixin
  include Rack::Test::Methods
  def app
    MapeWebApp # need to specify your app here if you use "Modular style"
  end
end
