require 'platform-api'
require 'resque/plugins/heroku_autoscaler/config'

module Resque
	module Plugins
		module HerokuAutoscaler
			def config
				Resque::Plugins::HerokuAutoscaler::Config
			end

			def self.config
				yield Resque::Plugins::HerokuAutoscaler::Config
			end

			def after_enqueue_scale_workers_up(*args)
				if current_worker_dynos == 0
					scale(1, 0)
				else
					calculate_and_set_worker_dynos
				end
			end

			def after_perform_scale_workers(*args)
				calculate_and_set_worker_dynos
			end

			def on_failure_scale_workers(*args)
				calculate_and_set_worker_dynos
			end

		private

			def scale(new_dyno_count, cwd=nil)
				return nil if new_dyno_count == 0

				cwd = current_worker_dynos if cwd.nil?
				log("\nScaling Resque Worker - new_dyno_count = |#{new_dyno_count}| current dynos = #{cwd}")
				if new_dyno_count.nil?
					send_heroku_kill_all_to_min_workers
				elsif new_dyno_count == 1
					send_heroku_change_workers (cwd + 1)
				elsif new_dyno_count == -1
					# cant scale down yet
					# if i could find out what worker the Resque job is on
					# i could then find out what workers dont have jobs and kill those
				end
				Resque.redis.set('last_scaled', Time.now)
			end

			def send_heroku_kill_all_to_min_workers
				heroku_api.formation.update(config.heroku_app, 'worker', {'quantity' => config.min_worker_dynos })
			end

			def send_heroku_change_workers num
				if num <= config.max_worker_dynos
					heroku_api.formation.update(config.heroku_app, 'worker', {'quantity' => num })
				else
					log("\nScaling Resque Worker- max worker limit hit #{num}")
				end
			end

			def current_worker_dynos
				# ary  = heroku.formation.list(config.heroku_app)
				# wary = ary.select { |pro| pro["type"] == "worker" }
				# qary = wary.map {|a| a["quantity"] }
				# qary.sum
				q = heroku.dyno.list(config.heroku_app)
				q.sum do |d|
					if d["type"] == "worker" && d["state"] == "up"
					 	1
					else
						0
					end
				end
			end

			def heroku_api
				@heroku_api ||= PlatformAPI.connect_oauth(config.heroku_api_key)
			end

			def calculate_and_set_worker_dynos
				if config.scaling_allowed?
					wait_for_task_or_scale
					if time_to_scale?
						new_dyno_count = config.new_worker_dyno_count(Resque.info[:pending],Resque.info[:workers],Resque.info[:working])
						scale(new_dyno_count)
					end
				end
			end

			def wait_for_task_or_scale
				until Resque.info[:pending] > 0 || time_to_scale?
					Kernel.sleep(0.5)
				end
			end

			def time_to_scale?
				if Resque.redis.get('last_scaled').nil?
					Resque.redis.set('last_scaled', Time.now)
					return true
				end
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
