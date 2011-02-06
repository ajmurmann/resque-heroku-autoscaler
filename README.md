Resque Heroku Autoscaler
===========

A [Resque][rq] plugin. Requires Resque 1.8 and the Heroku gem (I only testet with 1.11.0).

This gem scales your Heroku workers according to the number of pending Resque jobs. The original idea comes from Daniel Huckstep's [blog post on the topic][dh]

Just extend your job class with esque::Plugins::HerokuAutoscaler.


For example:

    require 'resque/plugins/heroku_autoscaler'

    class TestJob
      extend Resque::Plugins::HerokuAutoscaler

      @queue = :test

      def
    end

When you add the job to your Resque queue, a new worker will be started if there isn't already one. If all jobs in the queue are processed the worker will be stopped again, keeping your costs low.

Currently there is no way build in to set how many workers to are being started. I plan on adding that functionality soon.

[dh]: http://blog.darkhax.com/2010/07/30/auto-scale-your-resque-workers-on-heroku
[rq]: http://github.com/defunkt/resque
