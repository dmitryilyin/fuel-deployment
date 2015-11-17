require 'rspec'
require File.join File.dirname(__FILE__), '../lib/task'
require File.join File.dirname(__FILE__), '../lib/node'
require File.join File.dirname(__FILE__), '../lib/error'
require File.join File.dirname(__FILE__), '../lib/graph'
require File.join File.dirname(__FILE__), '../lib/process'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect
    mocks.verify_partial_doubles = true
  end
end
