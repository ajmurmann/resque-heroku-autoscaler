require 'resque/plugins/heroku_autoscaler/config'

module Resque
  module Plugins
    module HerokuAutoscaler
      @@heroku_client = nil

      def after_enqueue_scale_workers_up(*args)
        set_workers(Resque::Plugins::HerokuAutoscaler::Config.new_worker_count(Resque.info[:pending]))
      end

      def after_perform_scale_workers_down(*args)
        set_workers(Resque::Plugins::HerokuAutoscaler::Config.new_worker_count(Resque.info[:pending]))
      end

      def set_workers(number_of_workers)
        if number_of_workers != current_workers
          heroku_client.set_workers(Resque::Plugins::HerokuAutoscaler::Config.heroku_app, number_of_workers)
        end
      end

      def current_workers        
        heroku_client.info(Resque::Plugins::HerokuAutoscaler::Config.heroku_app)[:workers].to_i
      end

      def heroku_client
        @@heroku_client || @@heroku_client = Heroku::Client.new(Resque::Plugins::HerokuAutoscaler::Config.heroku_user,
                                                                Resque::Plugins::HerokuAutoscaler::Config.heroku_pass)
      end

      def self.config
        yield Resque::Plugins::HerokuAutoscaler::Config
      end
    end
  end
end