require 'rspec'
require 'platform-api'
require 'resque'
require 'timecop'
require 'active_support/all'
require 'resque/plugins/heroku_autoscaler/config'
require 'resque/plugins/resque_heroku_autoscaler'

RSpec.configure do |config|
  config.mock_with :rr
end
