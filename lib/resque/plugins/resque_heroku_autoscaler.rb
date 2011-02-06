module Resque
  module Plugins
    module HerokuAutoscaler
      @@heroku_client = nil

      def after_enqueue_scale_workers_up(*args)
        set_workers(1)
      end

      def after_perform_scale_workers_down(*args)
        set_workers(0) if Resque.info[:pending] == 0
      end

      def set_workers(number_of_workers)
        heroku_client.set_workers(ENV['HEROKU_APP'], number_of_workers)
      end

      def heroku_client
        @@heroku_client || @@heroku_client = Heroku::Client.new(ENV['HEROKU_USER'], ENV['HEROKU_PASS'])
      end
    end
  end
end