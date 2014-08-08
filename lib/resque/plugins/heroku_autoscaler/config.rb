module Resque
  module Plugins
    module HerokuAutoscaler
      module Config
        extend self

        @scaling_allowed = true

        attr_writer :scaling_allowed
        def scaling_allowed?
          @scaling_allowed
        end

        @new_worker_dyno_count = scaling_system

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

        def max_worker_dynos
          @max_workers ||= (ENV['WORKER_MAX'] || 5)
        end

        def min_worker_dynos
          @min_workers ||= (ENV['WORKER_MIN'] || 0)
        end

        def new_worker_dyno_count(pending, workers, working)
          @new_worker_dyno_count.call({ pending: pending, workers: workers, working: working })
        end

        def reset
          @scaling_allowed       = true
          @new_worker_dyno_count = scaling_system
        end

      private

        def scaling_system
          Proc.new do |data_hsh|
            pending = data_hsh[:pending].to_i
            workers = data_hsh[:workers].to_i
            working = data_hsh[:working].to_i
            if pending > 0
              if (workers - 4) < working
                1
              else
                # do nothing
                0
              end
            else
              if working == 0
                # kill all the workers
                nil
              elsif (workers > working + 8)
                -1
              else
                # do nothing
                0
              end
            end
          end
        end
      end
    end
  end
end
