require 'rspec'
require 'heroku'
require 'resque'
require 'resque/plugins/resque_heroku_autoscaler'

class TestJob
  extend Resque::Plugins::HerokuAutoscaler

  @queue = :test
end

class AnotherJob
  extend Resque::Plugins::HerokuAutoscaler

  @queue = :test
end

RSpec.configure do |config|
  config.mock_with :rr
end

describe Resque::Plugins::HerokuAutoscaler do
  it "should be a valid Resque plugin" do
    lambda { Resque::Plugin.lint(Resque::Plugins::HerokuAutoscaler) }.should_not raise_error
  end

  describe ".after_enqueue_scale_workers_up" do
    it "should add the hook" do
      Resque::Plugin.after_enqueue_hooks(TestJob).should include("after_enqueue_scale_workers_up")
    end

    it "should take whatever args Resque hands in" do
      stub(Heroku::Client).new { stub!.set_workers }

      lambda { TestJob.after_enqueue_scale_workers_up("some", "random", "aguments", 42) }.should_not raise_error
    end

    it "should create one worker" do
      stub(TestJob).workers { 0 }
      mock(TestJob).set_workers(1)
      TestJob.after_enqueue_scale_workers_up
    end
  end

  describe ".after_perform_scale_workers_down" do

    it "should add the hook" do
      Resque::Plugin.after_hooks(TestJob).should include("after_perform_scale_workers_down")
    end

    it "should take whatever args Resque hands in" do      
      Resque::Plugins::HerokuAutoscaler.class_eval("@@heroku_client = nil")
      stub(Heroku::Client).new { stub!.set_workers }

      lambda { TestJob.after_perform_scale_workers_down("some", "random", "aguments", 42) }.should_not raise_error
    end

    context "when the queue is empty" do
      before do
        stub(Resque).info { {:pending => 0} }
      end

      it "should set workers to 0" do
        mock(TestJob).set_workers(0)
        TestJob.after_perform_scale_workers_down
      end
    end

    context "when the queue is not empty" do
      before do
        stub(Resque).info { {:pending => 1} }
      end

      it "should not change workers" do
        dont_allow(TestJob).set_workers
        TestJob.after_perform_scale_workers_down
      end
    end
  end

  describe ".set_workers" do
    it "should use the Heroku client to set the workers" do
      ENV['HEROKU_APP'] = 'some app name'
      mock(TestJob).heroku_client { mock!.set_workers('some app name', 10) }
      TestJob.set_workers(10)
    end
  end

  describe ".heroku_client" do
    before do
      ENV['HEROKU_USER'] = 'john doe'
      ENV['HEROKU_PASS'] = 'password'
    end

    it "should return a heroku client" do
      Resque::Plugins::HerokuAutoscaler.class_eval("@@heroku_client = nil")
      TestJob.heroku_client.should be_a(Heroku::Client)
    end

    it "should use the right username and password" do
      Resque::Plugins::HerokuAutoscaler.class_eval("@@heroku_client = nil")
      mock(Heroku::Client).new('john doe', 'password')
      TestJob.heroku_client
    end

    it "should return the same client for multiple jobs" do
      a = 0
      stub(Heroku::Client).new { a += 1 }
      TestJob.heroku_client.should == TestJob.heroku_client
    end

    it "should share the same client across differnet job types" do
      a = 0
      stub(Heroku::Client).new { a += 1 }

      TestJob.heroku_client.should == AnotherJob.heroku_client
    end
  end
end