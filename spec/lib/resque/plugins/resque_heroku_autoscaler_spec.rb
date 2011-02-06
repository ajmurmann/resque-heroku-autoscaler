require 'rspec'
require 'heroku'
require 'resque'

require 'resque/plugins/resque_heroku_autoscaler'

RSpec.configure do |config|
  config.mock_with :rr
  # or if that doesn't work due to a version incompatibility
  # config.mock_with RR::Adapters::Rspec
end

class TestJob
  include Resque::Plugins::HerokuAutoscaler
end

class AnotherJob
  include Resque::Plugins::HerokuAutoscaler
end

describe Resque::Plugins::HerokuAutoscaler do
  before do
    @my_job = TestJob.new
  end

  it "should be a valid Resque plugin" do
    lambda { Resque::Plugin.lint(Resque::Plugins::HerokuAutoscaler) }.should_not raise_error
  end

  describe ".after_enqueue_scale_workers_up" do
    it "should add the hook" do
      Resque::Plugin.after_enqueue_hooks(@my_job).should include("after_enqueue_scale_workers_up")
    end

    it "should create one worker" do
      stub(@my_job).workers { 0 }
      mock(@my_job).set_workers(1)
      @my_job.after_enqueue_scale_workers_up
    end
  end

  describe ".after_perform_scale_workers_down" do

    it "should add the hook" do
      Resque::Plugin.after_hooks(@my_job).should include("after_perform_scale_workers_down")
    end

    it "should take whatever args Resque hands in" do
      stub(Heroku::Client).new { stub!.set_workers }

      lambda { @my_job.after_perform_scale_workers_down("some", "random", "aguments", 42) }.should_not raise_error
    end

    context "when the queue is empty" do
      before do
        stub(Resque).info { {:pending => 0} }
      end

      it "should set workers to 0" do
        @my_job = TestJob.new
        mock(@my_job).set_workers(0)
        @my_job.after_perform_scale_workers_down
      end
    end

    context "when the queue is not empty" do
      before do
        stub(Resque).info { {:pending => 1} }
      end

      it "should not change workers" do
        my_job = TestJob.new
        dont_allow(my_job).set_workers
        my_job.after_perform_scale_workers_down
      end
    end
  end

  describe ".set_workers" do
    it "should use the Heroku client to set the workers" do
      ENV['HEROKU_APP'] = 'some app name'
      mock(@my_job).heroku_client { mock!.set_workers('some app name', 10) }
      @my_job.set_workers(10)
    end
  end

  describe ".heroku_client" do
    before do
      ENV['HEROKU_USER'] = 'john doe'
      ENV['HEROKU_PASS'] = 'password'
    end

    it "should return a heroku client" do
      TestJob.class_eval("@@heroku_client = nil")
      @my_job.heroku_client.should be_a(Heroku::Client)
    end

    it "should use the right username and password" do
      TestJob.class_eval("@@heroku_client = nil")
      mock(Heroku::Client).new('john doe', 'password')
      @my_job.heroku_client
    end

    it "should return the same client for multiple jobs" do
      a = 0
      stub(Heroku::Client).new { a += 1 }
      @my_job.heroku_client.should == TestJob.new.heroku_client
    end

    it "should share the same client across differnet job types" do
      a = 0
      stub(Heroku::Client).new { a += 1 }

      @my_job.heroku_client.should == AnotherJob.new.heroku_client
    end
  end
end