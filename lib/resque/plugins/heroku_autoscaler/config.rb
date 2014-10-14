module Resque
  module Plugins
    module HerokuAutoscaler
      module Config
        extend self

        @scaling_disabled = false

        attr_writer :scaling_disabled
        def scaling_disabled?
          @scaling_disabled
        end

        @new_worker_count = Proc.new {|pending| pending >0 ? 1 : 0}
        @exception_handler = Proc.new do |exception|
          p exception
          puts exception.backtrace
        end

        attr_writer :heroku_api_key
        def heroku_api_key
          @heroku_api_key || ENV['HEROKU_API_KEY']
        end

        attr_writer :heroku_app
        def heroku_app
          @heroku_app || ENV['HEROKU_APP']
        end

        attr_writer :wait_time
        def wait_time
          @wait_time || 60
        end

        def new_worker_count(pending=nil, *payload, &calculate_count)
          if calculate_count
            @new_worker_count = calculate_count
          else
            @new_worker_count.call(pending, *payload)
          end
        end

        def exception_handler(exception=nil, &new_handler)
          if new_handler
            @exception_handler = new_handler
          else
            @exception_handler.call exception
          end
        end

        attr_writer :api_exceptions
        def api_exceptions
          @api_exceptions || [Excon::Errors::Error, Heroku::API::Errors::ErrorWithResponse]
        end

        def reset
          @scaling_disabled = false
          @new_worker_count = Proc.new {|pending| pending >0 ? 1 : 0}
        end
      end
    end
  end
end
