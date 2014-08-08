Behavior

Improvements :

VERSION 0.3
sets a maximum number of workers off the config var
  done set the ENV['WORKER_MAX'] or it defaults to 5
has an algo for dyno scaler vs amount of workers
  done
logs or saves a ditto
  logs is done
convert between resque workers and heroku worker dynos
  done
gradual up scaling
  done
removing the deprecated heroku - api gem
  done
sets a minimum off the config var
  done set the ENV['WORKER_MIN'] or it defaults to 0


VERSION 0.4
scale open workers when a slow task has bogged queue - tasks are waiting
gradual down scaling

turn on / off scaling with an environment var
  later





Resque Heroku Autoscaler (RHA)
=======================

A [Resque][rq] plugin. Requires Resque 1.8 and the Heroku-api gem.

This gem scales your Heroku workers according to the number of pending Resque jobs. The original idea comes from Daniel Huckstep's [blog post on the topic][dh]


##Setup

In order for the scaling to work RHA needs to know your **Heroku app's name, your Heroku user name and your Heroku password**. Per default those are being read from the following environment variables:

- HEROKU_APP
- HEROKU_API_KEY

If you prefer you also can configure RHA using a config block. For example you might put the following into config/initialiazers/resque_heroku_autoscaler_setup.config

    require 'resque/plugins/resque_heroku_autoscaler'

    Resque::Plugins::HerokuAutoscaler.config do |c|
      c.heroku_app  = "my_app_#{Rails.env}"
      c.heroku_api_key = 'abdcef'
    end


To use RHA in one of your jobs, just extend your job class with Resque::Plugins::HerokuAutoscaler.

For example:

    require 'resque/plugins/resque_heroku_autoscaler'

    class TestJob
      extend Resque::Plugins::HerokuAutoscaler

      @queue = :test

      def perform
       ...awesome stuff...
      end
    end

When you add the job to your Resque queue, a new worker will be started if there isn't already one. If all jobs in the queue are processed the worker will be stopped again, keeping your costs low.

Per default RHA will only start a single worker, no matter how many jobs are pending. You can change this behavior in the config block as well:

    require 'resque/plugins/resque_heroku_autoscaler'

    Resque::Plugins::HerokuAutoscaler.config do |c|
      c.new_worker_count do |pending|
        (pending/5).ceil.to_i
      end
    end

When calculating the new number of required workers the block given to new_worker_count will be called. Thus the example will result in starting one additional worker for every 5 pending jobs.

You might want to turn off scaling of your workers in development modus. You can do that by setting _scaling_disabled_ to true in your init script:

    if (Rails.env == 'development')
      Resque::Plugins::HerokuAutoscaler.config do |c|
        c.scaling_disabled = true
      end
    end



[dh]: http://blog.darkhax.com/2010/07/30/auto-scale-your-resque-workers-on-heroku
[rq]: http://github.com/defunkt/resque
