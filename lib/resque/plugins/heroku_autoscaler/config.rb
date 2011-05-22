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

        attr_writer :heroku_user
        def heroku_user
          @heroku_user || ENV['HEROKU_USER']
        end

        attr_writer :heroku_pass
        def heroku_pass
          @heroku_pass || ENV['HEROKU_PASS']
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

        def reset
          @scaling_disabled = false
          @new_worker_count = Proc.new {|pending| pending >0 ? 1 : 0}
        end
      end
    end
  end
end