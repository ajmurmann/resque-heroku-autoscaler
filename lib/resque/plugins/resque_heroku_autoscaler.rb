require 'heroku-api'
require 'resque/plugins/heroku_autoscaler/config'

module Resque
  module Plugins
    module HerokuAutoscaler
      def config
        Resque::Plugins::HerokuAutoscaler::Config
      end

      def after_enqueue_scale_workers_up(*args)
        if !config.scaling_disabled? && \
          Resque.info[:workers] == 0 && \
          config.new_worker_count(Resque.info[:pending]) >= 1

          set_workers(1)
          Resque.redis.set('last_scaled', Time.now)
        end
      end

      def after_perform_scale_workers(*args)
        calculate_and_set_workers
      end

      def on_failure_scale_workers(*args)
        calculate_and_set_workers
      end

      def set_workers(number_of_workers)
        if number_of_workers != current_workers
          heroku_api.post_ps_scale(config.heroku_app, 'worker', number_of_workers)
        end
      end

      def current_workers
        heroku_api.get_ps(config.heroku_app).body.count {|p| p['process'].match(/worker\.\d+/) }
      end

      def heroku_api
        @heroku_api ||= ::Heroku::API.new(api_key: config.heroku_api_key)
      end

      def self.config
        yield Resque::Plugins::HerokuAutoscaler::Config
      end

      def calculate_and_set_workers
        unless config.scaling_disabled?
          wait_for_task_or_scale
          if time_to_scale?
            scale
          end
        end
      end

      private

      def scale
        new_count = config.new_worker_count(Resque.info[:pending])
        set_workers(new_count) if new_count == 0 || new_count > current_workers
        Resque.redis.set('last_scaled', Time.now)
      end

      def wait_for_task_or_scale
        until Resque.info[:pending] > 0 || time_to_scale?
          Kernel.sleep(0.5)
        end
      end

      def time_to_scale?
        (Time.now - Time.parse(Resque.redis.get('last_scaled'))) >=  config.wait_time
      end

      def log(message)
        if defined?(Rails)
          Rails.logger.info(message)
        else
          puts message
        end
      end
    end
  end
end
