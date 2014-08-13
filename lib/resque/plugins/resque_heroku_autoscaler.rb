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
				queued = Resque.redis.get('enqueued').to_i
				Resque.redis.set('enqueued', queued + 1)
				log("\nScaling Resque Worker - after_enqueue_scale_workers_up | queued = #{queued}")
				calculate_and_set_worker_dynos
			end

			def after_perform_scale_workers(*args)
				queued = Resque.redis.get('enqueued').to_i
				Resque.redis.set('enqueued', queued - 1)
				log("\nScaling Resque Worker - after_perform_scale_workers | queued = #{queued}")
				calculate_and_set_worker_dynos(-1)
			end

			def on_failure_scale_workers(*args)
				queued = Resque.redis.get('enqueued').to_i
				Resque.redis.set('enqueued', queued - 1)
				log("\nScaling Resque Worker - on_failure_scale_workers | queued = #{queued}")
				calculate_and_set_worker_dynos(-1)
			end

		private

			def calculate_and_set_worker_dynos(post_adjust=0)
				if config.scaling_allowed?
					pending = Resque.info[:pending]
					working = Resque.info[:working]  + post_adjust
					log("\nScaling Resque Worker - p:#{pending} wkrs:#{ Resque.info[:workers]}, wing:#{working}")
					if (current_worker_dynos == 0)
						if (pending > 0)
							scale(1, 0)
						elsif (Resque.redis.get('enqueued').to_i > 0)
							scale(1, 0)
						end
					else
						#wait_for_task_or_scale
						if true #time_to_scale?
							new_dyno_count = config.new_worker_dyno_count(pending, Resque.info[:workers], working)
							scale(new_dyno_count)
						end
					end
				end
			end

			def scale(new_dyno_count, cwd=nil)
				cwd = current_worker_dynos if cwd.nil?
				log("\nScaling Resque Worker - new_dyno_count = |#{new_dyno_count}| current dynos = #{cwd}")

				return nil if new_dyno_count == 0

				if new_dyno_count.nil?
					send_heroku_kill_all_to_min_workers
				elsif new_dyno_count == 1
					send_heroku_change_workers (cwd + 1)
				elsif new_dyno_count == -1
					if (cwd - 1 == 0) && (Resque.redis.get('enqueued').to_i != 0)
						#skip
					else
						send_heroku_change_workers (cwd - 1)
					end
				end
				Resque.redis.set('last_scaled', Time.now)
			end

			def send_heroku_kill_all_to_min_workers
				log("\nScaling Resque Worker- send_heroku_kill_all_to_min_workers")
				heroku_api.formation.update(config.heroku_app, 'worker', {'quantity' => config.min_worker_dynos })
			end

			def send_heroku_change_workers num
				if num <= config.max_worker_dynos
					log("\nScaling Resque Worker- send_heroku_change_workers #{num}")
					heroku_api.formation.update(config.heroku_app, 'worker', {'quantity' => num })
				else
					log("\nScaling Resque Worker- max worker limit hit #{num}")
				end
			end

			def current_worker_dynos
				q = heroku_api.dyno.list(config.heroku_app)
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


			def wait_for_task_or_scale
				if Resque.info[:pending] == 0 || !time_to_scale?
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
